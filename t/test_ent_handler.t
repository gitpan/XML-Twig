#!/usr/bin/perl -w
use strict;

# $Id: test_ent_handler.t,v 1.1 2002/07/09 00:20:43 mrodrigu Exp $

use XML::Twig;

$|=1;

$/= "\n\n"; 
my $xml= <DATA>;

print "1..1\n";

my( $t, $result, $expected_result);

$result='';
$t= XML::Twig->new( twig_handlers => { 'ehtml/#ENT' => sub { $result .= "entity " . $_->sprint; } });
$t->parse( $xml);
($expected_result=<DATA>)=~ s{\n*$}{}s; 
if( $result eq $expected_result) { print "ok 1\n"; }
else { print "nok 1\n"; warn "expected: $expected_result\n result: $result"; }

__DATA__
<!DOCTYPE doc SYSTEM "dummy.dtd"[]>
<doc>
  <elt>text &ent;</elt>
  <ehtml>&ent2;</ehtml>
</doc>

entity &ent2;

