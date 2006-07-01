# $Id: xmlxpath_10pipe.t,v 1.6 2006/05/25 11:06:02 mrodrigu Exp $
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
