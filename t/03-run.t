#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

plan tests => 9;


my $R;

ok $R = Statistics::R->new();

ok $R->bin() =~ /\S+/;

is $R->run(q`postscript("file.ps" , horizontal=FALSE , width=500 , height=500 , pointsize=1)`), '';

is $R->run( q`plot(c(1, 5, 10), type = "l")` ), '';

ok $R->run( qq`x = 123 \n print(x)` ) =~ /^\[\d+\]\s+123\s*$/;

ok $R->send( qq`x = 456 \n print(x)` );
ok $R->receive() =~ /^\[\d+\]\s+456\s*$/;

ok $R->clean_up();

ok $R->stopR();


