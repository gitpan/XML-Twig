#!/usr/bin/perl -w
use strict;
BEGIN 
  { if( eval( 'require XML::XPath'))
      { import XML::XPath; require Test; import Test; plan( tests => 9); }
    else
      { print "1..1\nok 1\n"; warn "skipping: XML::XPath not available\n"; exit; }
  }

use XML::Twig::XPath;

my $t= XML::Twig::XPath->new->parse( *DATA);

my $node= $t->findvalue( '//attr:node/@attr:findme');
ok( $node, 'someval');

my @nodes;

# Do not set namespace prefixes - uses element context namespaces

@nodes = $t->findnodes('//foo:foo', $t); # should find foobar.com foos
ok( @nodes, 3);

@nodes = $t->findnodes('//goo:foo', $t); # should find no foos
ok( @nodes, 0);

@nodes = $t->findnodes('//foo', $t); # should find default NS foos
ok( @nodes, 2);

$node= $t->findvalue( '//*[@attr:findme]');
ok( $node, 'attr content');

# Set namespace mappings.


$t->set_namespace("foo" => "flubber.example.com");
$t->set_namespace("goo" => "foobar.example.com");

@nodes = $t->findnodes('//foo:foo', $t); # should find flubber.com foos
ok( @nodes, 2);

@nodes = $t->findnodes('//goo:foo', $t); # should find foobar.com foos
ok( @nodes, 3);

@nodes = $t->findnodes('//foo', $t); # should find default NS foos
ok( @nodes, 2);

ok( $t->findvalue('//attr:node/@attr:findme'), 'someval');

exit 0;

__DATA__
<xml xmlns:foo="foobar.example.com"
    xmlns="flubber.example.com">
    <foo>
        <bar/>
        <foo/>
    </foo>
    <foo:foo>
        <foo:foo/>
        <foo:bar/>
        <foo:bar/>
        <foo:foo/>
    </foo:foo>
    <attr:node xmlns:attr="attribute.example.com"
        attr:findme="someval">attr content</attr:node >
</xml>
