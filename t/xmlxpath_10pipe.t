# $Id: /xmltwig/trunk/t/xmlxpath_10pipe.t 4 2007-03-16T12:16:25.259192Z mrodrigu  $
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
plan( tests => 6);
 
use XML::Twig::XPath;
ok(1);

my $t= XML::Twig::XPath->new->parse( \*DATA);

ok( $t);

my @nodes;
@nodes = $t->findnodes( '//CCC | //BBB');
ok(@nodes, 3);
ok($nodes[0]->getName, "BBB"); # test document order

@nodes = $t->findnodes( '/AAA/EEE | //BBB');
ok(@nodes, 2);

@nodes = $t->findnodes( '/AAA/EEE | //DDD/CCC | /AAA | //BBB');
ok(@nodes, 4);

exit 0;

__DATA__
<AAA>
<BBB/>
<CCC/>
<DDD><CCC/></DDD>
<EEE/>
</AAA>
