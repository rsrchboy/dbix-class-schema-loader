package # hide from PAUSE
    DBIx::Class::Schema::Loader::Utils;

use strict;
use warnings;
use Data::Dumper ();
use Test::More;
use namespace::clean;
use Exporter 'import';

our @EXPORT_OK = qw/split_name dumper dumper_squashed eval_package_without_redefine_warnings class_path no_warnings warnings_exist warnings_exist_silent slurp_file/;

use constant BY_CASE_TRANSITION =>
    qr/(?<=[[:lower:]\d])[\W_]*(?=[[:upper:]])|[\W_]+/;

use constant BY_NON_ALPHANUM =>
    qr/[\W_]+/;

my $LF   = "\x0a";
my $CRLF = "\x0d\x0a";

sub split_name($) {
    my $name = shift;

    split $name =~ /[[:upper:]]/ && $name =~ /[[:lower:]]/ ? BY_CASE_TRANSITION : BY_NON_ALPHANUM, $name;
}

sub dumper($) {
    my $val = shift;

    my $dd = Data::Dumper->new([]);
    $dd->Terse(1)->Indent(1)->Useqq(1)->Deparse(1)->Quotekeys(0)->Sortkeys(1);
    return $dd->Values([ $val ])->Dump;
}

sub dumper_squashed($) {
    my $val = shift;

    my $dd = Data::Dumper->new([]);
    $dd->Terse(1)->Indent(1)->Useqq(1)->Deparse(1)->Quotekeys(0)->Sortkeys(1)->Indent(0);
    return $dd->Values([ $val ])->Dump;
}

sub eval_package_without_redefine_warnings {
    my ($pkg, $code) = @_;

    my $warn_handler = $SIG{__WARN__} || sub { warn @_ };

    local $SIG{__WARN__} = sub {
        $warn_handler->(@_)
            unless $_[0] =~ /^Subroutine \S+ redefined/;
    };

    # This hairiness is to handle people using "use warnings FATAL => 'all';"
    # in their custom or external content.
    my @delete_syms;
    my $try_again = 1;

    while ($try_again) {
        eval $code;

        if (my ($sym) = $@ =~ /^Subroutine (\S+) redefined/) {
            delete $INC{ +class_path($pkg) };
            push @delete_syms, $sym;

            foreach my $sym (@delete_syms) {
                no strict 'refs';
                undef *{"${pkg}::${sym}"};
            }
        }
        elsif ($@) {
            die $@ if $@;
        }
        else {
            $try_again = 0;
        }
    }
}

sub class_path {
    my $class = shift;

    my $class_path = $class;
    $class_path =~ s{::}{/}g;
    $class_path .= '.pm';

    return $class_path;
}

sub no_warnings(&;$) {
    my ($code, $test_name) = @_;

    my $failed = 0;

    my $warn_handler = $SIG{__WARN__} || sub { warn @_ };
    local $SIG{__WARN__} = sub {
        $failed = 1;
        $warn_handler->(@_);
    };

    $code->();

    ok ((not $failed), $test_name);
}

sub warnings_exist(&$$) {
    my ($code, $re, $test_name) = @_;

    my $matched = 0;

    my $warn_handler = $SIG{__WARN__} || sub { warn @_ };
    local $SIG{__WARN__} = sub {
        if ($_[0] =~ $re) {
            $matched = 1;
        }
        else {
            $warn_handler->(@_)
        }
    };

    $code->();

    ok $matched, $test_name;
}

sub warnings_exist_silent(&$$) {
    my ($code, $re, $test_name) = @_;

    my $matched = 0;

    local $SIG{__WARN__} = sub { $matched = 1 if $_[0] =~ $re; };

    $code->();

    ok $matched, $test_name;
}

sub slurp_file($) {
    open my $fh, '<:encoding(UTF-8)', shift;
    my $data = do { local $/; <$fh> };
    close $fh;

    $data =~ s/$CRLF|$LF/\n/g;

    return $data;
}

1;
# vim:et sts=4 sw=4 tw=0:
