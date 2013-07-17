use strictures;

package ExtUtils::Scriptlet;

# VERSION

# ABSTRACT: run perl code in a new process without quoting it, on any OS

# COPYRIGHT

use Exporter 'import';
use autodie;

our @EXPORT_OK = qw( perl );

=head1 FUNCTIONS

=head2 perl

Executes a given piece of perl code in a new process while dodging shell
quoting.

=cut

sub perl {
    my ( $code, %p ) = @_;

    die "No code given" if !$code;
    die "\\r is not permitted in the code segment" if $code =~ /\r/;

    $p{perl} ||= $^X;
    $p{encoding} ||= ":encoding(UTF-8)";
    $p{$_} ||= "" for qw( args argv payload );

    open                                 #
      my $fh,                            #
      "|- $p{encoding}",                 #
      "$p{perl} $p{args} - $p{argv}";    #

    print $fh                            #
      $code                              #
      . "\n__END__\n"                    #
      . $p{payload};                     #

    eval {
        # prevent the host perl from being terminated if the child perl dies
        local $SIG{PIPE} = 'IGNORE';
        close $fh;
    };

    return $?;
}

1;
