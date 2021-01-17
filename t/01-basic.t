#########################
use Test::Deep;
use Test::More tests => 3;
use File::Temp qw(tmpnam);
#########################
{
BEGIN { require_ok('D64::Disk') };
}
#########################
{
my $disk = D64::Disk->new();
is(ref $disk, 'D64::Disk', 'new - create an empty D64 disk image');
}
#########################
{
my $disk = D64::Disk->new();
my $raw_data = $disk->layout()->data();
is($raw_data, chr (0x00) x (683 * 256), 'new - an unformatted D64 disk image is entirely filled with $00 bytes apart from the BAM area');
}
#########################
