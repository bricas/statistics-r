#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

my ($R, $expected);

ok $R = Statistics::R->new();

ok $R->timeout(0.1);

my $func = 'function(){ Sys.sleep(2); return (1) }';
$R->run(qq`func <- $func` );

# command timing out
$expected = '';
is $R->run(q`func()`), $expected;

# quick calculation not timing out, expecting result
$expected = 1;
ok $R->run(q`1+1`);

# give timeout in constructor
ok $R = Statistics::R->new( timeout => 0.1, shared => 1 );
$R->run(qq`func <- $func` );

done_testing;
