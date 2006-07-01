#!/usr/bin/perl -w
use strict;

# $Id: xmlxpath_01basic.t,v 1.6 2006/05/25 11:06:02 mrodrigu Exp $

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
plan( tests => 5);

ok(1);
my $t= XML::Twig::XPath->new->parse( \*DATA);
ok($t);

my @root = $t->findnodes('/AAA');
ok(@root, 1);

my @ccc = $t->findnodes('/AAA/CCC');
ok(@ccc, 3);

my @bbb = $t->findnodes('/AAA/DDD/BBB');
ok(@bbb, 2);

exit 0;

__DATA__
<AAA>
    <BBB/>
    <CCC/>
    <BBB/>
    <CCC/>
    <BBB/>
    <!-- comment -->
    <DDD>
        <BBB/>
        Text
        <BBB/>
    </DDD>
    <CCC/>
</AAA>
