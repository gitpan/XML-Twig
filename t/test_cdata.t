#!/usr/bin/perl -w
use strict;

# $Id: test_cdata.t 13 2002-12-18 10:53:14Z mrodrigu $

use XML::Twig;

$|=1;

$/= "\n\n"; 
my $xml= <DATA>;

print "1..4\n";

my( $t, $result, $expected_result);

$t= XML::Twig->new( twig_handlers => { 'ehtml/#CDATA' => sub { $_->set_asis; } });
$t->parse( $xml);
$result= $t->sprint;
($expected_result=<DATA>)=~ s{\n*$}{}s; 
if( $result eq $expected_result) { print "ok 1\n"; }
else { print "nok 1\n"; warn "expected: $expected_result\n result  : $result"; }

$t= XML::Twig->new( twig_handlers => { 'ehtml/#CDATA' => sub { $_->remove_cdata; } });
$t->parse( $xml);
$result= $t->sprint;
($expected_result=<DATA>)=~ s{\n*$}{}s; 
if( $result eq $expected_result) { print "ok 2\n"; }
else { print "nok 2\n"; warn "expected: $expected_result\n result  : $result"; }

$t= XML::Twig->new( keep_encoding => 1, twig_handlers => { 'ehtml/#CDATA' => sub { $_->set_asis; } });
$t->parse( $xml);
$result= $t->sprint;
($expected_result=<DATA>)=~ s{\n*$}{}s; 
if( $result eq $expected_result) { print "ok 3\n"; }
else { print "nok 3\n"; warn "test keep_encoding / asis\n  expected: $expected_result\n  result  : $result"; }

$t= XML::Twig->new( keep_encoding => 1, twig_handlers => { 'ehtml/#CDATA' => sub { $_->remove_cdata; } });
$t->parse( $xml);
$result= $t->sprint;
($expected_result=<DATA>)=~ s{\n*$}{}s; 
if( $result eq $expected_result) { print "ok 4\n"; }
else { print "nok 4\n"; warn "test keep_encoding / remove_cdata\n  expected: $expected_result\n  result  : $result"; }

__DATA__
<doc>
  <elt>text</elt>
  <ehtml><![CDATA[hello<br>world & all]]></ehtml>
</doc>

<doc><elt>text</elt><ehtml>hello<br>world & all</ehtml></doc>

<doc><elt>text</elt><ehtml>hello&lt;br>world &amp; all</ehtml></doc>

<doc><elt>text</elt><ehtml>hello<br>world & all</ehtml></doc>

<doc><elt>text</elt><ehtml>hello&lt;br>world &amp; all</ehtml></doc>

