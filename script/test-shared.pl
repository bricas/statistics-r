#!/usr/bin/perl

  use Statistics::R ;
  
  my $R = Statistics::R->new() ;

  print "STARTING..." ;

  if ( $R->start_sharedR ) {
    print " OK\n" ;  
  }
  else {
    die("Can't start R");
  }
  
  $R->lock ;

  for(0..10) {
    my $time = time ;
    $R->send(qq`x = $time \n print(x)`) ;
    my $ret = $R->read ;
    print "<< $ret >>\n" ;
    sleep(1);
  }
  
  $R->unlock ;
  
  print "by!\n" ;


