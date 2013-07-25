use strictures;

package ExtUtils::Scriptlet;

# VERSION

# ABSTRACT: run perl code in a new process without quoting it, on any OS

# COPYRIGHT

use Exporter 'import';
use autodie;
use Data::Dumper;

our @EXPORT_OK = qw( perl );

=head1 FUNCTIONS

=head2 perl

Executes a given piece of perl code in a new process while dodging shell
quoting.

=cut

sub perl {
    my ( $code, %p ) = @_;

    die "No code given" if !$code;

    # no idea why it needs 3, please send a letter if you know, so i can burn it
    $code =~ s/\r\n/\r\r\r\n/g if $^O eq "MSWin32";

    die "at_argv needs to be an array reference" if $p{at_argv} and "ARRAY" ne ref $p{at_argv};
    $p{at_argv} =
      !defined $p{at_argv}
      ? ""
      : sprintf "\@ARGV = \@{ %s };",
      Data::Dumper->new( [ $p{at_argv} || [] ] )->Useqq( 1 )->Indent( 0 )->Dump;

    $p{perl} ||= $^X;
    $p{encoding} = sprintf ":encoding(%s)", $p{encoding} || "UTF-8";
    $p{$_} = defined $p{$_} ? $p{$_} : "" for qw( args argv payload );

    open                                 #
      my $fh,                            #
      "|- :raw $p{encoding}",            # :raw protects the payload from write
                                         # mangling (newlines)
      "$p{perl} $p{args} - $p{argv}";    #

    print $fh                            #
      "$p{at_argv};"                     #
      . "binmode STDIN;"                 # protect the payload from read
                                         # mangling (newlines, system locale)
      . "$code;"                         # unpack and execute serialized code
      . "\n__END__\n"                    #
      . $p{payload};                     #

    eval {
        local $SIG{PIPE} = 'IGNORE';     # prevent the host perl from being
                                         # terminated if the child perl dies
        close $fh;                       # grab exit value so we can return it
    };

    return $?;
}

1;
