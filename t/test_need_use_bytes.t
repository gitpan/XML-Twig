#!/bin/perl -w

# $Id$

# tests that require IO::Scalar to run
use strict;
use Carp;

#$|=1;
my $DEBUG=0;

use XML::Twig;

BEGIN 
  { eval "use bytes";
    if( $@) 
      { print "1..1\nok 1\n"; 
        warn "skipping, need to be able to use bytes\n";
        exit;
      } 
  }

print "1..2\n";

my $text= "&#233;t&#233;";
my $text_safe= "&#233;t&#233;";
my $text_safe_hex= "&#xe9;t&#xe9;";
my $doc=qq{<?xml version="1.0" encoding="UTF-8"?>\n<doc>$text</doc>};
my $doc_safe=qq{<?xml version="1.0" encoding="UTF-8"?>\n<doc>$text_safe</doc>};
my $doc_safe_hex=qq{<?xml version="1.0" encoding="UTF-8"?>\n<doc>$text_safe_hex</doc>};

my $t= XML::Twig->new()->parse( $doc);

if( $] == 5.008)
  { skip( 2); }
else
  { $t->set_output_text_filter( sub { my $text= shift;
                                      use bytes;
                                      $text=~ s{([\xC0-\xDF].|[\xE0-\xEF]..|[\xF0-\xFF]...)}
                                               {XML::Twig::_XmlUtf8Decode($1)}egs;
                                      return $text;
                                    }
                          );
    is( $t->sprint, $doc_safe, 'safe with _XmlUtf8Decode');  # test 338
    $t->set_output_text_filter( sub { my $text= shift;
                                      use bytes;
                                      $text=~ s{([\xC0-\xDF].|[\xE0-\xEF]..|[\xF0-\xFF]...)}
                                               {XML::Twig::_XmlUtf8Decode($1, 1)}egs;
                                      return $text;
                                    }
                          );
    is( $t->sprint, $doc_safe_hex, 'safe_hex with _XmlUtf8Decode');  # test 339
  }



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


sub xml_escape
  { my $string= shift;
    #$string=~ s{&}{&amp;}g;
    $string=~ s{<}{&lt;}g;
    $string=~ s{>}{&gt;}g;
    $string=~ s{"}{&quot;}g; #"
    $string=~ s{'}{&apos;}g; #'
    return $string;
  }

sub normalize_xml
  { my $xml= shift;
    $xml=~ s{\n}{}g;
    $xml=~ s{'}{"}g; #'
    $xml=~ s{ />}{/>}g;
    return $xml;
  }

sub hash_ent_text
  { my %ents= @_;
    return map { $_ => "<!ENTITY $_ $ents{$_}>" } keys %ents;
  }
sub string_ent_text
  { my %ents= @_;
    my %hash_ent_text= hash_ent_text( %ents);
    return join( '', map { $hash_ent_text{$_} } sort keys %hash_ent_text);
  }
