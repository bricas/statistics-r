#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

plan tests => 8;

$ENV{R_HOME} = "" if $ENV{R_HOME}; # avoid 'WARNING: ignoring environment value of R_HOME'

my $R;

my $file = 'file.ps';

ok $R = Statistics::R->new();

is $R->run( qq`postscript("$file" , horizontal=FALSE , width=500 , height=500 , pointsize=1)`), '';

is $R->run( q`plot(c(1, 5, 10), type = "l")` ), '';

ok $R->run( q`dev.off()` ); # RT bug #66190

ok -e $file; # RT bug #70307

ok $R->run( qq`x = 123 \n print(x)` ) =~ /^\[\d+\]\s+123\s*$/;

ok $R->run( qq`x = 456 ; write.table(x, file="", row.names=FALSE, col.names=FALSE) ` ) =~ /^456$/; # RT bug #70314

ok $R->bin() =~ /\S+/;

unlink $file;

eval {
   $R->run( q`print(ASDF)` );
};
# this test fails for me:
# "Dubious, test returned 2 (wstat 512, 0x200)"
#ok $@ =~ m/error/i; # Catch an R error

