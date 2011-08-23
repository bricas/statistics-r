package Statistics::R;

use strict;
use warnings;
use Statistics::R::Bridge;

our $VERSION = $Statistics::R::Bridge::VERSION;

my $this;


sub new {
    my ($class, @args) = @_;

    if( !defined $this ) {
        $this  = bless( {}, $class );
        # Create bridge
        $this->{ BRIDGE } = Statistics::R::Bridge->new( @args );
        $this->start;
    }

    return $this;
}


sub run {
   # Send a command to R, receive its output and return it, or die if there was
   # an error
   my ($this, $cmd) = @_;
   # Send command
   $this->send($cmd);
   # Receive command output
   my $output = $this->receive();
   # Check for errors
   if ($output =~ m/^<.*>$/) {
      my $msg = "Error running the R command\n".
                "   $cmd\n".
                "Reason\n".
                "   $output\n";
      die $msg;
   }
   return $output;
}


sub start {
    my $this = shift;
    delete $this->{ BRIDGE }->{ START_SHARED };
    # Start R if it was not already started
    my $status;
    if (not $this->is_started) {
        $status = $this->{ BRIDGE }->start;
    } else {
        $status = 1;
    }
}
*startR = \&start;


sub start_shared {
    shift->{ BRIDGE }->start_shared;
}
*start_sharedR = \&start_shared;


sub stop {
    my $this = shift;
    delete $this->{ BRIDGE }->{ START_SHARED };
    $this->{ BRIDGE }->stop;
}
*stopR = \&stop;


sub restart {
    shift->{ BRIDGE }->restart;
}
*restartR = \&restart;


sub bin {
    shift->{ BRIDGE }->bin;
}
*Rbin = \&bin;


sub lock {
    my $this = shift;
    $this->{ BRIDGE }->lock( @_ );
}


sub unlock {
    my $this = shift;
    shift->{ BRIDGE }->unlock( @_ );
}


sub is_blocked {
    my $this = shift;
    $this->{ BRIDGE }->is_blocked( @_ );
}


sub is_started {
    my $this = shift;
    $this->{ BRIDGE }->is_started;
}


sub send {
    my $this = shift;
    $this->{ BRIDGE }->send( @_ );
}


sub receive {
    my $this = shift;
    $this->{ BRIDGE }->read( @_ );
}
*read = \&receive;


sub clean_up {
    shift->send( 'rm(list = ls(all = TRUE))' );
}


sub error {
    # For backward compatibility
    return '';
}


1;

__END__

=head1 NAME

Statistics::R - Controls the R interpreter through Perl.

=head1 DESCRIPTION

This module controls the R interpreter (R project for statistical computing:
L<http://www.r-project.org/>). Multiple architectures and OS are supported and 
a single instance of R can be accessed by several Perl processes.

=head1 SYNOPSIS

  use Statistics::R;
  
  # Create a communication bridge with R and start R
  my $R = Statistics::R->new();
  
  # Run a simple command in R
  $R->run(q`postscript("file.ps" , horizontal=FALSE , width=500 , height=500 , pointsize=1)`);
  # Note the use of q`` to pass a string as-is

  # Pass some data to R. Note the use of qq`` instead of q`` to interpolate the
  # $input_string variable name
  my @input_array  = (1, 5, 10);
  my $input_string = join ', ', @input_array;
  $R->run(qq`plot(c($input_string), type = "l")`);

  $R->run(q`dev.off()`);

  # Retrieve data from R
  my $output_string = $R->run(qq`x = 123 \n print(x)`);

  # Stop R
  $R->stop();

=head1 METHODS

=over 4

=item new()

Create a Statistics::R bridge object between Perl and R and start() R. Available
options are:

=over 4

=item log_dir

The directory where the bridge between R and Perl will be created.

B<R and Perl need to have read and write access to the directory and Perl will
 change to this directory!>

I<By default it will be created at I<%TMP_DIR%/Statistics-R>.>

=item r_bin

The path to the R binary.

I<By default the path will be searched in the default installation path of R in the OS.>

=item r_dir

The directory of R.

=item tmp_dir

A temporary directory.

I<By default the temporary directory of the OS will be used>

=back

=item start()

Start R and set the communication bridge between Perl and R.

=item start_shared()

Start R or use an already running communication bridge.

=item stop()

Stop R and stop the bridge.

=item restart()

stop() and start() R.

=item bin()

Return the path to the R binary (executable).

=item send($CMD)

Send some command to be executed inside R. Note that I<$CMD> will be loaded by R with I<source()>

=item receive($TIMEOUT)

Get the output of R for the last group of commands sent to R by I<send()>.

=item lock()

Lock the bridge for your PID.

=item unlock()

Unlock the bridge if your PID have locked it.

=item is_blocked()

Return I<TRUE> if the bridge is blocked for your PID.

In other words, returns I<TRUE> if other process has I<lock()ed> the bridge.

=item is_started()

Return I<TRUE> if the R interpreter is started, or still started.

=item clean_up()

Clean up the environment, removing all the objects.

=back

=head1 INSTALL

To install this package you need to install R on your system first, since I<Statistics::R> need to find R path to work.

A standard installation of R on Win32 or Linux will work fine and be detected automatically by I<Statistics::R>.

Download page of R:
L<http://cran.r-project.org/banner.shtml>

Or go to the R web site:
L<http://www.r-project.org/>

=head1 EXECUTION FOR MULTIPLE PROCESSES

The main purpose of I<Statistics::R> is to start a single R interpreter that
listens to multiple Perl processes.

Note that to do that R and Perl need to be running with the same user/group level.

To start the I<Statistics::R> bridge, you can use the script I<statistics-r.pl>:

  $> statistics-r.pl start

From your script you need to use the I<start_shared()> option:

  use Statistics::R;
  
  my $R = Statistics::R->new();
  
  $R->start_shared;
  
  $R->send('x = 123');
  
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
