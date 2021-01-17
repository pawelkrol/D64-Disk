use ExtUtils::MakeMaker;
WriteMakefile(
    NAME             => 'D64::Disk',
    VERSION_FROM     => 'Disk.pm',
    PREREQ_PM        => {
                            D64::Disk::BAM            => 0.05,
                            D64::Disk::Layout         => 0.03,
                            D64::Disk::Layout::Dir    => 0.06,
                            D64::Disk::Layout::Sector => 0.02,
                            D64::Disk::Status         => 0.03,
                            File::Temp                => 0,
                            Test::More                => 0,
                        },
    ($] >= 5.005 ?
      (ABSTRACT_FROM => 'Disk.pm',
       AUTHOR        => 'Pawel Krol <pawelkrol@cpan.org>') : ()),
);
