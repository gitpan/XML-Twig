#!/usr/bin/perl -w
use strict;

# $Id: test_new_features_3.15.t,v 1.2 2004/08/30 17:39:56 mrodrigu Exp $

# test designed to improve coverage of the module

use strict;
use Carp;

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