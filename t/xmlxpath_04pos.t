# $Id: xmlxpath_04pos.t,v 1.5 2004/01/23 23:16:45 mrodrigu Exp $

BEGIN 
  { if( eval( 'require XML::XPath'))
      { import XML::XPath; require Test; import Test; plan( tests => 4); }
    else
      { print "1..1\nok 1\n"; warn "skipping: XML::XPath not available\n"; exit; }
  }
 

use XML::Twig::XPath;
ok(1);

my $t= XML::Twig::XPath->new->parse( \*DATA);

ok( $t);

my $first = $t->findvalue( '/AAA/BBB[1]/@id');
ok($first, "first");

my $last = $t->findvalue( '/AAA/BBB[last()]/@id');
ok($last, "last");

__DATA__
<AAA>
<BBB id="first"/>
<BBB/>
<BBB/>
<BBB id="last"/>
</AAA>
