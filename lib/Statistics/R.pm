package Statistics::R;

# CPAN dependencies: IPC::Run
# For running R in shared more, IPC::ShareLite is required. This will work on
# systems that can use shared memory and have semaphores, i.e. POSIX and windows
# systems

# TODO:
#   method that returns whether R is running
#   start on run()
#   shared process

use strict;
use warnings;
use File::Spec::Functions;
use File::DosGlob qw( glob );
use Env qw( @PATH $PROGRAMFILES );
use IPC::Run qw( harness start pump finish );
# require IPC::ShareLite for running R in shared mode


our $IS_WIN = ($^O =~ m/^(?:.*?win32|dos)$/i) ? 1 : 0;

our $prog = 'R';
our $eos  = 'EOS'; # Arbitrary string to indicate the end of the R output stream


sub new {
   # Create a new R communication object
   my ($class, %args) = @_;
   my $self = {};
   bless $self, ref($class) || $class;
   $self->initialize( %args );
   return $self;
}


sub initialize {
   my ($self, %args) = @_;

   $self->{is_started} = 0;

   # Path of R binary
   my $bin;
   if ( $args{ r_bin } || $args{ R_bin } ) {
      # User-specified location
      $bin = $args{ r_bin } || $args{ R_bin };
      if ( !-s $self->{bin} ) {
         die "Error: Could not find the R binary at the specified location, $bin\n";
      }
   } else {
      # Windows-specific PATH adjustement
      win32_path_adjust() if $IS_WIN;
      # Let IPC::Run find the full path for the program
      $bin = $prog;
   }
   $bin = win32_space_quote( $bin ) if $IS_WIN; #### May not be needed

   ####
   # If running in shared mode, deal with IPC::ShareLite
   if ( (exists $args{ shared }) && ($args{ shared } == 1) ) {
      $self->{is_shared} = 1;
   }
   ####

   # Setup R shared inputs and outputs
   $self->{stdin } = '';
   $self->{stdout} = '';
   $self->{stderr} = '';

   # Start the communication bridge with R
   my $cmd = [ $bin, '--vanilla', '--slave' ];
   $self->{bridge} = harness $cmd, \$self->{stdin}, \$self->{stdout}, \$self->{stderr};

   return 1;
}


sub bridge {
   # Get / set the communication bridge
   return shift->{bridge};
}


sub stdin {
   # Get / set standard input string for R
   my ($self, $val) = @_;
   if (defined $val) {
      $self->{stdin} = $val;
   }
   return $self->{stdin};
}


sub stdout {
   # Get / set standard output string for R
   my ($self, $val) = @_;
   if (defined $val) {
      $self->{stdout} = $val;
   }
   return $self->{stdout};
}


sub stderr {
   # Get / set standard error string for R
   my ($self, $val) = @_;
   if (defined $val) {
      $self->{stderr} = $val;
   }
   return $self->{stderr};
}


sub result {
   # Get / set result of last R command
   my ($self, $val) = @_;
   if (defined $val) {
      $self->{result} = $val;
   }
   return $self->{result};   
}


sub is_started {
   return shift->{is_started};
}


sub is_shared {
   return shift->{is_shared};
}


sub start {
   my ($self) = @_;
   my $status = $self->bridge->start or die "Error starting $prog: $?\n";
   $self->{is_started} = 1;
   return $status;
}


sub stop {
   my ($self) = @_;
   my $status = $self->bridge->finish or die "Error stopping $prog: $?\n";
   $self->{is_started} = 0;
   return $status;
}


sub restart {
   my ($self) = @_;
   return $self->stop && $self->start;
}


sub pid {
   # Get the PID of the running R process
   return shift->bridge->{KIDS}->[0]->{PID};
}


sub bin {
   # Get the full path to the R binary program to use
   # This is accessible only after the bridge has start()ed
   return shift->bridge->{KIDS}->[0]->{PATH};
}

sub wrap_cmd {
   # Wrap a command to pass to R. Whether the command is successful or not, the
   # end of stream string will appear on stdout and indicate that R has finished
   # processing the data. Note that $cmd can be multiple R commands.
   my ($self, $cmd) = @_;
   $cmd = qq`tryCatch( {$cmd} , finally = write("$eos",stdout()) )\n`;
   return $cmd;
}


sub run {
   # Pass the input and get the output
   my ($self, $cmd) = @_;

   # Need to start R now if it is not already running
   $self->start if not $self->is_started;

   # Wrap command for execution in R
   $self->stdin( $self->wrap_cmd($cmd) );

   # Pass input to R and get its output
   my $bridge = $self->bridge;
   $bridge->pump while $bridge->pumpable and $self->stdout !~ m/$eos\s?\z/mgc;

   # Report errors
   my $err = $self->stderr;
   die "Error: $err\n" if $err;

   # Parse output, save it and reinitialize stdout
   my $out = $self->stdout;
   $out =~ s/$eos\s?\z//mg;
   $self->result($out);
   $self->stdout('');

   return $out;
}


sub send {
   # For backward compatibility. Send a command to R
   my ($self, $cmd) = @_;
   $self->run($cmd);
   return 1;
}


sub receive {
   # For backward compatibility. Receive result of an R command
   return shift->result;
}
*read = \&receive;


sub win32_path_adjust {
    # Find potential R directories in the Windows Program Files folder and add
    # them to the PATH environment variable
    
    # Find potential R directories, e.g.  C:\Program Files (x86)\R-2.1\bin
    #                                 or  C:\Program Files\R\bin\x64
    my @r_dirs;
    my @prog_file_dirs;
    if (defined $PROGRAMFILES) {
       push @prog_file_dirs, $PROGRAMFILES;                   # e.g. C:\Program Files (x86)
       my ($programfiles_2) = ($PROGRAMFILES =~ m/^(.*) \(/); # e.g. C:\Program Files
       push @prog_file_dirs, $programfiles_2 if not $programfiles_2 eq $PROGRAMFILES;
    }
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


1;
