#!/usr/bin/perl

use Statistics::R;

print "Starting R...";

my $R = Statistics::R->new( shared => 1 );

if ( $R->is_started ) {
    print " OK\n";
}
else {
    die "Error: Could not start R\n";
}

$R->lock;

for ( 0 .. 10 ) {
    my $time = time;
    $R->send( qq`x = $time \n print(x)` );
    my $ret = $R->read;
    print "<< $ret >>\n";
    sleep( 1 );
}

$R->unlock;

print "Bye!\n";

