#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

my ($R, $expected);

ok $R = Statistics::R->new();

ok $R->timeout(0.1);

# command timing out
$expected = '';
is $R->run(q`Sys.sleep(0.2)`), $expected;

# quick calculation not timing out, expecting result
isnt $R->run(q`1+1`), $expected;

# give timeout in constructor
ok $R = Statistics::R->new( timeout => 0.1, shared => 1 );
is $R->run(q`Sys.sleep(0.2)`), $expected;

# still times out with newly built bridge
is $R->run(q`Sys.sleep(0.2)`), $expected;

done_testing;
