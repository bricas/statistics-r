#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

plan tests => 30;


my ($R1, $R2, $R3, $R4);

ok $R1 = Statistics::R->new( shared => 1 );
ok $R2 = Statistics::R->new( shared => 1 );
ok $R3 = Statistics::R->new( shared => 1 );
ok $R4 = Statistics::R->new( shared => 1 );

is $R1->is_shared, 1;
is $R2->is_shared, 1;
is $R3->is_shared, 1;
is $R4->is_shared, 1;

ok $R2->start;
ok $R4->start;
ok $R3->start;
ok $R1->start;

is $R1->is_started, 1;
is $R2->is_started, 1;
is $R3->is_started, 1;
is $R4->is_started, 1;

print "R1 PID = ".$R1->pid."\n";
print "R2 PID = ".$R2->pid."\n";
print "R3 PID = ".$R3->pid."\n";
print "R4 PID = ".$R4->pid."\n";

is $R1->pid, $R2->pid;
is $R1->pid, $R3->pid;
is $R1->pid, $R4->pid;

###
exit;

ok $R1->set( 'x', "string" );

ok $R2->set( 'y', 3  );

is $R2->get( 'x' ), "string";

ok $R3->set( 'z', 10 );

ok $R4->run( q`a <- y / z` );

is $R4->get( 'a' ), 0.3;

ok $R3->stop();

is $R1->is_started, 0;
is $R2->is_started, 0;
is $R3->is_started, 0;
is $R4->is_started, 0;
