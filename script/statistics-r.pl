#!/usr/bin/perl

use strict;
use warnings;

use Statistics::R;

my $command = lc( shift || '' );

usage() if !$command;

my $R = Statistics::R->new();

if ( $command eq 'start' ) {
    print ">> R - STARTING... ";
    if ( $R->start_sharedR ) {
        print "OK\n";
        if ( $^O =~ /^(?:.*?win32|dos)$/i ) {
            print "[Press Ctrl+C to terminate].\n";
            while ( 1 ) { sleep( 10 ); }
        }
        else {
            my $child_pid = fork;
            if ( $child_pid != 0 ) {
                $R = undef;
                exit;
            }
        }
    }
    else {
        die( "\n** Can't start R!" );
    }
}
elsif ( $command eq 'stop' ) {
    $R->stopR();
}

sub usage {
    my ( $script ) = ( $0 =~ /([^\\\/]+)$/s );

    print <<"EOUSAGE";
Statistics::R - $Statistics::R::VERSION

USAGE:

  $script start
  $script stop

(C) Copyright 2000-2004, Graciliano M. P. <gm\@virtuasites.com.br>
EOUSAGE

    exit;
}
