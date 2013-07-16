use strictures;

package ExtUtils::Scriptlet;

# VERSION

# ABSTRACT:

# COPYRIGHT

use Exporter 'import';
use autodie;

our @EXPORT_OK = qw( perl );

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

    eval { close $fh };

    return $?;
}

1;
