#!/usr/bin/perl -w
use strict;

# $Id: xmlxpath_01basic.t,v 1.5 2004/03/26 16:30:40 mrodrigu Exp $

BEGIN 
  { if( eval( 'require XML::XPath'))
      { import XML::XPath; require Test; import Test; plan( tests => 5); }
    else
      { print "1..1\nok 1\n"; warn "skipping: XML::XPath not available\n"; exit; }
  }

use XML::Twig::XPath;

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
