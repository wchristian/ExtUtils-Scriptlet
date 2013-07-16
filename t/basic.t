use strictures;

package basic_test;

use Test::More qw(no_plan);
use utf8;

use ExtUtils::Scriptlet 'perl';

run();
exit;

sub ret($) { $_[0] >> 8 }

sub run {

    is ret perl( "exit length qq[   ]" ), 3, "a simple scriptlet works";

    is eval { perl }, undef, 'code is required';

    is eval { perl "\r" }, undef, '\r are not allowed in the code segment';

    my $code = 'local $/; exit length <STDIN>';
    is ret perl( $code, payload => "   " ), 3, "basic payload has the right length";

    my %newlines = ( MSWin32 => "\r\n", Darwin => "\r" );
    my $newline = $newlines{$^O} || "\n";
    my $os_payload = " $newline ";
    is ret perl( $code, payload => $os_payload ), length $os_payload, "payload with newlines has the right length";

    is ret perl( $code, payload => " ä " ), 4, "payload is sent as utf8 by default";

    is ret perl( $code, encoding => ":encoding(iso-8859-15)", payload => " ä " ), 3,
      "the payload encoding can be modified";

    is ret perl( 'exit length $ARGV[0]', argv => "meep" ), 4, "argv is passed correctly to the interpreter";

    return;
}
