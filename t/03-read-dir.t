#########################
use D64::Disk;
use Test::More tests => 1;
#########################
{
my $disk = D64::Disk->new();
$disk->format_disk('name', 'id');
my $dir = $disk->read_dir();
is(ref $dir, 'D64::Disk::Layout::Dir', 'read_dir - read disk directory layout object from a D64 disk image');
}
#########################
