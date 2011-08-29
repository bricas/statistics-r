package Statistics::R;

# CPAN dependencies: IPC::Run
# For running R in shared more, IPC::ShareLite is required. This will work on
# systems that can use shared memory and have semaphores, i.e. POSIX and windows
# systems

=head1 NAME

Statistics::R - Perl interface to control the R statistical program

=head1 DESCRIPTION

This module controls the R interpreter (R project for statistical computing:
L<http://www.r-project.org/>). Multiple architectures and OS are supported and 
a single instance of R can be accessed by several Perl processes.

=head1 SYNOPSIS

  use Statistics::R;
  
  # Create a communication bridge with R and start R
  my $R = Statistics::R->new();
  
  # Run simple R commands
  $R->run(q`postscript("file.ps" , horizontal=FALSE , width=500 , height=500 , pointsize=1)`);
  $R->run(q`plot(c(1, 5, 10), type = "l")`);
  $R->run(q`dev.off()`);

  # Pass and retrieve data
  my $input_value = 1;
  $R->set('x', $input_value);
  $R->run(q`y <- x^2`);
  my $output_value = $R->get('y');
  print "y = $output_value\n";

  $R->stop();

=head1 METHODS

=over 4

=item new()

Create a Statistics::R bridge object between Perl and R and start() R. Available
options are:


=over 4

=item shared

Start a shared bridge. See start().

=item log_dir

A directory where temporary files necessary for the bridge between R and Perl
will be stored.

B<R and Perl need to have read and write access to the directory!>

I<By default this will be a folder called Statistics-R and placed in a temporary
directory of the system>

=item r_bin

The path to the R binary. See I<INSTALLATION>.

=back

=item set()

Set the value of an R variable, e.g.

  $R->set( 'x', "apple" );

or 

  $R->set( 'y', [1, 2, 3] );


=item get( $)
 
Get the value of an R variable, e.g.

  my $x = $R->get( 'x' );  # $y is an scalar

or

  my $y = $R->get( 'y' );  # $x is an arrayref

=item start()

Start R and set the communication bridge between Perl and R. Pass the option
shared => 1 to use an already running bridge.

=item stop()

Stop R and stop the bridge.

=item restart()

stop() and start() R.

=item bin()

Return the path to the R binary (executable).

=item send($CMD)

Send some command to be executed inside R. Note that I<$CMD> will be loaded by R
with I<source()>. Prefer the run() command.

=item receive($TIMEOUT)

Get the output of R for the last group of commands sent to R by I<send()>.
Prefer the run() command.

=item lock()

Lock the bridge for your PID.

=item unlock()

Unlock the bridge if your PID have locked it.

=item is_locked()

Return I<TRUE> if the bridge is locked for your PID.

In other words, returns I<TRUE> if other process has I<lock()ed> the bridge.

=item is_started()

Return I<TRUE> if the R interpreter is started, or still started.

=item clean_up()

Clean up the environment, removing all the objects.

=back

=head1 INSTALLATION

To install this package you need to install R on your system first, since
I<Statistics::R> need to find R path to work. If R is in your PATH environment
variable, then it should be available from a terminal and be detected
automatically by I<Statistics::R>. This means that you do not have to do anything
on Linux systems to get I<Statistics::R> working. On Windows systems, in addition
to the folders described in PATH, the usual suspects will be checked for the
presence of the R binary, e.g. C:\Program Files\R. Your last recourse if
I<Statistics::R> does not find R is to specify its full path when calling new():

    my $R = Statistics::R->new( r_bin => $fullpath );

Download page of R:
L<http://cran.r-project.org/banner.shtml>

Or go to the R web site:
L<http://www.r-project.org/>

You also need to have the following CPAN Perl modules installed:

=over 4

=item Text::Balanced

=item Regexp::Common

=item IPC::Run

=back

=head1 EXECUTION FOR MULTIPLE PROCESSES

The main purpose of I<Statistics::R> is to start a single R interpreter that
listens to multiple Perl processes.

Note that to do that R and Perl need to be running with the same user/group level.

To start the I<Statistics::R> bridge, you can use the script I<statistics-r>:

  $> statistics-r start

From your script you need to use the I<start()> option in shared mode:

  use Statistics::R;
  
  my $R = Statistics::R->new();
  
  $R->start( shared => 1 );
  
  $R->run('x = 123');
  
  exit;

Note that in the example above the method I<stop()> wasn't called, since it will
close the bridge.

=head1 SEE ALSO

=over 4

=item * L<Statistics::R::Bridge>

=item * The R-project web site: L<http://www.r-project.org/>

=item * Statistics:: modules for Perl: L<http://search.cpan.org/search?query=Statistics&mode=module>

=back

=head1 AUTHOR

Graciliano M. P. E<lt>gm@virtuasites.com.brE<gt>

=head1 MAINTAINERS

Brian Cassidy E<lt>bricas@cpan.orgE<gt>

Florent Angly E<lt>florent.angly@gmail.comE<gt>

=head1 COPYRIGHT & LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 BUGS

All complex software has bugs lurking in it, and this program is no exception.
If you find a bug, please report it on the CPAN Tracker of Statistics::R:
L<http://rt.cpan.org/Dist/Display.html?Name=Statistics-R>

Bug reports, suggestions and patches are welcome. The Statistics::R code is
developed on Github (L<http://github.com/bricas/statistics-r>) and is under Git
revision control. To get the latest revision, run:

   git clone git@github.com:bricas/statistics-r.git

=cut


use 5.006;
use strict;
use warnings;
use File::Spec::Functions;
use File::DosGlob qw( glob );
use Env qw( @PATH $PROGRAMFILES );

use IPC::Run qw( harness start pump finish );

# require IPC::ShareLite for running R in shared mode


our $IS_WIN  = ($^O =~ m/^(?:.*?win32|dos)$/i) ? 1 : 0;
our $VERSION = '0.20-alpha';
our $PROG    = 'R';
our $EOS     = 'Statistics::R::EOS'; # Arbitrary string to indicate the end of the R output stream


sub new {
   # Create a new R communication object
   my ($class, %args) = @_;
   my $self = {};
   bless $self, ref($class) || $class;
   $self->initialize( %args );
   return $self;
}


sub is_started {
   return shift->{is_started};
}


sub is_shared {
   return shift->{is_shared};
}


{
no warnings 'redefine';
sub start {
   my ($self, @args) = @_;



   #### need to do something shared if needed here...
   my $status = $self->bridge->start or die "Error starting $PROG: $?\n";
   $self->{is_started} = 1;
   return $status;
}
}


sub stop {
   my ($self) = @_;
   my $status = $self->bridge->finish or die "Error stopping $PROG: $?\n";
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


sub run {
   # Pass the input and get the output
   my ($self, $cmd) = @_;

   # Need to start R now if it is not already running
   $self->start if not $self->is_started;

   # Wrap command for execution in R
   $self->stdin( $self->wrap_cmd($cmd) );

   # Pass input to R and get its output
   my $bridge = $self->bridge;
   $bridge->pump while $bridge->pumpable and $self->stdout !~ m/$EOS\s?\z/mgc;

   # Report errors
   my $err = $self->stderr;
   die "Error: $err\n" if $err;

   # Parse output, save it and reinitialize stdout
   my $out = $self->stdout;
   $out =~ s/$EOS\s?\z//mg;
   $self->result($out);
   $self->stdout('');

   return $out;
}


#---------- INTERNAL METHODS --------------------------------------------------#


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
      $bin = $PROG;
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


sub wrap_cmd {
   # Wrap a command to pass to R. Whether the command is successful or not, the
   # end of stream string will appear on stdout and indicate that R has finished
   # processing the data. Note that $cmd can be multiple R commands.
   my ($self, $cmd) = @_;
   $cmd = qq`tryCatch( {$cmd} , finally = write("$EOS",stdout()) )\n`;
   return $cmd;
}


#---------- METHODS FOR BACKWARD COMPATIBILITY --------------------------------#


{
   # Prevent "Name XXX used only once" warnings in this block
   no warnings 'once';
   *startR        = \&start;
   *stopR         = \&stop;
   *restartR      = \&restart;
   *Rbin          = \&bin;
   *start_sharedR = \&start_shared;
   *read          = \&receive;
   *is_blocked    = \&is_locked;
}



sub start_shared {
    my $this = shift;
    $this->start( shared => 1 );
}


sub lock {
    return 1;
}


sub unlock {
    return 1;
}


sub is_locked {
    return 1;
}


sub send {
   # Send a command to R
   my ($self, $cmd) = @_;
   $self->run($cmd);
   return 1;
}


sub receive {
   # Receive the result of an R command
   return shift->result;
}


sub error {
    # Get the error messages generated
    return '';
}


sub clean_up {
   # Clean up the content of the log dir
   return 1;
}


#---------- WINDOWS-SPECIFIC METHODS ------------------------------------------#


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
