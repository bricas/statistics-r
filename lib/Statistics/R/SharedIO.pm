package Statistics::R::SharedIO;

use Carp;
use strict;
use warnings;
use IPC::ShareLite;

our $SHARE;


=head1 NAME

Statistics::R::SharedIO - Store scalars in shared memory.

=head1 DESCRIPTION

This module allows to place scalars in a machine's shared memory so that several
processes can have access to the same data. This is implemented as a tied scalar
method that binds to a L<IPC::ShareLite> object.


=head1 SYNOPSIS

   use Statistics::R::SharedIO;

   # Place something in shared memory
   my $share_name = 'out';
   my $var1;
   tie $var1, 'Statistics::R::SharedIO', $share_name;
   $var1 = 'Lorem ipsum dolor sit amet';
   print "var1 = $var1\n";

   # Any other variable tied to the same share now has the same value
   my $var2;
   tie $var2, 'Statistics::R::SharedIO', $share_name;
   print "var2 = $var2\n";


=head1 METHODS

See L<perltie>.

=head1 SEE ALSO

L<IPC::ShareLite>.

=head1 AUTHOR

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


sub TIESCALAR {
   my ($class, $share_name) = @_;
   $SHARE = IPC::ShareLite->new(
      -key     => $share_name,
      -create  => 'yes',
      -destroy => 'no'
   ) or die "Error: Could not create an IPC::ShareLite object\n$!\n";
   my $scalar = undef;
   return bless \$scalar, $class;
}


sub STORE {
   my ($self, $value) = @_;
   $SHARE->store( $value );
}


sub FETCH {
   my ($self) = @_;
   return $SHARE->fetch();
}


sub DESTROY {
   my ($self) = @_;
   $SHARE = undef;
}


1;
