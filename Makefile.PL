use strict;
use warnings;

use ExtUtils::MakeMaker;

if ( -e 'MANIFEST.SKIP' ) {
    system( 'pod2text lib/Statistics/R.pm > README' );
}

WriteMakefile(
    DISTNAME      => 'Statistics-R',
    NAME          => 'Statistics::R',
    AUTHOR        => 'Graciliano M. P. <gm@virtuasites.com.br>',
    ABSTRACT_FROM => 'lib/Statistics/R.pm',
    VERSION_FROM  => 'lib/Statistics/R.pm',
    EXE_FILES     => [ qw(script/statistics-r.pl) ],
    (   eval { ExtUtils::MakeMaker->VERSION( 6.21 ) }
        ? ( LICENSE => 'perl' )
        : ()
    ),
    PREREQ_PM => {
        'Test::More' => '0.47',
    },
);
