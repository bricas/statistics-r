use strict;
use warnings;

use inc::Module::Install;

use lib 'lib';
use Statistics::R::Bridge;


name     'Statistics-R';
all_from 'lib/Statistics/R.pm';

resources
   homepage   'http://search.cpan.org/search?query=statistics%3A%3AR&mode=dist';
   bugtracker 'http://rt.cpan.org/Dist/Display.html?Name=Statistics-R';
   repository 'git@github.com:bricas/statistics-r.git';

build_requires 'Test::More'      => '0.47';

requires       'Text::Balanced'  => '0';
requires       'Regexp::Common'  => '0';
requires       'File::Which'     => '0';

if ( $^O =~ m/^(?:.*?win32|dos)$/i ) {
    Statistics::R::Bridge::win32_path_adjust();
}
requires_external_bin 'R';

install_script 'script/statistics-r';

WriteAll;

if ( -e 'MANIFEST.SKIP' ) {
   generate_readme( 'lib/Statistics/R.pm', 'README' ); 
}



sub generate_readme {
   my ($in, $out) = @_;
   `pod2text $in $out`;
   warn "Warning: Could not generate $out.\n$!\n" if $? == -1;
   return $?; # exit status
}
