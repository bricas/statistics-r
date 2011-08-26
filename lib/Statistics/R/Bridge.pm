package Statistics::R::Bridge;

use strict;
use warnings;
use IO::Select;
use File::Spec::Functions;
use Time::HiRes qw( sleep );
use File::Which qw( where );
use Env qw( @PATH $PROGRAMFILES );
use File::DosGlob qw( glob );


our $HOLD_PIPE_X;
our $IS_WIN = ($^O =~ m/^(?:.*?win32|dos)$/i) ? 1 : 0;


sub new {
    my ($class, %args) = @_;
    my $this = {};
    bless $this, ref($class) || $class;
    $this->initialize( %args );
    return $this;
}


sub initialize {
    my ($this, %args) = @_;
    
    # Find and create log dir
    $this->{ LOG_DIR } = $args{ log_dir } || catfile( File::Spec->tmpdir(), 'Statistics-R');
    # Fix by CTB for RT Bug #17956: log_dir should be in tmp_dir by default
    if ( !-e $this->{ LOG_DIR } ) { mkdir( $this->{ LOG_DIR }, 0777 ); }
    if (   !-d $this->{ LOG_DIR }
        || !-r $this->{ LOG_DIR }
        || !-w $this->{ LOG_DIR } )
    {
        die "Error: Could not read or write the LOG_DIR directory ".$this->{LOG_DIR}."\n"
    }
    
    # Find full path of R binary
    if ( $args{ r_bin } || $args{ R_bin } ) {
        # User-specified location
        $this->{ R_BIN } =  $args{ r_bin } || $args{ R_bin };
        if ( !-s $this->{ R_BIN } ) {
            die "Error: Could not find the R binary at the specified location, ".
                $this->{ R_BIN }."\n";
        }
    } else {
        # Windows-specific PATH adjustement
        win32_path_adjust() if $IS_WIN;
        # Locate R in PATH using File::Which
        my @paths = where('R');
        if (scalar @paths == 0) {
            die "Error: Could not find the R binary! Make sure it is in your ".
                "PATH environment variable or specify its location using the ".
                "r_bin option of the new() method.\n";
        }
        $this->{ R_BIN } = $paths[0];
        #if (scalar @paths > 1) {
        #    warn "Warning: Multiple binaries where found for R. Using the first".
        #         " one... ".$this->{ R_BIN }."\n";  
        #}
    }
    $this->{ R_BIN } = win32_space_quote( $this->{ R_BIN } ) if $IS_WIN;
    $this->{ START_CMD } = "$this->{R_BIN} --slave --vanilla ";

    # Files necessary for piping to and from R
    $this->{ START_R }    = catfile($this->{LOG_DIR}, 'start.r');
    $this->{ OUTPUT_R }   = catfile($this->{LOG_DIR}, 'output.log');
    $this->{ PROCESS_R }  = catfile($this->{LOG_DIR}, 'process.log');
    $this->{ PID_R }      = catfile($this->{LOG_DIR}, 'R.pid');
    $this->{ STARTING_R } = catfile($this->{LOG_DIR}, 'R.starting');
    $this->{ STOPPING_R } = catfile($this->{LOG_DIR}, 'R.stopping');
    $this->{ LOCK_R }     = catfile($this->{LOG_DIR}, 'lock.pid');
    
    # The name of R input file will be something like input.1.r
    $this->{ INPUT_R_PREFIX } = catfile($this->{LOG_DIR}, 'input.');
    $this->{ INPUT_R_SUFFIX } = '.r';

    return 1;
}


sub bin {
    my $this = shift;
    return $this->{ R_BIN };
}


sub send {
    my( $this, $cmd ) = @_;

    $cmd =~ s/\r\n?/\n/gs;
    $cmd .= "\n" if $cmd !~ /\n$/;
    $cmd =~ s/\n/\r\n/gs;
    
    while ( $this->is_locked ) { sleep( 1 ); }
    
    my $n = $this->read_processR || 0;
    $n = 1 if $n eq '0' || $n eq '';
    
    # Increment file number until the first free slot
    my $file = catfile( $this->{LOG_DIR}, "input.$n.r" );
    while ( -e $file || -e "$file._" ) {
        ++$n;
        $file = catfile( $this->{LOG_DIR}, "input.$n.r" );
    }
    
    $this->write_file( "$file._", "$cmd\n");
    
    chmod( 0777, "$file._" );

    $this->{ OUTPUT_R_POS } = -s $this->{ OUTPUT_R };

    rename( "$file._", $file );
    
    my $has_quit = 1 if $cmd =~ /^\s*(?:q|quit)\s*\(.*?\)\s*$/s;

    ##print "CMD[$n]$has_quit>> $cmd\n" ;

    my $status = 1;
    my $delay  = 0.02;
    
    my ( $x, $xx );
    while (
            ( !$has_quit || $this->{ STOPPING } == 1 )
            &&  -e $file
            &&  $this->is_started( !$this->{ STOPPING } )
          )
    {
        
        ++$x;
        ##print "sleep $file\n" ;
        sleep( $delay );
        if ( $x == 20 ) {
            
            my ( undef, $data ) = $this->read_processR;
            
            if ( $data =~ /\s$n\s+\.\.\.\s+\// ) { 
                last;
            }
            $x = 0;
            ++$xx;
            $delay = 0.5;
        }
        if ( $xx || 0 > 5 ) {
            
            $status = undef;
        }    ## xx > 5 = x > 50
    }
    
    if ( $has_quit && !$this->{ STOPPING } ) { $this->stop( 1 ); }

    return $status;
}


sub receive {
    my( $this, $timeout ) = @_;

    $timeout = -1 if !defined $timeout;

    open( my $fh, '<', $this->{ OUTPUT_R } ) or die "Error: Could not read file ".$this->{ OUTPUT_R }."\n$!\n";
    binmode( $fh );
    seek( $fh, ( $this->{ OUTPUT_R_POS } || 0 ), 0 );

    my $time = time;
    my ( $x, $data ) = ( 0, '' );

    while ( $x == 0 || ( time - $time ) <= $timeout ) {
        ++$x;
        my $s = -s $this->{ OUTPUT_R };
        my $r = read(
            $fh, $data,
            ( $s - $this->{ OUTPUT_R_POS } ),
            length( $data )
        );
        $this->{ OUTPUT_R_POS } = tell( $fh );
        last if !$r;
    }

    close( $fh );

    my @lines = split( /(?:\r\n?|\n)/s, $data );

    return @lines if wantarray;
    return join( "\n", @lines );
}
*read = \&receive;


sub is_started {
    my( $this, $can_auto_start ) = @_;

    return unless $this->{ PID };

    if ( kill( 0, $this->{ PID } ) <= 0 ) {
        $this->update_pid;
        $this->stop( undef, 1 ) if ( kill( 0, $this->{ PID } ) <= 0 );
        return 0;
    }
    elsif ( !-s $this->{ PID_R } ) {
        $this->sleep_unsync;

        if ( $can_auto_start ) {
            $this->wait_stopping;
            if ( -e $this->{ PID_R } ) { $this->wait_starting; }
        }

        if ( -s $this->{ PID_R } ) { $this->update_pid; }
        elsif ( $can_auto_start ) {
            $this->touch_file( $this->{PID_R} );
            chmod( 0777, $this->{ PID_R } );
            $this->stop;
            return $this->start_shared;
        }
        else { return; }
    }

    return 1;
}


sub lock {
    my $this = shift;

    while ( $this->is_locked ) { sleep( 0.5 ); }

    $this->write_file( $this->{LOCK_R}, "$$\n");

    chmod( 0777, $this->{ LOCK_R } );

    $this->{ LOCK } = 1;
    
    return 1;
}


sub unlock {
    my $this = shift;

    return if $this->is_locked;
    unlink( $this->{ LOCK_R } );
    return 1;
}


sub is_locked {
    my $this = shift;

    return undef
        if ( $this->{ LOCK }
        || !-e $this->{ LOCK_R }
        || !-s $this->{ LOCK_R } );

    my $pid = $this->read_file( $this->{ LOCK_R } );

    return undef if $pid == $$;

    if ( !kill( 0, $pid ) ) { unlink( $this->{ LOCK_R } ); return undef; }
    return 1;
}
*is_blocked = \&is_locked;


sub update_pid {
    my $this = shift;

    open( my $fh, $this->{ PID_R } ) or return $this->{ PID };
    my $pid = join '', <$fh>;
    close( $fh );
    $pid =~ s/\s//gs;
    
    return $this->{ PID } if $pid eq '';
    $this->{ PID } = $pid;
}


sub chmod_all {
    my $this = shift;

    chmod( 0777,
        $this->{ LOG_DIR },
        $this->{ START_R },
        $this->{ OUTPUT_R },
        $this->{ PROCESS_R },
        $this->{ LOCK_R },
        $this->{ PID_R } );
        
}


sub start {
    my $this = shift;
    
    return if $this->is_started;

    $this->stop( undef, undef, 1 );
    
    $this->clean_log_dir;
    
    $this->save_file_startR;

    $this->touch_file( $this->{PID_R} );
    $this->touch_file( $this->{OUTPUT_R} );
    $this->touch_file( $this->{PROCESS_R} );
    
    $this->chmod_all;

    my $cmd = $this->{START_CMD}." < ".$this->{START_R}." > ".$this->{ OUTPUT_R };

    my $pid = open( my $read, "| $cmd" ) or die "Error: Could not run the commmand\n$!\n";
    
    $this->{ PIPE } = $read;

    $this->{ HOLD_PIPE_X } = ++$HOLD_PIPE_X;
    {
        no strict 'refs'; # squash more errors
        *{ "HOLD_PIPE$HOLD_PIPE_X" } = $read;
    }

    $this->{ PID } = $pid;

    $this->chmod_all;
    
    # Wait
    while ( !-s $this->{ PID_R } ) {
        sleep( 0.05 );
    }
    
    $this->update_pid;
    
    # Wait
    while ( $this->read_processR() eq '' ) {
        sleep( 0.10 );
    }
    
    $this->chmod_all;
    
    return 1;
}

sub wait_starting {
    my $this = shift;

    {
        my $c;
        while ( -e $this->{ STARTING_R } ) {
            ++$c;
            sleep( 1 );
            if ( $c == 10 ) { return; }
        }
    }

    if (   -s $this->{ START_R }
        && -e $this->{ PID_R }
        && -e $this->{ OUTPUT_R }
        && -e $this->{ PROCESS_R } )
    {
        my $c;
        while ( -s $this->{ PID_R } == 0 || -s $this->{ PROCESS_R } == 0 ) {
            ++$c;
            sleep( 1 );
            if ( $c == 10 ) { return; }
        }
        return 1;
    }
    return;
}


sub wait_stopping {
    my $this = shift;

    my $c;
    while ( -e $this->{ STOPPING_R } ) {
        ++$c;
        sleep( 1 );
        if ( $c == 10 ) { return; }
    }
    return 1;
}


sub sleep_unsync {
    my $this = shift;

    my $n = "0." . int( rand( 100 ) );
    sleep( $n );
    return 1;
}


sub start_shared {
    my( $this, $no_recall ) = @_;

    return if $this->is_started;
    $this->{ START_SHARED } = 1;

    $this->wait_stopping;

    $this->wait_starting;

    if (   -s $this->{ START_R }
        && -s $this->{ PID_R }
        && -s $this->{ OUTPUT_R }
        && -s $this->{ PROCESS_R } )
    {
        delete $this->{ PIPE };

        $this->update_pid;
        $this->{ OUTPUT_R_POS } = 0;
        $this->{ STOPPING }      = undef;

        $this->chmod_all;

        if ( $this->is_started ) {
            while ( $this->read_processR() eq '' ) {
                sleep( 0.10 );
            }
            return 1;
        }
    }

    my $starting;
    if ( !-e $this->{ STARTING_R } ) {
        $this->touch_file( $this->{STARTING_R} );
        $starting = 1;
    }

    if ( $starting ) {
        $this->stop;
    }
    else {
        $this->sleep_unsync;
        if ( $this->wait_starting && $no_recall ) {
            unlink( $this->{ STARTING_R } );
            return $this->start_shared( 1 );
        }
    }

    my $stat = $this->start;

    unlink( $this->{ STARTING_R } ) if $starting;

    return $stat;
}


sub stop {
    no warnings; # squash "Killed" warning for now
    my ($this, $no_send, $not_started, $no_stopping_file) = @_;

    my $started = $not_started ? undef : $this->is_started;

    $this->{ STOPPING } = $started ? 1 : 2;
    
    if ( !$no_stopping_file ) {
        $this->touch_file( $this->{STOPPING_R} );
    }

    $this->unlock if $started;

    my $pid_old = $this->{ PID };
    my $pid = $this->update_pid || $pid_old;

    unlink( $this->{ PID_R } );

    if ( $pid_old && $pid_old != $pid ) {
        for ( 1 .. 3 ) { kill( 9, $pid_old ); }
    }

    $this->send( q`q("no",0,TRUE)` ) if !$no_send;

    if ( $pid ) {
        for ( 1 .. 3 ) { kill( 9, $pid ); }
    }


    {
        no strict 'refs'; # squash more errors
        close( *{ 'HOLD_PIPE' . $this->{ HOLD_PIPE_X } } );
    }

    delete $this->{ PIPE };
    delete $this->{ PID };
    delete $this->{ OUTPUT_R_POS };

    sleep( 1 ) if !$started;

    unlink( $this->{ STOPPING_R } );

    $this->clean_log_dir;

    $this->{ STOPPING } = undef;

    return 1;
}


sub restart {
    my $this = shift;
    $this->stop;
    $this->start;
    return 1;
}


sub read_processR {
    my $this = shift;

    my $s = -s $this->{ PROCESS_R } || 0;

    open( my $fh, $this->{ PROCESS_R } ) || return;
    seek( $fh, ( $s - 100 ), 0 );

    my $data;
    my $r = CORE::read( $fh, $data, 1000 );
    close( $fh );

    return if !$r;

    my ( $n ) = ( $data =~ /(\d+)\s*$/gi );
    $n = 1 unless $n;

    return ( $n, $data ) if wantarray;
    return $n;
}


sub save_file_startR {
    my $this = shift;

    my $pid_r          = win32_double_bs( $this->{ PID_R } );
    my $process_r      = win32_double_bs( $this->{ PROCESS_R } ); 
    my $input_r_prefix = win32_double_bs( $this->{ INPUT_R_PREFIX } );
    my $input_r_suffix = $this->{ INPUT_R_SUFFIX };

    my $bridge_code = qq`
      print("Statistics::R - Perl bridge started!") ;
      
      PERLINPUTFILEX = 0 ;
      PERLINPUTFILE = "" ;

      PERLOUTPUTFILE <- file("$process_r","w")
      cat(0 , "\\n" , file=PERLOUTPUTFILE)
      
      .Last <- function(x) {
        cat("/\\n" , file=PERLOUTPUTFILE)
        unlink(PERLINPUTFILE) ;
        print("QUIT") ;
        close(PERLOUTPUTFILE) ;
        unlink("$process_r") ;
        unlink("$pid_r") ;
      }
      
      PERLPIDFILE <- file("$pid_r","w")
      cat( Sys.getpid() , "\\n" , file=PERLPIDFILE)
      close(PERLPIDFILE) ;
      
      while(1) {
        PERLINPUTFILEX = PERLINPUTFILEX + 1 ;
        
        ##print(PERLINPUTFILEX) ;
        cat(PERLINPUTFILEX , "\\n" , file=PERLOUTPUTFILE)
        
        PERLINPUTFILE <- paste("$input_r_prefix", PERLINPUTFILEX , "$input_r_suffix" , sep="") ;
        
        ##print(PERLINPUTFILE) ;
        
        PERLSLEEPDELAY = 0.01
        PERLSLEEPDELAYX = 0 ;
        
        while( file.access(PERLINPUTFILE, mode=0) ) {
          ##print(PERLINPUTFILE);
          Sys.sleep(PERLSLEEPDELAY) ;
          
          ## Change the delays to process fast consecutive files,
          ## but without has a small sleep() time after some time
          ## without process files, soo, will save CPU.
          
          if ( PERLSLEEPDELAYX < 165 ) {
            PERLSLEEPDELAYX = PERLSLEEPDELAYX + 1 ;
            if      (PERLSLEEPDELAYX == 50)  { PERLSLEEPDELAY = 0.1 } ## 0.5s
            else if (PERLSLEEPDELAYX == 100) { PERLSLEEPDELAY = 0.5 } ## 5.5s
            else if (PERLSLEEPDELAYX == 120) { PERLSLEEPDELAY = 1 }   ## 15.5s
            else if (PERLSLEEPDELAYX == 165) { PERLSLEEPDELAY = 2 }   ## 60.5s
            else if (PERLSLEEPDELAYX == 195) { PERLSLEEPDELAY = 3 }   ## 120.5s
          }
        }
        
        cat("...\\n" , file=PERLOUTPUTFILE)
        
        tryCatch( source(PERLINPUTFILE) , error = function(e) { print(e) } ) ;
        
        ## Ensure that device is off after execute the input file.
        tryCatch( dev.off() , error = function(e) {} ) ;

        cat("/\\n" , file=PERLOUTPUTFILE)
        
        unlink(PERLINPUTFILE) ;
      
        if (PERLINPUTFILEX > 1000) {
          PERLINPUTFILEX = 0 ;
          close(PERLOUTPUTFILE) ;
          PERLOUTPUTFILE <- file("$process_r","w") ;
        }
      }
      
      close(PERLOUTPUTFILE) ;
    `;
    
    $this->write_file( $this->{START_R}, $bridge_code );

    chmod( 0777, $this->{ START_R } );
    
    return 1;
}


sub clean_log_dir {
    my $this = shift;
    
    my @files = (
        $this->{ START_R }   ,  # start.r
        $this->{ OUTPUT_R }  ,  # output.log
        $this->{ PROCESS_R } ,  # process.log
        $this->{ PID_R }     ,  # R.pid
        $this->{ LOCK_R }    ,  # lock.pid   
        # These files are explicitly not deleted. Why?
        #$this->{ STARTING_R },  # R.starting
        #$this->{ STOPPING_R },  # R.stopping
    );
    
    push @files, glob win32_space_escape( win32_double_bs( $this->{ INPUT_R_PREFIX }.'*'.$this->{ INPUT_R_SUFFIX } ) );

    for my $file (@files) {
        if (-e $file) {
            unlink $file or warn "Error: Could not remove file $file\n$!\n";
        }
    }
    
    return 1;    
}


sub read_file {
    # Read content from a file and return it
    my ($this, $file) = @_;
    open( my $fh, '<', $file ) or die "Error: Could not read file $file\n$!\n";
    my $content = join '', <$fh>;
    $content =~ s/\s//gs;
    close $fh;
    return 1;   
}


sub write_file {
    # Write some content in a file
    my ($this, $file, $content) = @_;
    open( my $fh, '>', $file ) or die "Error: Could not write file $file\n$!\n";
    print $fh "$content";
    close $fh;
    return 1;
}


sub touch_file {
    # Create an empty file
    my ($this, $file) = @_;
    open( my $fh, '>', $file ) or die "Error: Could not write file $file\n$!\n";
    close $fh;
    return 1;
}


sub win32_path_adjust {
    # Find potential R directories in the Windows Program Files folder and add
    # them to the PATH environment variable
    
    # Find potential R directories, e.g.  C:\Program Files (x86)\R-2.1\bin
    #                                 or  C:\Program Files\R\bin\x64
    my @r_dirs;
    my @prog_file_dirs   = ($PROGRAMFILES);                # e.g. C:\Program Files (x86)
    my ($programfiles_2) = ($PROGRAMFILES =~ m/^(.*) \(/); # e.g. C:\Program Files
    push @prog_file_dirs, $programfiles_2 if not $programfiles_2 eq $PROGRAMFILES;
    for my $prog_file_dir ( @prog_file_dirs ) {
        next if not -d $prog_file_dir;
        my @subdirs;
        my @globs = ( catfile($prog_file_dir, 'R'), catfile($prog_file_dir, 'R-*') );
        for my $glob ( @globs ) {
            $glob = win32_space_escape( win32_double_bs( $glob ) );
            push @subdirs, glob $glob; # DosGlob
        }
        for my $subdir (@subdirs) {
            my $subdir2 = catfile($subdir, 'bin');
            if ( -d $subdir2 ) {
                my $subdir3 = catfile($subdir2, 'x64');
                if ( -d $subdir3 ) {
                    push @r_dirs, $subdir3;
                }
                push @r_dirs, $subdir2;
            }
            push @r_dirs, $subdir;
        }
    }

    # Append R directories to PATH (order is important for File::Which)
    push @PATH, @r_dirs;
    
    return 1;
}


sub win32_space_quote {
    # Quote a path if it contains whitespaces
    my $path = shift;
    $path = '"'.$path.'"' if $path =~ /\s/;
    return $path;
}


sub win32_space_escape {
    # Escape spaces with a single backslash
    my $path = shift;
    $path =~ s/ /\\ /g;
    return $path;
}


sub win32_double_bs {
    # Double the backslashes
    my $path = shift;
    $path =~ s/\\/\\\\/g;
    return $path;
}


#sub Linux {
#    # Find the full path of the R binary on non-Windows systems
#    my( $this, %args ) = @_;
#    if ( !-s $this->{ R_BIN } ) {
#        my @files = qw(R R-project Rproject);
#        ## my @path = (split(":" , $ENV{PATH} || $ENV{Path} || $ENV{path} ) ,
#        # '/usr/lib/R/bin' , '/usr/lib/R/bin' ) ;
#        # CHANGE MADE BY CTBROWN 2008-06-16
#        # RESPONSE TO RT BUG#23948: bug in Statistics::R
#        my @path = (
#            split( ":", $ENV{ PATH } || $ENV{ Path } || $ENV{ path } ),
#            '/usr/lib/R/bin'
#        );
#        my $bin;
#        while ( !$bin && @files ) {
#            $bin = $this->find_file( shift( @files ), @path );
#        }
#        if ( !$bin ) {
#            my $path = `which R`;
#            $path =~ s/^\s+//s;
#            $path =~ s/\s+$//s;
#            if ( -e $path && -x $path ) { $bin = $path; }
#        }
#        $this->{ R_BIN } = $bin;
#    }  
#}


#sub Win32 {
#    # Find the full path of the R binary on Windows systems
#    my( $this, %args ) = @_;
#    if ( !-s $this->{ R_BIN } ) {
#        my $ver_dir = ( $this->cat_dir( catfile($ENV{ProgramFiles},'R') ) )[ 0 ];
#        my $bin = catfile($ver_dir, 'bin', 'Rterm.exe');
#        if ( !-e $bin || !-x $bin ) { $bin = undef; }
#        if ( !$bin ) {
#            my @dir = $this->cat_dir( catfile($ENV{ProgramFiles},'R'), undef, 1, 1 );
#            foreach my $dir_i ( @dir ) {
#                if ( $dir_i =~ /\/Rterm\.exe$/ ) { $bin = $dir_i; last; }
#            }
#        }
#        if ( !$bin ) {
#            my @files = qw(Rterm.exe);
#            my @path  = (
#                split( ";", $ENV{ PATH } || $ENV{ Path } || $ENV{ path } ) );
#            $bin = $this->find_file( \@files, @path );
#        }
#        $this->{ R_BIN } = $bin;
#    }
#    if ( !-s $this->{ R_BIN } ) {
#        die "Error: Could not find the R binary!\n";
#    }
#    $this->{ R_BIN } = '"'.$this->{ R_BIN }.'"' if $this->{ R_BIN } =~ /\s/;
#}


sub DESTROY {
    my $this = shift;
    $this->unlock;
    $this->stop if !$this->{ START_SHARED };
}


1;

__END__

=head1 NAME

Statistics::R::Bridge - A communication bridge between Perl and R.

=head1 DESCRIPTION

This module implements a communication bridge between Perl and R (R project for
statistical computing: L<http://www.r-project.org/>) in different architectures
and OS.

B<You shouldn't use this directly. See L<Statistics::R> for usage.>

=cut
