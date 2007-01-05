# $Id: /xmltwig/trunk/t/xmlxpath_07count.t 3 2006-08-16T15:53:26.215012Z mrodrigu  $

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
plan( tests => 7);
 

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
