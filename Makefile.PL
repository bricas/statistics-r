use strict;
use warnings;
use File::Spec::Functions;

use ExtUtils::MakeMaker;

if ( -e 'MANIFEST.SKIP' ) {
   generate_readme( catfile('lib','Statistics','R.pm'), 'README' ); 
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
        'Test::More'     => '0.47',
        'Text::Balanced' => '0',
        'Regexp::Common' => '0',
    },
);


sub generate_readme {
   my ($in, $out) = @_;
   `pod2text $in $out`;
   warn "Warning: Could not generate $out.\n$!\n" if $? == -1;
   return $?; # exit status
}
