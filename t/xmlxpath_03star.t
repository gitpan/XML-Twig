# $Id: xmlxpath_03star.t,v 1.5 2004/01/23 23:16:45 mrodrigu Exp $

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

@nodes = $t->findnodes( '/AAA/CCC/DDD/*');
ok(@nodes, 4);

@nodes = $t->findnodes( '/*/*/*/BBB');
ok(@nodes, 5);

@nodes = $t->findnodes( '//*');
ok(@nodes, 17);

__DATA__
<AAA>
<XXX><DDD><BBB/><BBB/><EEE/><FFF/></DDD></XXX>
<CCC><DDD><BBB/><BBB/><EEE/><FFF/></DDD></CCC>
<CCC><BBB><BBB><BBB/></BBB></BBB></CCC>
</AAA>
