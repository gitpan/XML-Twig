#!/bin/perl -w

# $Id: test_additional.t,v 1.128 2005/02/14 16:40:28 mrodrigu Exp $

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

{ my $t= XML::Twig->new( parse_start_tag => sub { return 'a'; })->parse( '<b>c</b>');
  is( $t->sprint, '<a>c</a>', "dummy parse_start_tag");
}
exit 0;
