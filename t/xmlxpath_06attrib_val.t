# $Id: xmlxpath_06attrib_val.t,v 1.5 2004/01/23 23:16:45 mrodrigu Exp $

BEGIN 
  { if( eval( 'require XML::XPath'))
      { import XML::XPath; require Test; import Test; plan( tests => 5); }
    else
      { print "1..1\nok 1\n"; warn "skipping: XML::XPath not available\n"; exit; }
  }
 

use XML::Twig::XPath;
ok(1);

my $t= XML::Twig::XPath->new->parse( \*DATA);

ok( $t);

my @nodes;
@nodes = $t->findnodes( '//BBB[@id = "b1"]');
ok(@nodes, 1);

@nodes = $t->findnodes( '//BBB[@name = "bbb"]');
ok(@nodes, 1);

@nodes = $t->findnodes( '//BBB[normalize-space(@name) = "bbb"]');
ok(@nodes, 2);

__DATA__
<AAA>
<BBB id='b1'/>
<BBB name=' bbb '/>
<BBB name='bbb'/>
</AAA>
