#!/bin/perl -w

use strict;
use Carp;

$|=1;

use XML::Twig;

my $TMAX=3; 

print "1..$TMAX\n";

my $xml_file= "t/test_expand_external_entities.xml";
my $dtd_file= "t/test_expand_external_entities.dtd";

my( $xml, $dtd, $xml_expanded, %ent);
{ local undef $/;
  open XML, "<$xml_file" or die "cannot open $xml_file: $!";
  $xml= <XML>;
  close XML;
  open DTD, "<$dtd_file" or die "cannot open $dtd_file: $!";
  $dtd= <DTD>;
  close DTD;
}

# extract entities
while( $dtd=~ m{<!ENTITY \s+ (\w+) \s+ "([^"]*)" \s* >}gx) { $ent{$1}= $2; } #"
# replace in xml
($xml_expanded= $xml)=~ s{&(\w+);}{$ent{$1}}g;

{
my $t= XML::Twig->new( load_DTD => 1);
$t->set_expand_external_entities;
$t->parsefile( $xml_file);
is( normalize_xml( $t->sprint), normalize_xml( $xml_expanded), "expanded document");
}

{
my $t= XML::Twig->new( load_DTD => 1, expand_external_ents => 1);
$t->parsefile( $xml_file);
is( normalize_xml( $t->sprint), normalize_xml( $xml_expanded), "expanded document");
}

{
(my $xml_no_dtd= $xml_expanded)=~ s{^<!DOCTYPE.*?>}{}s;
my $t= XML::Twig->new( load_DTD => 1, expand_external_ents => 1, do_not_output_DTD => 1);
$t->parsefile( $xml_file);
is( normalize_xml( $t->sprint), normalize_xml( $xml_no_dtd), "expanded document");
}


############################################################################
# tools                                                                    #
  
############################################################################

{ my $test_nb;
  sub is
    { my $got     = shift; my $expected= shift; my $message = shift;
      if( defined $_[0]) { $test_nb= shift; } else { $test_nb++; } 

      if( $expected eq $got) { print "ok $test_nb\n"; }
      else { print "not ok $test_nb\n"; 
             if( length( $expected) > 20)
               { warn "$message:\nexpected: '$expected'\ngot     : '$got'\n"; }
             else
               { warn "$message: expected '$expected', got '$got'\n"; }
           }
    }

  sub ok
    { my $cond   = shift; my $message=shift;
      if( defined $_[0]) { $test_nb= shift; } else { $test_nb++; } 

      if( $cond) { print "ok $test_nb\n"; }
      else { print "not ok $test_nb\n"; warn "$message: false\n"; }
    }

  sub nok
    { my $cond   = shift; my $message=shift;
      if( defined $_[0]) { $test_nb= shift; } else { $test_nb++; } 

      if( !$cond) { print "ok $test_nb\n"; }
      else { print "not ok $test_nb\n"; warn "$message: true (should be false)\n"; }
    }

  sub skip
    { my( $nb_skip, $message)= @_;
      warn "$message: skipping $nb_skip tests\n";
      for my $test ( ($test_nb + 1) .. ($test_nb + $nb_skip))
        { print "ok $test\n"; }
    }
}

sub normalize_xml
  { my $xml= shift;
    $xml=~ s{\n}{}g;
    $xml=~ s{'}{"}g; #'
    $xml=~ s{ />}{/>}g;
    return $xml;
  }

