#!/bin/perl -w

# $Id: test_class_methods.t,v 1.5 2004/03/26 16:30:40 mrodrigu Exp $

# testing methods on class attribute:
# class set_class add_to_class att_to_class add_att_to_class move_att_to_class
# tag_to_class add_tag_to_class set_tag_class in_class
 
use strict;
use Carp;

use XML::Twig;

my $DEBUG=0;

my $TMAX=26; 

print "1..$TMAX\n";

{ 
my $root= XML::Twig->new->parse( q{<doc att1="val1" att2="val2"/>})->root;
nok( $root->class, "no class");
$root->set_class( 'foo');
is( $root->class, 'foo', 'set_class');
$root->set_class( 'bar');
is( $root->class, 'bar', 'set_class');
ok( $root->in_class( 'bar'), 'in_class (ok)');
nok( $root->in_class( 'foo'), 'in_class (nok)');
$root->add_to_class( 'foo');
ok( $root->in_class( 'bar'), 'in_class (ok)');
ok( $root->in_class( 'foo'), 'in_class (ok)');
nok( $root->in_class( 'baz'), 'in_class (nok)');
$root->tag_to_class;
is( $root->class, 'doc', 'tag_to__class');
ok( $root->in_class( 'doc'), 'in_class (ok)');
nok( $root->in_class( 'foo'), 'in_class (nok)');
$root->tag_to_class;
is( $root->class, 'doc', 'tag_to_class (with existing class)');
$root->add_tag_to_class;
is( $root->class, 'doc', 'add_tag_to_class');
$root->att_to_class( 'att1');
is( $root->class, 'val1', 'att_to_class');
$root->att_to_class( 'att1');
is( $root->class, 'val1', 'att_to_class (with existing class)');
$root->add_att_to_class( 'att');
is( $root->class, 'val1', 'att_to_class (non existing att)');
$root->add_att_to_class( 'att2');
is( $root->class, 'val1 val2', 'att_to_class (2 classes now)');
ok( $root->in_class( 'val1'), 'in_class');
ok( $root->in_class( 'val2'), 'in_class');
nok( $root->in_class( 'val'), 'in_class (nok)');
$root->set_tag_class( 'new');
is( $root->sprint, '<new att1="val1" att2="val2" class="doc val1 val2"/>', 'set_tag_class');
$root->move_att_to_class( 'att2');
is( $root->sprint, '<new att1="val1" class="doc val1 val2"/>', 'set_tag_class');

ok( $root->matches( '.doc'), 'match on class (first)');
ok( $root->matches( '.val1'), 'match on class (middle)');
ok( $root->matches( '.val2'), 'match on class (last)');
nok( $root->matches( '.val'), 'match on class (not good)');

}


exit 0;



############################################################################
# tools                                                                    #
  
############################################################################

{ my $test_nb;
  sub is
    { my $got     = shift; my $expected= shift; my $message = shift;
      $test_nb++; 

      if( $expected eq $got) 
        { print "ok $test_nb\n";
          warn "$message" if( $DEBUG); 
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

      if( $got=~ /$expected_regexp/) { print "ok $test_nb\n"; }
      else { print "not ok $test_nb\n"; 
             warn "$message: expected to match /$expected_regexp/, got '$got'\n";
           }
    }

  sub ok
    { my $cond   = shift; my $message=shift;
      $test_nb++; 

      if( $cond) { print "ok $test_nb\n"; }
      else { print "not ok $test_nb\n"; warn "$message: false\n"; }
    }

  sub nok
    { my $cond   = shift; my $message=shift;
      $test_nb++; 

      if( !$cond) { print "ok $test_nb\n"; }
      else { print "not ok $test_nb\n"; warn "$message: true (should be false): '$cond'\n"; }
    }

  sub is_undef
    { my $cond   = shift; my $message=shift;
      $test_nb++; 

      if( ! defined( $cond)) { print "ok $test_nb\n"; }
      else { print "not ok $test_nb\n"; warn "$message is defined: '$cond'\n"; }
    }


my %seen_message;
  sub skip
    { my( $nb_skip, $message)= @_;
      unless( $seen_message{$message})
        { warn "$message: skipping $nb_skip tests\n";
          $seen_message{$message}++;
        }
      for my $test ( ($test_nb + 1) .. ($test_nb + $nb_skip))
        { print "ok $test\n"; }
      $test_nb= $test_nb + $nb_skip;
    }
}


sub tags { return join ':', map { $_->gi } @_ }
