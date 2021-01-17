#########################
use D64::Disk;
use D64::Disk::Layout;
use Test::More tests => 5;
use constant BYTES_PER_SECTOR => $D64::Disk::Layout::bytes_per_sector;
#########################
{
my $disk = D64::Disk->new();
my $raw_data = $disk->layout()->data();
is($raw_data, chr (0x00) x (683 * BYTES_PER_SECTOR), 'format_disk - an unformatted D64 disk image is entirely filled with $00 bytes');
}
#########################
{
my $disk = D64::Disk->new();
my $status = $disk->format_disk('name', 'id');
### TODO: REMOVE IT!!! ###
unlink('temp2.d64');
$disk->{_layout}->save_as('temp2.d64');
### TODO: REMOVE IT!!! ###
is(ref $status, 'D64::Disk::Status', 'format_disk - returns disk status object')
}
#########################
{
my $disk = D64::Disk->new();
my $status = $disk->format_disk('name', 'id');
is($status->{error}, 'OK', 'format_disk - completes without errors')
}
#########################
{
my $disk = D64::Disk->new();
$disk->format_disk('name', 'id');
my $raw_data = substr $disk->layout()->data(), 357 * BYTES_PER_SECTOR, BYTES_PER_SECTOR;
my $bam_data = join '', map { chr hex } qw(
12 01 41 00 15 ff ff 1f 15 ff ff 1f 15 ff ff 1f
15 ff ff 1f 15 ff ff 1f 15 ff ff 1f 15 ff ff 1f
15 ff ff 1f 15 ff ff 1f 15 ff ff 1f 15 ff ff 1f
15 ff ff 1f 15 ff ff 1f 15 ff ff 1f 15 ff ff 1f
15 ff ff 1f 15 ff ff 1f 11 fc ff 07 13 ff ff 07
13 ff ff 07 13 ff ff 07 13 ff ff 07 13 ff ff 07
13 ff ff 07 12 ff ff 03 12 ff ff 03 12 ff ff 03
12 ff ff 03 12 ff ff 03 12 ff ff 03 11 ff ff 01
11 ff ff 01 11 ff ff 01 11 ff ff 01 11 ff ff 01
4e 41 4d 45 a0 a0 a0 a0 a0 a0 a0 a0 a0 a0 a0 a0
a0 a0 49 44 a0 32 41 a0 a0 a0 a0 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
);
is($raw_data, $bam_data, 'format_disk - a formatted D64 disk image has got the BAM area initialised');
}
#########################
{
my $disk = D64::Disk->new();
$disk->format_disk('name', 'id');
my $raw_data = $disk->layout()->data();
substr $raw_data, 357 * BYTES_PER_SECTOR, BYTES_PER_SECTOR, '';
my $sector_data = join '', map { chr hex } qw(
00 ff 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
);
my $disk_data = $sector_data x (683 - 1);
is($raw_data, $disk_data, 'format_disk - a formatted D64 disk image has got all track/sector data initialised');
}
#########################
