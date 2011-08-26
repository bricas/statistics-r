package Statistics::R;

use 5.006;
use strict;
use warnings;
use Regexp::Common;
use Text::Balanced qw ( extract_delimited extract_multiple );
use Statistics::R::Bridge;

our $VERSION = '0.10';


sub new {
    my ($class, @args) = @_;

    my $this = {};
    bless $this, ref($class) || $class;

    # Create bridge
    $this->{ BRIDGE } = Statistics::R::Bridge->new( @args );
    
    # Start R
    $this->start( @args );

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


sub set {
    # Assign a variable or array of variables in R. Use undef if you want to
    # assign NULL to an R variable
    my ($this, $varname, $arr) = @_;
    
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
    $this->run($cmd);
    return 1;
}


sub get {
    # Get the value of an R variable
    my ($this, $varname) = @_;
    my $string = $this->run(qq`print($varname)`);

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
            die "Error: Don't know how to handle this R output\n$string\n";
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


sub start {
    my ($this, %args) = @_;
    # Start R if it was not already started
    my $status;
    if (not $this->is_started) {
        if ( (exists $args{ shared }) && ($args{ shared } == 1) ) {
            # Start R in shared mode
            $status = $this->{ BRIDGE }->start_shared;
        } else {
            # Start R in regular mode
            delete $this->{ BRIDGE }->{ START_SHARED };
            $status = $this->{ BRIDGE }->start;
        }
    } else {
        $status = 1;
    }
}
*startR = \&start;


sub start_shared {
    my $this = shift;
    $this->start( shared => 1 );
}
*start_sharedR = \&start_shared;


sub stop {
    my $this = shift;
    delete $this->{ BRIDGE }->{ START_SHARED };
    $this->{ BRIDGE }->stop;
}
*stopR = \&stop;


sub restart {
    my $this = shift;
    $this->{ BRIDGE }->restart;
}
*restartR = \&restart;


sub bin {
    my $this = shift;
    $this->{ BRIDGE }->bin;
}
*Rbin = \&bin;


sub lock {
    my $this = shift;
    $this->{ BRIDGE }->lock( @_ );
}


sub unlock {
    my $this = shift;
    $this->{ BRIDGE }->unlock( @_ );
}


sub is_locked {
    my $this = shift;
    $this->{ BRIDGE }->is_locked( @_ );
}
*is_blocked = \&is_locked;


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
    my $this = shift;
    $this->{ BRIDGE }->clean_log_dir( @_ );
}


sub error {
    # For backward compatibility
    return '';
}


1;

__END__

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

=item File::Which

=back

=head1 EXECUTION FOR MULTIPLE PROCESSES

The main purpose of I<Statistics::R> is to start a single R interpreter that
listens to multiple Perl processes.

Note that to do that R and Perl need to be running with the same user/group level.

To start the I<Statistics::R> bridge, you can use the script I<statistics-r.pl>:

  $> statistics-r.pl start

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
