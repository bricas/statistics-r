use strict;
use warnings;

use Test::More tests => 10;

use Statistics::R;

my $R;
my $warn = 0;
{
    local $SIG{ __WARN__ } = sub { $warn++; };
    $R = Statistics::R->new();
}

SKIP: {
    skip 'No R binary', 10 if $warn;

    ok( $R );

    ok( $R->startR );

    ok( $R->Rbin );

    ok( $R->send(
            q`postscript("file.ps" , horizontal=FALSE , width=500 , height=500 , pointsize=1)`
        )
    );

    ok( $R->send( q`plot(c(1, 5, 10), type = "l")` ) );

    ok( $R->send( qq`x = 123 \n print(x)` ) );

    my $ret = $R->read;

    ok( $ret =~ /^\[\d+\]\s+123\s*$/ );

    ok( $R->send( qq`x = 456 \n print(x)` ) );
    $ret = $R->read;
    ok( $ret =~ /^\[\d+\]\s+456\s*$/ );

    ok( $R->stopR() );
}

