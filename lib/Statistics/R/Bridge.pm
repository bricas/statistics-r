package Statistics::R::Bridge;

use strict;
use warnings;

our $VERSION = '0.04';

my $this;

sub new {
    my $class = shift;

    if( !defined $this ) {
        $this = bless( {}, $class );
        $this->Bridge( @_ );

        return unless $this->{ OS };
    }

    return $this;
}

sub Bridge {
    my $this = shift;

    if ( $^O =~ /^(?:.*?win32|dos)$/i ) {
        require Statistics::R::Bridge::Win32;
        $this->{ OS } = Statistics::R::Bridge::Win32->new( @_ );
    }
    else {
        require Statistics::R::Bridge::Linux;
        $this->{ OS } = Statistics::R::Bridge::Linux->new( @_ );
    }

    return undef if !$this->{ OS };
}

sub error {
    my $this = shift;
    Statistics::R->error( @_ );
}

sub start {
    my $this = shift;
    delete $this->{ OS }->{ START_SHARED };

    $this->{ OS }->start;
}

sub start_shared {
    shift->{ OS }->start_shared;
}

sub stop {
    my $this = shift;
    delete $this->{ OS }->{ START_SHARED };
    $this->{ OS }->stop;
}

sub restart {
    shift->{ OS }->restart;
}

sub bin {
    shift->{ OS }->{ R_BIN };
}

sub lock {
    my $this = shift;
    $this->{ OS }->lock( @_ );
}

sub unlock {
    my $this = shift;
    $this->{ OS }->unlock( @_ );
}

sub is_blocked {
    my $this = shift;
    $this->{ OS }->is_blocked( @_ );
}

sub send {
    my $this = shift;
    $this->{ OS }->send( @_ );
}

sub read {
    my $this = shift;
    $this->{ OS }->read( @_ );
}

1;

__END__

=head1 NAME

Statistics::R::Bridge - Implements a communication bridge between Perl and R (R-project).

=head1 DESCRIPTION

This will implements a communication bridge between Perl and R (R-project) in different architectures and OS.

=head1 USAGE

B<You shouldn't use this directly. See L<Statistics::R> for usage.>

=head1 METHODS

=over 4

=item start

Start R and the bridge.

=item stop

Stop R and the bridge.

=item restart

stop() and start() R.

=item bin

Return the path to the R binary (executable).

=item send ($CMD)

Send some command to be executed inside R. Note that I<$CMD> will be loaded by R with I<source()>

=item read ($TIMEOUT)

Read the output of R for the last group of commands sent to R by I<send()>.

=item error

Return the last error message.

=back

=head1 SEE ALSO

=over 4 

=item * L<Statistics::R>

=head1 AUTHOR

Graciliano M. P. E<lt>gm@virtuasites.com.brE<gt>

=head1 MAINTAINER

Brian Cassidy E<lt>bricas@cpan.orgE<gt>

=head1 COPYRIGHT & LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

