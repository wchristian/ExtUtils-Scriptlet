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

    # serialize code to protect from newline mangling
    $code = Data::Dumper->new( [$code] )->Useqq( 1 )->Dump;

    $p{perl} ||= $^X;
    $p{encoding} ||= ":encoding(UTF-8)";
    $p{$_} ||= "" for qw( args argv payload );

    open                                 #
      my $fh,                            #
      "|- :raw $p{encoding}",            # :raw protects the payload from write
                                         # mangling (newlines)
      "$p{perl} $p{args} - $p{argv}";    #

    print $fh                            #
      "binmode STDIN;"                   # protect the payload from read
                                         # mangling (newlines, system locale)
      . "$code; eval \$VAR1;"            # unpack and execute serialized code
      . "die \$@ if \$@;"                #
      . "\n__END__\n"                    #
      . $p{payload};                     #

    eval {

        # prevent the host perl from being terminated if the child perl dies
        local $SIG{PIPE} = 'IGNORE';
        close $fh;                       # grab exit value so we can return it
    };

    return $?;
}

1;
