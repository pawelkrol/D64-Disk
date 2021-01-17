package D64::Disk;

=head1 NAME

D64::Disk - Manipulating Commodore (D64/D71/D81) disk images

=head1 SYNOPSIS

    use D64::Disk;

    # Create an empty D64 disk image:
    my $disk = D64::Disk->new();

    # Read D64 disk image from an existing file:
    my $disk = D64::Disk->new('disk.d64');

    # Create a formatted D64 disk image consisting of a provided program file:
    my $disk = D64::Disk->make('file.prg');

    # Format a D64 disk image:
    $disk->format_disk('name', 'id');

    # Read disk directory layout object from a D64 disk image:
    my $dir = $disk->read_dir();

    # Write disk directory layout object into a D64 disk image:
    $disk->write_dir($dir);

    # Add new file with a specified name and type to a D64 disk image:
    $disk->add_file($name, $type, $data);

    # Read the first file with a specified name and type from a D64 disk image:
    my $data = $disk->read_file($name, $type);

    # Remove the first file with a specified name and type from a D64 disk image:
    $disk->remove_file($name, $type);

    # Save D64 disk image into a file:
    $disk->save('disk.d64');

=cut

use bytes;
use strict;
use utf8;
use warnings;

our $VERSION = '0.01';

use Carp qw(carp croak);
use Data::Dumper;
use D64::Disk::BAM;
use D64::Disk::Layout;
use D64::Disk::Layout::Dir;
use D64::Disk::Layout::Sector;
use D64::Disk::Status::Factory;

# Single directory entry size in bytes:
our $dir_entry_length = 32;

# Block Availability Map (BAM) track:
our $BAM_TRACK = 18;
# Block Availability Map (BAM) sector:
our $BAM_SECTOR = 0;

# Sector interleave during data write:
our $sector_interleave = 8;

# Track data offsets in a D64 file:
# our @track_data_offsets;

sub new {
    my ($class) = shift ;
    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);
    return $self;
}

sub _initialize {
    my ($self) = shift;
    $self->_init_layout();
}

sub _init_layout {
    my ($self) = shift;
    $self->{_layout} = D64::Disk::Layout->new();
}

=head2 max_dir_entries

Get total number of available entries that can be created in the disk directory:

  my $total_number = $disk->max_dir_entries();

=cut

sub max_dir_entries {
    my ($self) = @_;
    my $class = ref($self) || $self;
    my $bytes_per_sector = $class->_derived_class_property_value('$bytes_per_sector');
    my $dir_entry_length = $class->_derived_class_property_value('$dir_entry_length');
    croak "Derived class \"${class}\" does not define \"\$dir_entry_length\" value" unless defined $dir_entry_length;
    my $sectors_per_track_aref = $class->_derived_class_property_value('@sectors_per_track');
    my $directory_track = $class->_derived_class_property_value('$directory_track');
    croak "Derived class \"${class}\" does not define \"\$directory_track\" value" unless defined $directory_track;
    my $num_sectors = $sectors_per_track_aref->[$directory_track - 1] - 1;
    my $max_dir_entries = $bytes_per_sector / $dir_entry_length * $num_sectors;
    return $max_dir_entries;
}

# my $can_write_to_disk = $self->_is_disk_format_version_correct();
sub _is_disk_format_version_correct {
    my ($self) = @_;
    my $diskBAM = undef; ## TODO: ...get BAM object...
    my $dos_version_type = $diskBAM->dos_version_type();
    if ($dos_version_type == 0x41 or $dos_version_type == 0x00) {
        # Disk format version OK:
        return 1;
    }
    else {
        # Soft write protection:
        ## TODO: ...raise "DOS Version" error code 73, "CBM DOS V2.6 1541"...
        return 0;
    }
}

=head2 layout

Retrieve an underlying L<D64::Disk::Layout> object:

    my $layout = $disk->layout();

=cut

sub layout {
    my ($self) = @_;
    return $self->{_layout};
}

=head2 format_disk

Format a D64 disk image:

  $disk->format_disk('name', 'id');

=cut

sub format_disk {
    my ($self, $name, $id) = @_;

    $self->_init_layout();

    my @sector_layouts = $self->{_layout}->sectors();
    for my $sector_layout (@sector_layouts) {
      my $bytes_per_sector = eval "\$D64::Disk::Layout::bytes_per_sector";
      my $sector_data = chr (0x00) . chr (0xff) . chr (0x00) x ($bytes_per_sector - 2);
      $self->{_layout}->sector_data($sector_layout->track(), $sector_layout->sector(), $sector_data);
    }

    my $diskBAM = $self->init_bam();

    $name //= '';
    $diskBAM->disk_name(1, $name);

    $id //= '';
    if (length ($id) > 2) {
      $diskBAM->full_disk_id(1, $id);
    }
    else {
      $diskBAM->disk_id(1, $id);
    }

    $self->_set_bam($diskBAM);

    my $dir_track = $self->{DIRECTORY_FIRST_TRACK};
    my $dir_track_data = $self->{_layout}->track_data($dir_track);
    my $bytes_per_sector = $D64::Disk::Layout::bytes_per_sector;
    substr $dir_track_data, 0, $bytes_per_sector, '';
    # Fix for "Use of uninitialized value $sector in numeric eq (==) at D64/Disk/Layout/Dir.pm line 444":
    my $directory_first_sector = eval "\$D64::Disk::Layout::Dir::DIRECTORY_FIRST_SECTOR";
    my $dir = D64::Disk::Layout::Dir->new(data => $dir_track_data);

    $self->_set_directory($dir);

    return D64::Disk::Status::Factory->new(0);
}

=head2 read_dir

Read disk directory layout object from a D64 disk image:

  my $dir = $disk->read_dir();

=cut

sub read_dir {
    my ($self) = @_;
    my $dir_track = $self->{DIRECTORY_FIRST_TRACK};
    my $dir_sector = $self->{DIRECTORY_FIRST_SECTOR};
    # my $bam_data = $self->{_layout}->sector_data($BAM_TRACK, $BAM_SECTOR);
    my $dir_data;
    while (1) {
      my $sector = $self->{_layout}->sector(track => $dir_track, sector => $dir_sector);
      $dir_data .= $sector->data();
      ($dir_track, $dir_sector) = $sector->ts_link();
      last if $sector->is_last_in_chain();
    }
    # Pad directory data to required 4608 bytes:
    my $dir_data_size = $D64::Disk::Layout::Sector::SECTOR_DATA_SIZE * $D64::Disk::Layout::Dir::TOTAL_SECTOR_COUNT;
    $dir_data .= chr (0x00) x (18 * 256 - length $dir_data);
    # Fix for "Use of uninitialized value $sector in numeric eq (==) at D64/Disk/Layout/Dir.pm line 444":
    my $directory_first_sector = eval "\$D64::Disk::Layout::Dir::DIRECTORY_FIRST_SECTOR";
    my $dir = D64::Disk::Layout::Dir->new(data => $dir_data, track => $dir_track, sector => $dir_sector);
    return $dir;
}

sub write_dir {
}

sub add_file {
}
sub new_file {
}

sub read_file {
}

sub remove_file {
}

# Doesn't remove the contents, only clean BAM and marks file as deleted in dir
sub scratch_file {
}

sub write_file {
}

=head2 save

Save D64 disk image into a file:

  $disk->save('disk.d64');

=cut

sub save {
    my ($self, $file_name) = @_;
    $self->{_layout}->save_as($file_name);
}

=head2 init_bam

Initialize BAM sector with the given 256 bytes of data:

  $disk->init_bam(sector => $data);

Clear the entire BAM sector data:

  $disk->init_bam();

=cut

sub init_bam {
    my ($self, %params) = @_;
    my $bytes = $params{sector};

    my $diskBAM = D64::Disk::BAM->new($bytes);

    # Allocate BAM sector:¶
    $diskBAM->sector_used($BAM_TRACK, $BAM_SECTOR, 1);

    # Track containing the entire directory:
    $self->{DIRECTORY_FIRST_TRACK} = $diskBAM->directory_first_track();
    # First directory sector:
    $self->{DIRECTORY_FIRST_SECTOR} = $diskBAM->directory_first_sector();

    # Allocate first directory sector:¶
    $diskBAM->sector_used($self->{DIRECTORY_FIRST_TRACK}, $self->{DIRECTORY_FIRST_SECTOR}, 1);

    return $self->_set_bam($diskBAM);
}

sub _get_bam {
    my ($self) = @_;

    my $sector_data = $self->{_layout}->sector_data($BAM_TRACK, $BAM_SECTOR);
    my $diskBAM = D64::Disk::BAM->new($sector_data);

    return $diskBAM;
}

sub _set_bam {
    my ($self, $diskBAM) = @_;

    my $sector_data = $diskBAM->get_bam_data();
    $self->{_layout}->sector_data($BAM_TRACK, $BAM_SECTOR, $sector_data);

    return $diskBAM;
}

sub _set_directory {
    my ($self, $dir) = @_;

    for my $sector ($dir->sectors()) {
      $self->{_layout}->sector(data => $sector);
    }

    return $dir;
}

1;
