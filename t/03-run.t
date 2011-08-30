#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

plan tests => 10;


my $R;

my $file = 'file.ps';

ok $R = Statistics::R->new();

is $R->run( qq`postscript("$file" , horizontal=FALSE , width=500 , height=500 , pointsize=1)`), '';

is $R->run( q`plot(c(1, 5, 10), type = "l")` ), '';

#is $R->run( q`dev.off()` ), '';
my $out = $R->run( q`dev.off()` );
print "out = $out\n";

ok -e $file; # RT bug #70307

ok $R->run( qq`x = 123 \n print(x)` ) =~ /^\[\d+\]\s+123\s*$/;

ok $R->send( qq`x = 456 \n print(x)` );
ok $R->receive() =~ /^\[\d+\]\s+456\s*$/;

ok $R->bin() =~ /\S+/;

unlink $file;

eval {
   $R->run( q`print(ASDF)` );
};
ok $@ =~ m/error/i; # Catch an R error

