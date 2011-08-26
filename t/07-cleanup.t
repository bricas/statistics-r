#! perl

use strict;
use warnings;
use Test::More;
use Statistics::R;
use File::Temp qw/ tempfile tempdir /;

plan tests => 10;


my $R;

my $tempdir = tempdir( 'tempXXXX', CLEANUP => 1 );
my ($tempfh, $tempfile) = tempfile( 'dummyXXXX', DIR => $tempdir, UNLINK => 1 );

ok -e $tempdir;
ok -e $tempfile;

ok $R = Statistics::R->new( log_dir => $tempdir );

ok -e $tempdir;
ok -e $tempfile;
my $start_r_file = $R->{ BRIDGE }->{ START_R };
ok -e $start_r_file;

ok $R->stop();

ok -e $tempdir;
ok -e $tempfile;
ok not -e $start_r_file;



