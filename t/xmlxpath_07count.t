# $Id: xmlxpath_07count.t,v 1.6 2004/03/26 16:30:40 mrodrigu Exp $

BEGIN 
  { if( eval( 'require XML::XPath'))
      { import XML::XPath; require Test; import Test; plan( tests => 7); }
    else
      { print "1..1\nok 1\n"; warn "skipping: XML::XPath not available\n"; exit; }
  }
 

use XML::Twig::XPath;
ok(1);

my $t= XML::Twig::XPath->new->parse( \*DATA);

ok( $t);

my @nodes;
@nodes = $t->findnodes( '//*[count(BBB) = 2]');
ok($nodes[0]->getName, "DDD");

@nodes = $t->findnodes( '//*[count(*) = 2]');
ok(@nodes, 2);

@nodes = $t->findnodes( '//*[count(*) = 3]');
ok(@nodes, 2);
ok($nodes[0]->getName, "AAA");
ok($nodes[1]->getName, "CCC");

exit 0;

__DATA__
<AAA>
<CCC><BBB/><BBB/><BBB/></CCC>
<DDD><BBB/><BBB/></DDD>
<EEE><CCC/><DDD/></EEE>
</AAA>
