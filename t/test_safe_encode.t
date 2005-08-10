#!/usr/bin/perl -w
use strict; 

# $Id: test_safe_encode.t,v 1.4 2005/08/10 09:32:33 mrodrigu Exp $

use FindBin qw($Bin);
BEGIN { unshift @INC, $Bin; }
use tools;

use XML::Twig;

my $DEBUG=0;

print "1..8\n";

# suitable for perl 5.6.*
my $doc='<doc><élément att="été">été</élément></doc>';
(my $safe_xml_doc= $doc)=~ s{é}{&#233;}g;
(my $safe_hex_doc= $doc)=~ s{é}{&#xe9;}g;
(my $text_safe_xml_doc= $doc)=~ s{été}{&#233;t&233;}g;
(my $text_safe_hex_doc= $doc)=~ s{é}{&#xe9;t&xe9;}g;

is( XML::Twig->new( output_filter => 'safe')->parse( $doc)->sprint, $safe_xml_doc, "output_filter => 'safe'");
is( XML::Twig->new( output_filter => 'safe_hex')->parse( $doc)->sprint, $safe_hex_doc, "output_filter => 'safe_hex'");
is( XML::Twig->new( output_text_filter => 'safe')->parse( $doc)->sprint, $safe_xml_doc, "output_text_filter => 'safe'");
is( XML::Twig->new( output_text_filter => 'safe_hex')->parse( $doc)->sprint, $safe_hex_doc, "output_text_filter => 'safe_hex'");

# suitable for 5.8.* and above (you can't have utf-8 hash keys before that)

if( $] < 5.008)
  { skip( 4 => "cannot process utf-8 attribute names with a perl before 5.8"); }
else
  {
    my $doc='<doc><élément atté="été">été</élément></doc>';
    (my $safe_xml_doc= $doc)=~ s{é}{&#233;}g;
    (my $safe_hex_doc= $doc)=~ s{é}{&#xe9;}g;
    (my $text_safe_xml_doc= $doc)=~ s{été}{&#233;t&233;}g;
    (my $text_safe_hex_doc= $doc)=~ s{é}{&#xe9;t&xe9;}g;

    is( XML::Twig->new( output_filter => 'safe')->parse( $doc)->sprint, $safe_xml_doc, "output_filter => 'safe'");
    is( XML::Twig->new( output_filter => 'safe_hex')->parse( $doc)->sprint, $safe_hex_doc, "output_filter => 'safe_hex'");
    is( XML::Twig->new( output_text_filter => 'safe')->parse( $doc)->sprint, $safe_xml_doc, "output_text_filter => 'safe'");
    is( XML::Twig->new( output_text_filter => 'safe_hex')->parse( $doc)->sprint, $safe_hex_doc, "output_text_filter => 'safe_hex'");
  }
