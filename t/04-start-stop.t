#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;
use Cwd;

plan tests => 10;


my $R;

my $initial_dir = cwd;

ok $R = Statistics::R->new();

ok $R->start();

is cwd, $initial_dir; # Bug RT #6724 and #70307

ok $R->restart();

ok $R->stop();

ok $R->start_shared();

ok $R->stop();

ok $R->start( shared => 1);

ok $R->stop();

is cwd, $initial_dir; # Bug RT #6724 and #70307