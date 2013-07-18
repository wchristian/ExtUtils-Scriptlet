use strictures;

package basic_test;

use Test::More qw(no_plan);
use utf8;

use ExtUtils::Scriptlet 'perl';

run();
exit;

sub ret($) { $_[0] > 0 ? $_[0] >> 8 : $_[0] }

sub run {

    is ret perl( "exit length qq[   ]" ), 3, "a simple scriptlet works";

    is eval { perl }, undef, 'code is required';

    my %newlines = ( MSWin32 => "\r\n", Darwin => "\r" );
    my $os_newline = $newlines{$^O} || "\n";
    is ret perl( "exit length qq[$os_newline]" ), length $os_newline, '\r in the code segment are handled correctly';

    isnt ret( eval { perl "exit 13", perl => "perl_does_not_exist" } || 1 ), 13, 'interpreter can be modified';

    my $code = 'local $/; exit length <STDIN>';
    is ret perl( $code, payload => "   " ), 3, "basic payload has the right length";

    is ret perl( $code, payload => $os_newline ), length $os_newline,
      "payload with os newlines has equal length on both sides";

    is ret perl( "$code", payload => " ä " ), 4, "payload is sent as utf8 by default";

    is ret perl( "$code", encoding => ":encoding(iso-8859-15)", payload => " ä " ), 3,
      "the payload encoding can be modified";

    is perl( "exit 13", args => "-v" ), 0, "custom args are passed to the interpreter";

    is ret perl( 'exit length $ARGV[0]', argv => "meep" ), 4, "argv is passed correctly to the interpreter";

    isnt perl( $code, args => "-e die" ), 0, "close is protected against SIGPIPE";

    return;
}
