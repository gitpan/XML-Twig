#!/usr/bin/perl -w
use strict;

# $Id: test_new_features_3.15.t,v 1.2 2004/08/30 17:39:56 mrodrigu Exp $

# test designed to improve coverage of the module

use strict;
use Carp;

use FindBin qw($Bin);
BEGIN { unshift @INC, $Bin; }
use tools;

#$|=1;
my $DEBUG=0;

use XML::Twig;

my $TMAX=1; 
print "1..$TMAX\n";

{ my $indented="<doc>\n  <elt/>\n</doc>\n";
  (my $straight=$indented)=~ s{\s}{}g;
  is( XML::Twig->new( pretty_print => 'indented')->parse( $indented)->sprint,
      $indented, "pretty printed doc"); exit;
  is( XML::Twig->new()->parse( $indented)->sprint,
      $straight, "non pretty printed doc");
}

