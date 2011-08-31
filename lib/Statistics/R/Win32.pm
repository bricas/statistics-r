package Statistics::R::Win32;


use strict;
use warnings;
use File::Spec::Functions;
use File::DosGlob qw( glob );
use Env qw( @PATH $PROGRAMFILES );

use vars qw{@ISA @EXPORT};

BEGIN {
   @ISA     = 'Exporter';
   @EXPORT  = qw{
      win32_path_adjust
      win32_space_quote
      win32_space_escape
      win32_double_bs
   };
}

our $PROG = 'R';


=head1 NAME

Statistics::R::Win32 - Helper functions for Statistics::R on MS Windows platforms

=head1 DESCRIPTION

Helper functions to deal with environment variables and escape file paths on
MS Windows platforms.

=head1 SYNOPSIS

   if ( $^O =~ m/^(?:.*?win32|dos)$/i ) {
      require Statistics::R::Win32;
   }

=head1 METHODS

=over 4

=item win32_path_adjust( )

Looks for paths where R could be installed, e.g. C:\Program Files (x86)\R-2.1\bin
and add it to the PATH environment variable.

=item win32_space_quote( )

Takes a path and return a path that is surrounded by double-quotes if the path
contains whitespaces. Example:

   C:\Program Files\R\bin\x64

becomes

   "C:\Program Files\R\bin\x64"

=item win32_space_escape( )

Takes a path and return a path where spaces have been escaped by a backslash.
contains whitespaces. Example:

   C:\Program Files\R\bin\x64

becomes

   C:\Program\ Files\R\bin\x64

=item win32_double_bs

Takes a path and return a path where each backslash was replaced by two backslashes.
 Example:

   C:\Program Files\R\bin\x64

becomes

   C:\\Program Files\\R\\bin\\x64

=back

=head1 SEE ALSO

=over 4

=item * L<Statistics::R>

=back

=head1 AUTHORS

Florent Angly E<lt>florent.angly@gmail.comE<gt> (2011 rewrite)

Graciliano M. P. E<lt>gm@virtuasites.com.brE<gt> (original code)

=head1 MAINTAINER

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


# Adjust PATH environment variable when this module is loaded.
win32_path_adjust();


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
      my @globs = ( catfile($prog_file_dir, $PROG), catfile($prog_file_dir, $PROG.'-*') );
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

   # Append R directories to PATH (order is important)
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
