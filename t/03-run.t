#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;

plan tests => 15;


my ($R, $expected);

my $file = 'file.ps';

ok $R = Statistics::R->new();

ok $R->bin() =~ /\S+/, 'Binary';

$expected = '';
is $R->run( ), $expected;

$expected = '';
is $R->run( qq`postscript("$file" , horizontal=FALSE , width=500 , height=500 , pointsize=1)`), $expected, 'Basic';

$expected = '';
is $R->run( q`plot(c(1, 5, 10), type = "l")` ), $expected;

$expected = 
'null device 
          1 ';
is $R->run( q`dev.off()` ), $expected; # RT bug #66190

ok -e $file; # RT bug #70307
unlink $file;

$expected =
'loop iteration 1
loop iteration 2
loop iteration 3';
is $R->run( q`for (j in 1:3) { cat("loop iteration "); cat(j); cat("\n") }` ), $expected;

$expected = 'Some innocuous message on stderr';
is $R->run( q`write("Some innocuous message on stderr", stderr())` ), $expected, 'IO';

$expected = 'Some innocuous message on stdout';
is $R->run( q`write("Some innocuous message on stdout", stdout())` ), $expected;

$expected = '[1] 123';
is $R->run( qq`x <- 123 \n print(x)` ), $expected, 'Multi-line commands';

$expected = '456';
my $cmd1 = 'x <- 456 ; write.table(x, file="", row.names=FALSE, col.names=FALSE)';
is $R->run( $cmd1 ), $expected; # RT bug #70314

my $cmd2 = <<EOF;
a <- 2
b <- 5
c <- a * b
print('ok')
EOF
$expected = '[1] "ok"';
is $R->run( $cmd2 ), $expected, 'Heredoc commands';

$expected =
'456
[1] "ok"';
is $R->run( $cmd1, $cmd2 ), $expected, 'Multiple commands';

eval {
   $R->run( q`print(ASDF)` );
};
ok $@, 'Error handling'; # Cannot match a specific string because locale may vary


