#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;
use Time::HiRes qw ( time sleep );

plan tests => 13;


my ($R1, $R2, $R3, $R4);

ok $R1 = Statistics::R->new( shared => 1 );
ok $R2 = Statistics::R->new( shared => 1 );
ok $R3 = Statistics::R->new( shared => 1 );
ok $R4 = Statistics::R->new( shared => 1 );

ok $R2->start;
is $R1->is_shared, 1;

ok $R1->set( 'x', "string" );
ok $R2->set( 'y', 3  );
is $R2->get( 'x' ), "string";
ok $R3->set( 'z', 10 );
ok $R4->run( q`a <- x * y / z` );


print "##################\n";
is $R4->get( 'a' ), 13.5;
print "##################\n";

ok $R3->stop();
