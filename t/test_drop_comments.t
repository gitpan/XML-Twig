#!/usr/local/bin/perl -w
use strict;
use XML::Twig;

print "1..3\n";

my $xml = <<XML_TEST;
<xml_root>
  <!-- some comment -->
  <key>value</key>
</xml_root>
XML_TEST

{
    my $twig1 = XML::Twig->new(comments => 'keep', keep_spaces => 1);
    $twig1->parse($xml);
    ok ($twig1->sprint() =~ /<!--.*-->/s, 'keep comments');
    #print $twig1->sprint, "\n", '-'x80, "\n"; # keeps comments ok
    $twig1->dispose;
}

{
    my $twig2 = XML::Twig->new(comments => 'drop', keep_spaces => 1);
    $twig2->parse($xml);
    ok ($twig2->sprint() !~ /<!--.*-->/s, 'drop comments');
    #print $twig2->sprint, "\n", '-'x80, "\n"; # drops comments ok
    $twig2->dispose;
}

{
    my $twig3 = XML::Twig->new(comments => 'keep', keep_spaces => 1);
    $twig3->parse($xml);
    ok ($twig3->sprint() =~ /<!--.*-->/s, 'keep comments');
    #print $twig3->sprint, "\n", '-'x80, "\n"; # drops comments!!
    $twig3->dispose;
}
exit 0;


############################################################################
# tools                                                                    #
############################################################################

{ my $test_nb;
  sub is
    { my $got     = shift; my $expected= shift; my $message = shift;
      if( defined $_[0]) { $test_nb= shift; } else { $test_nb++; } 

      if( $expected eq $got) { print "ok $test_nb\n"; }
      else { print "not ok $test_nb\n"; warn "$message: expected '$expected', got '$got'\n"; }
    }

  sub ok
    { my $cond   = shift; my $message=shift;
      if( defined $_[0]) { $test_nb= shift; } else { $test_nb++; } 

      if( $cond) { print "ok $test_nb\n"; }
      else { print "not ok $test_nb\n"; warn "$message: false\n"; }
    }

  sub skip
    { my( $nb_skip, $message)= @_;
      warn "$message: skipping $nb_skip tests\n";
      for my $test ( ($test_nb + 1) .. ($test_nb + $nb_skip))
        { print "ok $test\n"; }
    }
}

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
