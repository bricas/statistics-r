#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

plan tests => 8;


my $R;
my $warn = 0;
{
    local $SIG{ __WARN__ } = sub { $warn++; };
    $R = Statistics::R->new();
}

SKIP: {
    skip 'No R binary', 10 if $warn;

    ok $R;

    ok $R->start();

    ok $R->restart();

    ok $R->stop();

    ok $R->start_shared();

    ok $R->stop();

    ok $R->start( shared => 1);

    ok $R->stop();

}

