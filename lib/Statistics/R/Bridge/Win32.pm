package Statistics::R::Bridge::Win32;

use strict;
use warnings;

use base 'Statistics::R::Bridge::pipe';

our $VERSION = '0.04';

sub Win32 {
    my( $this, %args ) = @_;

    $this->{ R_BIN } = $args{ r_bin } || $args{ R_bin };
    $this->{ R_DIR } = $args{ r_dir } || $args{ R_dir };
    $this->{ TMP_DIR } = $args{ tmp_dir };

    if ( !-s $this->{ R_BIN } ) {
        my $ver_dir = ( $this->cat_dir( "$ENV{ProgramFiles}/R" ) )[ 0 ];

        my $bin = "$ver_dir/bin/Rterm.exe";
        if ( !-e $bin || !-x $bin ) { $bin = undef; }

        if ( !$bin ) {
            my @dir = $this->cat_dir( "$ENV{ProgramFiles}/R", undef, 1, 1 );
            foreach my $dir_i ( @dir ) {
                if ( $dir_i =~ /\/Rterm\.exe$/ ) { $bin = $dir_i; last; }
            }
        }

        if ( !$bin ) {
            my @files = qw(Rterm.exe);
            my @path  = (
                split( ";", $ENV{ PATH } || $ENV{ Path } || $ENV{ path } ) );
            $bin = $this->find_file( \@files, @path );
        }

        $this->{ R_BIN } = $bin;
    }

    if ( !$this->{ R_DIR } && $this->{ R_BIN } ) {
        ( $this->{ R_DIR } )
            = ( $this->{ R_BIN } =~ /^(.*?)[\\\/]+[^\\\/]+$/s );
        $this->{ R_DIR } =~ s/\/bin$//;
    }

    if ( !$this->{ TMP_DIR } ) {
        $this->{ TMP_DIR } = $ENV{ TMP } || $ENV{ TEMP };
        if ( !$this->{ TMP_DIR } ) {
            foreach
                my $dir ( qw(c:/tmp c:/temp c:/windows/tmp c:/windows/temp) )
            {
                if ( -d $dir ) { $this->{ TMP_DIR } = $dir; last; }
            }
        }
    }

    if ( !-s $this->{ R_BIN } ) {
        $this->error( "Can'find R binary!" );
        return UNDEF;
    }
    if ( !-d $this->{ R_DIR } ) {
        $this->error( "Can'find R directory!" );
        return UNDEF;
    }

    $this->{ R_BIN }   =~ s/\//\\/g;
    $this->{ R_DIR }   =~ s/\//\\/g;
    $this->{ TMP_DIR } =~ s/[\/\\]+/\//g;

    my $exec = $this->{ R_BIN };
    $exec = "\"$exec\"" if $exec =~ /\s/;

    $this->{ START_CMD } = "$exec --slave --vanilla";

    if ( !$args{ log_dir } ) {

# $args{log_dir} = "$this->{R_DIR}/Statistics-R" ;
# Bug Fix by CTB:  Reponse to RT Bug #17956: Win32: log_dir is not in tmp_dir by default as advertised
        $args{ log_dir } = "$this->{TMP_DIR}/Statistics-R";
        $args{ log_dir } =~ s/\\+/\//gs;
    }

    $this->{ OS } = 'win32';

    $this->pipe( %args );
}

1;

__END__

=head1 NAME

Statistics::R::Bridge::Win32 - Handles R on Win32.

=head1 DESCRIPTION

This will handle R on Win32.

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

