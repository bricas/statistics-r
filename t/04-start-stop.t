#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

plan tests => 8;


my $R;

ok $R = Statistics::R->new();

ok $R->start();

ok $R->restart();

ok $R->stop();

ok $R->start_shared();

ok $R->stop();

ok $R->start( shared => 1);

ok $R->stop();

