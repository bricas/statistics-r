package Statistics::R::Bridge::Linux;

use strict;
use warnings;

use base 'Statistics::R::Bridge::pipe';

our $VERSION = '0.04';

sub Linux {
    my( $this, %args ) = @_;

    $this->{ R_BIN } = $args{ r_bin } || $args{ R_bin } || '';
    $this->{ R_DIR } = $args{ r_dir } || $args{ R_dir } || '';
    $this->{ TMP_DIR } = $args{ tmp_dir } || '';

    if ( !-s $this->{ R_BIN } ) {
        my @files = qw(R R-project Rproject);
        ## my @path = (split(":" , $ENV{PATH} || $ENV{Path} || $ENV{path} ) , '/usr/lib/R/bin' , '/usr/lib/R/bin' ) ;
        # CHANGE MADE BY CTBROWN 2008-06-16
        # RESPONSE TO RT BUG#23948: bug in Statistics::R
        my @path = (
            split( ":", $ENV{ PATH } || $ENV{ Path } || $ENV{ path } ),
            '/usr/lib/R/bin'
        );

        my $bin;
        while ( !$bin && @files ) {
            $bin = $this->find_file( shift( @files ), @path );
        }

        if ( !$bin ) {
            my $path = `which R`;
            $path =~ s/^\s+//s;
            $path =~ s/\s+$//s;
            if ( -e $path && -x $path ) { $bin = $path; }
        }

        $this->{ R_BIN } = $bin;
    }

    if ( !$this->{ R_DIR } && $this->{ R_BIN } ) {
        ( $this->{ R_DIR } )
            = ( $this->{ R_BIN } =~ /^(.*?)[\\\/]+[^\\\/]+$/s );
        $this->{ R_DIR } =~ s/\/bin$//;
    }

    if ( !$this->{ TMP_DIR } ) {
        foreach my $dir ( qw(/tmp /usr/local/tmp) ) {
            if ( -d $dir ) { $this->{ TMP_DIR } = $dir; last; }
        }
    }

    if ( !-s $this->{ R_BIN } ) {
        $this->error( "Can'find R binary!" );
        return undef;
    }
    if ( !-d $this->{ R_DIR } ) {
        $this->error( "Can'find R directory!" );
        return undef;
    }

    $this->{ START_CMD } = "$this->{R_BIN} --slave --vanilla ";

    if ( !$args{ log_dir } ) {
        $args{ log_dir } = "$this->{TMP_DIR}/Statistics-R";
    }

    $this->{ OS } = 'linux';

    $this->pipe( %args );
}

1;

__END__

=head1 NAME

Statistics::R::Bridge::Linux - Handles R on Linux.

=head1 DESCRIPTION

This will handle R on Linux.

=head1 SEE ALSO

=over 4 

=item * L<Statistics::R>

=item * L<Statistics::R::Bridge>

=head1 AUTHOR

Graciliano M. P. E<lt>gm@virtuasites.com.brE<gt>

=head1 MAINTAINER

Brian Cassidy E<lt>bricas@cpan.orgE<gt>

=head1 COPYRIGHT & LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

