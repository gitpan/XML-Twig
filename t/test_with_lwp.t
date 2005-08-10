#!/bin/perl -w

use strict;
use Carp;

use FindBin qw($Bin);
BEGIN { unshift @INC, $Bin; }
use tools;


$|=1;

use XML::Twig;

eval { require LWP; };
if( $@) { import LWP; print "1..1\nok 1\n"; warn "skipping, LWP not available\n"; exit }

# skip on Win32, it looks like we have a problem there (named pipes?)
if( ($^O eq "MSWin32") && ($]<5.008) ) { print "1..1\nok 1\n"; warn "skipping, *parseurl methods not available on Windows with perl < 5.8.0\n"; exit }

my $TMAX=13; 

chdir 't';

print "1..$TMAX\n";

{
my $t= XML::Twig->new->parseurl( 'file:test_with_lwp.xml', LWP::UserAgent->new);
is( $t->sprint, '<doc><elt>text</elt></doc>', "parseurl");
}

{
my $t= XML::Twig->new->parseurl( 'file:test_with_lwp.xml');
is( $t->sprint, '<doc><elt>text</elt></doc>', "parseurl");
}

{
my $t= XML::Twig->new->safe_parseurl( 'file:test_with_lwp.xml');
is( $t->sprint, '<doc><elt>text</elt></doc>', "parseurl");
}

{
warn "\n\n### warning is normal here ###\n\n";
my $t= XML::Twig->new->safe_parseurl( 'file:test_with_lwp_no_file.xml');
ok( !$t, "no file");
ok( $@=~ m{^no element found}, "no file, error message");
}

{
my $t= XML::Twig->new->safe_parseurl( 'file:test_with_lwp_not_wf.xml');
ok( !$t, "not well-formed");
ok( $@=~ m{^no element found}, "not well-formed, error message");
}

{
my $t= XML::Twig->new->parsefile( 'test_with_lwp.xml');
is( $t->sprint, '<doc><elt>text</elt></doc>', "parseurl");
}

{
my $t= XML::Twig->new->safe_parsefile( 'test_with_lwp.xml');
is( $t->sprint, '<doc><elt>text</elt></doc>', "parseurl");
}

{
my $t= XML::Twig->new->safe_parsefile( 'test_with_lwp_no_file.xml');
ok( !$t, "no file");
ok( $@=~ m{^no element found}, "no file, error message");
}

{
my $t= XML::Twig->new->safe_parsefile( 'test_with_lwp_not_wf.xml');
ok( !$t, "not well-formed");
ok( $@=~ m{^no element found}, "not well-formed, error message");
}

exit 0;

{
my $warning_handler;
sub warnings_off
  { $warning_handler= $SIG{__WARN__};
    $SIG{__WARN__} = sub { };
  }
sub warnings_on
  { $SIG{__WARN__}= $warning_handler if( $warning_handler);
  }
}
