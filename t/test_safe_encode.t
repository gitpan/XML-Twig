#!/usr/bin/perl -w
use strict; 

# $Id: test_safe_encode.t,v 1.2 2004/04/22 18:50:10 mrodrigu Exp $

use XML::Twig;

my $DEBUG=0;

print "1..4\n";

my $doc='<doc><élément atté="été">été</élément></doc>';
(my $safe_xml_doc= $doc)=~ s{é}{&#233;}g;
(my $safe_hex_doc= $doc)=~ s{é}{&#xe9;}g;
(my $text_safe_xml_doc= $doc)=~ s{été}{&#233;t&233;}g;
(my $text_safe_hex_doc= $doc)=~ s{é}{&#xe9;t&xe9;}g;

is( XML::Twig->new( output_filter => 'safe')->parse( $doc)->sprint, $safe_xml_doc, "output_filter => 'safe'");
is( XML::Twig->new( output_filter => 'safe_hex')->parse( $doc)->sprint, $safe_hex_doc, "output_filter => 'safe_hex'");
is( XML::Twig->new( output_text_filter => 'safe')->parse( $doc)->sprint, $safe_xml_doc, "output_text_filter => 'safe'");
is( XML::Twig->new( output_text_filter => 'safe_hex')->parse( $doc)->sprint, $safe_hex_doc, "output_text_filter => 'safe_hex'");

############################################################################
# tools                                                                    #
  
############################################################################

{ my $test_nb;
  sub is
    { my( $got, $expected, $message) = @_;
      $test_nb++; 

      if( $expected eq $got) 
        { print "ok $test_nb\n";
          warn "ok $test_nb $message\n" if( $DEBUG); 
        }
      else 
        { print "not ok $test_nb\n"; 
          if( length( $expected) > 20)
            { warn "$message:\nexpected: '$expected'\ngot     : '$got'\n"; }
          else
            { warn "$message: expected '$expected', got '$got'\n"; }
        }
    }

  sub matches
    { my $got     = shift; my $expected_regexp= shift; my $message = shift;
      $test_nb++; 

      if( $got=~ /$expected_regexp/) 
        { print "ok $test_nb\n"; 
          warn "ok $test_nb $message\n" if( $DEBUG); 
        }
      else { print "not ok $test_nb\n"; 
             warn "$message: expected to match /$expected_regexp/, got '$got'\n";
           }
    }

  sub ok
    { my $cond   = shift; my $message=shift;
      $test_nb++; 

      if( $cond)
        { print "ok $test_nb\n"; 
          warn "ok $test_nb $message\n" if( $DEBUG); 
        }
      else { print "not ok $test_nb\n"; warn "$message: false\n"; }
    }

  sub nok
    { my $cond   = shift; my $message=shift;
      $test_nb++; 

      if( !$cond)
        { print "ok $test_nb\n"; 
          warn "ok $test_nb $message\n" if( $DEBUG); 
        }
      else { print "not ok $test_nb\n"; warn "$message: true (should be false): '$cond'\n"; }
    }

  sub is_undef
    { my $cond   = shift; my $message=shift;
      $test_nb++; 

      if( ! defined( $cond)) 
        { print "ok $test_nb\n"; 
          warn "ok $test_nb $message\n" if( $DEBUG); 
        }
      else { print "not ok $test_nb\n"; warn "$message is defined: '$cond'\n"; }
    }


my %seen_message;
  sub skip
    { my( $nb_skip, $message)= @_;
      $message ||='';
      unless( $seen_message{$message})
        { warn "$message: skipping $nb_skip tests\n";
          $seen_message{$message}++;
        }
      for my $test ( ($test_nb + 1) .. ($test_nb + $nb_skip))
        { print "ok $test\n";
          warn "skipping $test ($message)\n" if( $DEBUG); 
        }
      $test_nb= $test_nb + $nb_skip;
    }
}

sub tags { return join ':', map { $_->gi } @_ }
sub ids  { return join ':', map { $_->att( 'id') || '<' . $_->gi . ':no_id>' } @_ }

