# $Id: xmlxpath_22name_select.t,v 1.5 2004/01/23 23:16:45 mrodrigu Exp $

use Test;
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

my @nodes;
@nodes = $t->findnodes( '//*[name() = /AAA/SELECT]');
ok(@nodes, 2);
ok($nodes[0]->getName, "BBB");

__DATA__
<AAA>
<SELECT>BBB</SELECT>
<BBB/>
<CCC/>
<DDD>
<BBB/>
</DDD>
</AAA>
