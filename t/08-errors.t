#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

plan tests => 3;

my $R;

ok $R = Statistics::R->new();


eval {
   $R->run( q`print "ASDF"` );
};
ok $@, 'Syntax error';
# Actual error message vary depending on locale


eval {
   $R->run( q`print(ASDF)` );
};
ok $@, 'Runtime error';

