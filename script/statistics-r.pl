#!/usr/bin/perl

  use Statistics::R ;
  
  use strict ;
  
  my $do ;
  
  if    ( $ARGV[0] =~ /start/i ) { $do = 'start' ;}
  elsif ( $ARGV[0] =~ /stop/i ) { $do = 'stop' ;}  
  
if ( $do eq '' ) {

  my ($script) = ( $0 =~ /([^\\\/]+)$/s );

print qq`____________________________________________________________________

Statistics::R - $Statistics::R::VERSION
____________________________________________________________________

USAGE:

  $script start
  $script stop

(C) Copyright 2000-2004, Graciliano M. P. <gm\@virtuasites.com.br>
____________________________________________________________________
`;

exit;
}
  
  my $R = Statistics::R->new() ;
  
  if ( $do eq 'start' ) {
    print ">> R - STARTING... " ;
    if ( $R->start_sharedR ) {
      print " OK\n" ;
      if ( $^O =~ /^(?:.*?win32|dos)$/i ) {
        print "[Press Ctrl+C to terminate].\n" ;
        while(1) { sleep(10) ;}
      }
      else {
        my $child_pid = fork ;
        if ( $child_pid != 0 ) {
          $R = undef ;
          exit ;
        }
      }
    }
    else {
      die("\n** Can't start R!");
    }
  }
  elsif ( $do eq 'stop' ) {
    $R->stopR() ;
  }

exit;


