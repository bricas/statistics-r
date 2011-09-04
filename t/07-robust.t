#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

plan tests => 10003;


# Test that the IOs are well-oiled. In Statistics::R version 0.20, a slight
# imprecision in the regular expression to parse the output stream caused a
# problem was apparent only once every few thousands times

my ($R, $input);

ok $R = Statistics::R->new();

ok $R->set('x', $input);

for my $i (1 .. 10000) {
   is($R->get('x'), undef);
}

ok $R->stop();
