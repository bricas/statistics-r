#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

my $R;


ok $R = Statistics::R->new();
eval {
   $R->run( qq`print("Hello");\nprint "ASDF"` );
};
#diag "Diagnostic: \n".$@."\n";
ok $@, 'Syntax error';
# Actual error message vary depending on locale


ok $R = Statistics::R->new();
eval {
   $R->run( qq`print("Hello");\nprint(ASDF)` );
};
#diag "Diagnostic: \n".$@."\n";
ok $@, 'Runtime error';


use_ok 't::FlawedStatisticsR';
ok $R = t::FlawedStatisticsR->new();
eval {
   $R->run( qq`print("Hello");\ncolors<-c("red")` );
};
#diag "Diagnostic: \n".$@."\n";
ok $@, 'Internal error';


done_testing;


