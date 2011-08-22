#! perl

use strict;
use warnings;
use Test::More tests => 1;


BEGIN {
   use_ok( 'Statistics::R' );
}

diag( "Testing Statistics::R $Statistics::R::VERSION, Perl $], $^X" );
