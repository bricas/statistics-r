#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;
use Time::HiRes qw ( time sleep );

plan tests => 16;


my $R;

ok $R = Statistics::R->new( shared => 1 );

ok $R->is_started();

ok $R->lock();

for ( 0 .. 10 ) {
    my $time = time;
    my $ret = $R->run( qq`x = $time \n print(x)` );
    ok $ret =~ m/\S+/;
    #print "<< $ret >>\n";
    sleep( 0.2 );
}

ok $R->unlock();

ok $R->stop();
