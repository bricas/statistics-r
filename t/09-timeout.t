#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

my ($R, $expected);

ok $R = Statistics::R->new();

ok $R->timeout(1);

# lengthy command timing out
$expected = '';
is $R->run(q`mean(rt(100000000, df = 4))`), $expected;

# quicker calculation not timing out
$expected = '';
ok ! $R->run(q`mean(rt(100, df = 4))`) eq '';

# give timeout in constructor
ok $R = Statistics::R->new( timeout => 1, shared => 1 );

$expected = '';
is $R->run(q`mean(rt(100000000, df = 4))`), $expected;

# still times out with newly built bridge
is $R->run(q`mean(rt(100000000, df = 4))`), $expected;

done_testing;
