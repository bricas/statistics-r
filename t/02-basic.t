#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

plan tests => 10;


my $R;

ok $R = Statistics::R->new();

ok $R->startR();

ok $R->Rbin() =~ /\S+/;

ok $R->send(q`postscript("file.ps" , horizontal=FALSE , width=500 , height=500 , pointsize=1)`);

ok $R->send( q`plot(c(1, 5, 10), type = "l")` );

ok $R->send( qq`x = 123 \n print(x)` );

my $ret = $R->read();
ok $ret =~ /^\[\d+\]\s+123\s*$/;

ok $R->send( qq`x = 456 \n print(x)` );

$ret = $R->read();
ok $ret =~ /^\[\d+\]\s+456\s*$/;

ok $R->stopR();

