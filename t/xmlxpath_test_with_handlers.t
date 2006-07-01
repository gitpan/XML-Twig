#!/bin/perl -w
# $Id: xmlxpath_test_with_handlers.t,v 1.6 2006/05/25 11:06:03 mrodrigu Exp $
use strict;

BEGIN 
  { if( eval( 'require XML::Twig::XPath'))
      { import XML::Twig::XPath; }
    elsif( $@ =~ m{^cannot use XML::XPath or XML::XPathEngine})
      { print "1..1\nok 1\n"; warn "skipping: XML::XPathEngine or XML::XPath not available\n";
        exit;
      }
    else
      { die $@; }
  }

use Test;
plan( tests => 7);

use XML::Twig::XPath;

$|=1;

my $doc=
'<doc id="doc">
    <elt id="elt-1">elt 1</elt>
    <elt id="elt-2">elt 2</elt>
    <elt2 id="elt2-1">
      <elt id="elt-3">elt 3</elt>
    </elt2>
    <elt2 id="elt2-2">
      <elt2 att_int="2" id="elt2-3">2</elt2>
      <elt2 att_int="3" id="elt2-4">3</elt2>
    </elt2>
    <elt5 id="elt5-1">
				<elt3 id="elt3-1">
					<elt4 att_int="2" id="elt4-1">2</elt4>
					<elt4 att_int="3" id="elt4-2">3</elt4>
				</elt3>
				<elt3 id="elt3-2">
					<elt4 att_int="2" id="elt4-3">2</elt4>
					<elt4 att_int="3" id="elt4-4">3</elt4>
				</elt3>
        <elt6 id="elt6-1">in_elt6-1</elt6>
        <elt7 id="elt7-1">in_elt7-1</elt7>
        <elt7 id="elt7-2">in_elt7-2</elt7>
    </elt5>
    <:elt id=":elt">yep, that is a valid name</:elt>
 </doc>'
;

my $t= XML::Twig::XPath->new( twig_handlers =>
         { elt5 => sub { my @res1= $_->findnodes( './elt3/elt4[@att_int="3"] | elt3');
                         ok( ids( @res1), "elt3-1 - elt4-2 - elt3-2 - elt4-4");           # 1
                         ok( $_->field( 'elt7[@id="elt7-2"]'), "in_elt7-2");              # 2
                         ok( $_->findvalue( 'elt7[@id="elt7-2"]'), "in_elt7-2");          # 3
                         ok( $_->findvalue( 'elt7[preceding-sibling::*[1][self::elt6]]'), "in_elt7-1"); # 4
                         ok( $_->findvalue( 'elt7[preceding-sibling::elt6]'), "in_elt7-1in_elt7-2"); # 5
                         ok( $_->findvalue( "elt7"), "in_elt7-1in_elt7-2");                 # 6
                     },
          }, 
                             );
$t->parse( $doc);
 ok( ids( $t->findnodes( '//elt3/elt4[@att_int="3"] | //elt3') ), "elt3-1 - elt4-2 - elt3-2 - elt4-4"); # 7

exit 0;

sub ids
  { return join( " - ", map { $_->id } @_); }
