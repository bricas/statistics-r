package Statistics::R;


use 5.006;
use strict;
use warnings;
use Regexp::Common;
use File::Spec::Functions;
use IPC::Run qw( harness start pump finish );
use Text::Balanced qw ( extract_delimited extract_multiple );

our $VERSION = '0.20-beta';
our $PROG    = 'R';                  # executable we are after... R
our $EOS     = 'Statistics::R::EOS'; # string to signal the R output stream end
our $IS_WIN  = ($^O =~ m/^(?:.*?win32|dos)$/i) ? 1 : 0;

if ($IS_WIN) {
   require Statistics::R::Win32;
}


our ($SHARED_BRIDGE, $SHARED_STDIN, $SHARED_STDOUT, $SHARED_STDERR);


=head1 NAME

Statistics::R - Perl interface to interact with the R statistical program

=head1 DESCRIPTION

Statistics::R is a module to controls the R interpreter (R project for statistical
computing: L<http://www.r-project.org/>). It lets you start R, pass commands to
it and retrieve the output. A shared mode allow to have several instances of
Statistics::R talk to the same R process. This module works on GNU/Linux, MS
Windows and probably many more systems.

=head1 SYNOPSIS

  use Statistics::R;
  
  # Create a communication bridge with R and start R
  my $R = Statistics::R->new();
  
  # Run simple R commands
  my $output_file = "file.ps";
  $R->run(qq`postscript("$output_file" , horizontal=FALSE , width=500 , height=500 , pointsize=1)`);
  $R->run(q`plot(c(1, 5, 10), type = "l")`);
  $R->run(q`dev.off()`);

  # Pass and retrieve data (scalars or arrays)
  my $input_value = 1;
  $R->set('x', $input_value);
  $R->run(q`y <- x^2`);
  my $output_value = $R->get('y');
  print "y = $output_value\n";

  $R->stop();

=head1 METHODS

=over 4

=item new()

Create a Statistics::R bridge object between Perl and R. Available options are:


=over 4

=item shared

Start a shared bridge. See start(). 

=item r_bin

The path to the R binary. See I<INSTALLATION>.

=back


=item run()

Execute in R one or several commands passed as a string. Also, start() R if it
was not yet started.

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

=item is_started()

Is R running?

=item pid()

What is the pid of the running R process


=item is_shared()

=back

=head1 LEGACY METHODS

=over 4

=item send($CMD)

Send some command to be executed inside R. Prefer the run() command instead.

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

=head1 AUTHORS

Graciliano M. P. E<lt>gm@virtuasites.com.brE<gt>

Florent Angly E<lt>florent.angly@gmail.comE<gt> (Statistics::R in 2011 rewrite)

=head1 MAINTAINERS

Brian Cassidy E<lt>bricas@cpan.orgE<gt>

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


sub new {
   # Create a new R communication object
   my ($class, %args) = @_;
   my $self = {};
   bless $self, ref($class) || $class;
   $self->initialize( %args );
   return $self;
}


sub is_shared {
   # Get (/ set) the whether or not Statistics::R is setup to run in shared mode
   my ($self, $val) = @_;
   if (defined $val) {
      $self->{is_shared} = $val;
   }
   return $self->{is_shared};
}


{
no warnings 'redefine';
sub start {
   my ($self, %args) = @_;
   my $status = 1;
   if (not $self->is_started) {

      # If shared mode option of start() requested, rebuild the bridge in shared
      # mode. Don't use this option though. It is only here to cater for the legacy
      # method start_shared()
      if ( exists($args{shared}) && ($args{shared} == 1) ) {
         $self->is_shared( 1 );
         $self->bridge( 1 );
      }

      # Now, start R
      my $bridge = $self->bridge;
      $status = $bridge->start or die "Error starting $PROG: $?\n";
      $self->bin( $bridge->{KIDS}->[0]->{PATH} );
   }

   return $status;
}
}


sub stop {
   my ($self) = @_;
   my $status = 1;
   if ($self->is_started) {
      $status = $self->bridge->finish or die "Error stopping $PROG: $?\n";
   }
   return $status;
}


sub restart {
   my ($self) = @_;
   return $self->stop && $self->start;
}


sub is_started {
   # Query whether or not R is currently running
   return shift->bridge->{STATE} eq IPC::Run::_started ? 1 : 0;
}


sub pid {
   # Get (/ set) the PID of the running R process. It is accessible only after
   # the bridge has start()ed
   return shift->bridge->{KIDS}->[0]->{PID};
}


sub bin {
   # Get / set the full path to the R binary program to use. Unless you have set
   # the path yourself, it is accessible only after the bridge has start()ed
   my ($self, $val) = @_;
   if (defined $val) {
      $self->{bin} = $val;
   }
   return $self->{bin};
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
   die "Problem running an R command: $err\n" if $err;

   # Parse output, save it and reinitialize stdout
   my $out = $self->stdout;
   $out =~ s/$EOS\s?\z//mg;
   chomp $out;
   $self->result($out);
   $self->stdout('');

   return $out;
}



sub set {
   # Assign a variable or array of variables in R. Use undef if you want to
   # assign NULL to an R variable
   my ($self, $varname, $arr) = @_;
    
   # Check variable type, convert everything into an arrayref
   my $ref = ref $arr;
   if ($ref eq '') {
      # This is a scalar
      $arr = [ $arr ];
   } elsif ($ref eq 'ARRAY') {
      # This is an array reference, nothing to do
   } else {
      die "Error: Import variable of type $ref is not supported\n";
   }

   # Quote strings and nullify undef variables
   for (my $i = 0; $i < scalar @$arr; $i++) {
      if (defined $$arr[$i]) {
         if ( $$arr[$i] !~ /$RE{num}{real}/ ) {
            $$arr[$i] = '"'.$$arr[$i].'"';
         }
      } else {
         $$arr[$i] = 'NULL';
      }
   }

   # Build a string and run it to import data
   my $cmd = $varname.' <- c('.join(', ',@$arr).')';
   $self->run($cmd);
   return 1;
}


sub get {
   # Get the value of an R variable
   my ($self, $varname) = @_;
   my $string = $self->run(qq`print($varname)`);

   # Parse R output
   my $value;
   if ($string eq 'NULL') {
      $value = undef;
   } elsif ($string =~ m/^\s*\[\d+\]/) {
      # Vector: its string look like:
      # ' [1]  6.4 13.3  4.1  1.3 14.1 10.6  9.9  9.6 15.3
      #  [16]  5.2 10.9 14.4'
      my @lines = split /\n/, $string;
      for (my $i = 0; $i < scalar @lines; $i++) {
         $lines[$i] =~ s/^\s*\[\d+\] //;
      }
      $value = join ' ', @lines;
   } else {
      my @lines = split /\n/, $string;
      if (scalar @lines == 2) {
         # String looks like: '    mean 
         # 10.41111 '
         # Extract value from second line
         $value = $lines[1];
         $value =~ s/^\s*(\S+)\s*$/$1/;
      } else {
         #die "Error: Don't know how to handle this R output\n$string\n";
         $value = $string;
      }
   }

   # Clean
   my @arr;
   if (not defined $value) {
      @arr = ( undef );
   } else {
      # Split string into an array, paying attention to strings containing spaces
      @arr = extract_multiple( $value, [sub { extract_delimited($_[0],q{ '"}) },] );
      for (my $i = 0; $i < scalar @arr; $i++) {
         my $elem = $arr[$i];
         if ($elem =~ m/^\s*$/) {
            # Remove elements that are simply whitespaces
            splice @arr, $i, 1;
            $i--;
         } else {
            # Trim whitespaces
            $arr[$i] =~ s/^\s*(.*?)\s*$/$1/;
            # Remove double-quotes
            $arr[$i] =~ s/^"(.*)"$/$1/; 
         }
      }
   }

   # Return either a scalar of an arrayref
   my $ret_val;
   if (scalar @arr == 1) {
       $ret_val = $arr[0];
   } else {
       $ret_val = \@arr;
   }

   return $ret_val;
}


#---------- INTERNAL METHODS --------------------------------------------------#


sub initialize {
   my ($self, %args) = @_;

   # Path of R binary
   my $bin;
   if ( $args{ r_bin } || $args{ R_bin } ) {
      $bin = $args{ r_bin } || $args{ R_bin };
   } else {
      $bin = $PROG; # IPC::Run will find the full path for the program later
   }

   #### May not be needed
   $bin = win32_space_quote( $bin ) if $IS_WIN;
   ####

   $self->bin( $bin );

   # Using shared mode?
   if ( exists($args{shared}) && ($args{shared} == 1) ) {
      $self->is_shared( 1 );
   } else {
      $self->is_shared( 0 );
   }

   # Build the bridge
   $self->bridge( 1 );

   return 1;
}


sub bridge {
   # Get or build the communication bridge and IOs with R
   my ($self, $build) = @_;
   if ($build) {
      my $cmd = [ $self->bin, '--vanilla', '--slave' ];
      if (not $self->is_shared) {
         my ($stdin, $stdout, $stderr);
         $self->{stdin}  = \$stdin;
         $self->{stdout} = \$stdout;
         $self->{stderr} = \$stderr;
         $self->{bridge} = harness $cmd, $self->{stdin}, $self->{stdout}, $self->{stderr};
      } else {
         $self->{stdin}  = \$SHARED_STDIN ;
         $self->{stdout} = \$SHARED_STDOUT;
         $self->{stderr} = \$SHARED_STDERR;
         if (not defined $SHARED_BRIDGE) {
            # The first Statics::R instance builds the bridge
            $SHARED_BRIDGE = harness $cmd, $self->{stdin}, $self->{stdout}, $self->{stderr};
         }
         $self->{bridge} = $SHARED_BRIDGE;
      }
   }
   return $self->{bridge};
}


sub stdin {
   # Get / set standard input string for R
   my ($self, $val) = @_;
   if (defined $val) {
      ${$self->{stdin}} = $val;
   }
   return ${$self->{stdin}};
}


sub stdout {
   # Get / set standard output string for R
   my ($self, $val) = @_;
   if (defined $val) {
      ${$self->{stdout}} = $val;
   }
   return ${$self->{stdout}};
}


sub stderr {
   # Get / set standard error string for R
   my ($self, $val) = @_;
   if (defined $val) {
      ${$self->{stderr}} = $val;
   }
   return ${$self->{stderr}};
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
   $cmd = qq`tryCatch( {$cmd} ); write("$EOS",stdout())\n`;
   return $cmd;
}


#---------- LEGACY METHODS ----------------------------------------------------#


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
   *receive       = \&result;
}


sub start_shared {
    my $self = shift;
    $self->start( shared => 1 );
}


sub lock {
    return 1;
}


sub unlock {
    return 1;
}


sub is_locked {
    return 0;
}


sub send {
   # Send a command to R
   my ($self, $cmd) = @_;
   $self->run($cmd);
   return 1;
}


sub error {
    return '';
}


sub clean_up {
   return 1;
}


1;
