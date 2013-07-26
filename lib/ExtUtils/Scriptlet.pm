use strictures;

package ExtUtils::Scriptlet;

# VERSION

# ABSTRACT: run perl code in a new process without quoting it, on any OS

# COPYRIGHT

use Exporter 'import';
use autodie;
use Data::Dumper;

our @EXPORT_OK = qw( perl );

=head1 SYNOPSIS

    use ExtUtils::Scriptlet 'perl';
    
    my $module = "ExtUtils::Scriptlet";
    
    my $ret = perl <<"PERL_END", at_argv => [ 13 ];
        use lib "lib";
        require $module;
        print "$module ok\n";
        exit \$ARGV[0];
    PERL_END
    
    print $ret;

results in:

    ExtUtils::Scriptlet ok
    3328

=head1 DESCRIPTION

In short, this module allows you to dodge shell quoting to the largest extent
possible when you need to run some Perl in a child process. If you're not sure
why you need or want this, please read the MOTIVATION section further down.

=head1 WARNING

This is a very young module and its semantics might still change. Be sure to
read the change log before upgrading. Similarly, if you have suggestions to be
implemented in this regarding changes of data handling, additional functions or
additional options, please let me know.

=head1 FUNCTIONS

=head2 my $ret = perl( $code, %options )

Executes a given piece of perl code in a new process. Further arguments or data
can be sent to the child process with the options hash. Unless otherwise noted,
these options do not need any shell quoting whatsoever. If noted, all shell
quoting is your responsibility, and use is discouraged.

Returns the return value of the child process as it would be stored in $? or
returned by system().

=head3 at_argv

This option expects a reference to an array that can be safely serialized with
Data::Dumper. The contents of that array are then stored and accessible in @ARGV
in the child process. $ARGV or ARGV will not be populated.

=head3 payload

This option expects a single string. That string will be sent into the child
process' STDIN. Perl's newline conversion is not a factor in this, as it will be
disabled on both the host and child side. The encoding of the string on the host
side will be assumed to be UTF-8 by default, on the child side the contents of
STDIN will always be raw bytes.

=head3 encoding

If necessary this option can be used to change the encoding with which the
payload string is converted to bytes on the host side. It expects a single
encoding name ( iso-8859-7, utf8, UTF-8, etc. ).

=head3 perl

WARNING: Subject to shell quoting!

This is the path to the perl interpreter used to launch the child process. By
default it is $^X. It expects a single string.

=head3 args

WARNING: Subject to shell quoting! Use not encouraged.

This option expects a single string. That string can contain shell arguments
passed to the child perl, i.e. "-Ilib" and others. While some Perl options can
only be passed this way, most of the ones typically passed to child perls (like
-I) can be implemented in the code of the child instead.

=head3 argv

WARNING: Subject to shell quoting! Use not encouraged.

This option expects a single string. That string can contain can contain
arbitrary data that will be passed to the child perl as shell arguments that end
up in @ARGV, $ARGV or ARGV as per normal perlrun semantics. For your own safety
you are encouraged to use at_argv instead. Only use this if you NEED to use
$ARGV or ARGV and have no other option.

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

=head1 MOTIVATION

Consider this piece of code:

    system($^X, '-Ilib', '-e', qq{require strict; print "module ok"});

It looks reasonable, but it will break on windows. This is because system will
just send this as the command line:

    C:\Perl\bin\perl.exe -Ilib -e require strict; print "module ok"

So you need to quote the arguments manually. And if you're used to quoting your
-e with ', you make another mistake before you arrive on this:

    my $q = $^O eq 'MSWin32' ? '"' : '';
    system($^X, '-Ilib', '-e', qq|${q}require strict; print "module ok"${q}|);

That's pretty gross. But still not right, since the quotes around the string
won't be escaped properly. So you try this:

    my $q = $^O eq 'MSWin32' ? '"' : '';
    system($^X, '-Ilib', '-e', qq|${q}require strict; print \\"module ok\\"${q}|);

But that doesn't work, since Windows has different escaping rules. What you need
is this:

    my $q = $^O eq 'MSWin32' ? '"' : '';
    my $e = $^O eq 'MSWin32' ? '""' : '';
    system($^X, '-Ilib', '-e', qq|${q}require strict; print $e"module ok$e"${q}|);

However depending on the number of quotes in your string, and the command
parsing library you hit, that might not work either, so you need this:

    my $q = $^O eq 'MSWin32' ? '"' : '';
    system($^X, '-Ilib', '-e', qq|${q}require strict; print qq[module ok]${q}|);

That will work cross-platform. Unfortunately it's kind of a horror to get there
and it is hell to read after the fact. Plus, when you need to get more
complicated in the code you want to run you might end up running out of quoting
delimiters. And i haven't even touched on quoting the OTHER arguments, or
dealing with more fancy things like %PATH%, ^ or UTF-8.

Now you might say "Well, just use Win32::ShellQuote to take care of that!", but
sadly that's not 100% reliable either and i'm not even sure what other
surprises might lurk on other OSes or other shells. The best way is really to
just avoid the shell and quoting altogether.

ExtUtils::Scriptlet does that.

=head1 FUTURE

These are implementation points that i am considering, but not sure about yet.
If you have thoughts on these, let me know, please.

Right now it is necessary to use Capture::Tiny to get STDOUT and STDERR of the
child process. I am considering switching the implementation to IPC::Open3 in
the future to enable perl to return handles to those, or maybe just directly
capture STDOUT and STDERR and return them as strings.

Right now encoding only determines how the payload is converted to bytes. It
could also be used to decode in the child directly. I am not sure if that is a
good idea or not.

=cut
