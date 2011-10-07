#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

plan tests => 13;


my $R;

my $file = 'file.ps';

ok $R = Statistics::R->new();

is $R->run( qq`postscript("$file" , horizontal=FALSE , width=500 , height=500 , pointsize=1)`), '', 'Basic';

is $R->run( q`plot(c(1, 5, 10), type = "l")` ), '';

ok $R->run( q`dev.off()` ); # RT bug #66190

ok -e $file; # RT bug #70307

ok $R->run( q`for (j in 1:3) { cat("loop iteration: "); print(j); }` );

ok $R->run( q`write("Some innocuous message on stderr", stderr())` ), 'IO';

ok $R->run( q`write("Some innocuous message on stderr", stderr())` );

ok $R->run( qq`x <- 123 \n print(x)` ) =~ /^\[\d+\]\s+123\s*$/, 'Multi-line';

ok $R->run( qq`x <- 456 ; write.table(x, file="", row.names=FALSE, col.names=FALSE) ` ) =~ /^456$/; # RT bug #70314

my $cmds = <<EOF;
a <- 2
b <- 5
c <- a * b
print('ok')
EOF

ok $R->run($cmds), 'Heredocs';

ok $R->bin() =~ /\S+/;

unlink $file;

eval {
   $R->run( q`print(ASDF)` );
};
ok $@, 'Error handling'; # Cannot match a specific string because locale may vary


