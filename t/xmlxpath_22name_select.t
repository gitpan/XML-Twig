# $Id: /xmltwig/trunk/t/xmlxpath_22name_select.t 4 2007-03-16T12:16:25.259192Z mrodrigu  $

use Test;
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
plan( tests => 4);
 

use XML::Twig::XPath;
ok(1);

my $t= XML::Twig::XPath->new->parse( \*DATA);

ok( $t);

my @nodes;
@nodes = $t->findnodes( '//*[name() = /AAA/SELECT]');
ok(@nodes, 2);
ok($nodes[0]->getName, "BBB");

exit 0;

__DATA__
<AAA>
<SELECT>BBB</SELECT>
<BBB/>
<CCC/>
<DDD>
<BBB/>
</DDD>
</AAA>
