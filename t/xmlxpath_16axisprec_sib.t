# $Id: xmlxpath_16axisprec_sib.t,v 1.6 2004/03/26 16:30:40 mrodrigu Exp $

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
@nodes = $t->findnodes( '/AAA/XXX/preceding-sibling::*');
ok(@nodes, 1);
ok($nodes[0]->getName, "BBB");

@nodes = $t->findnodes( '//CCC/preceding-sibling::*');
ok(@nodes, 4);

@nodes = $t->findnodes( '/AAA/CCC/preceding-sibling::*[1]');
ok($nodes[0]->getName, "XXX");

@nodes = $t->findnodes( '/AAA/CCC/preceding-sibling::*[2]');
ok($nodes[0]->getName, "BBB");

exit 0;

__DATA__
<AAA>
    <BBB>
        <CCC/>
        <DDD/>
    </BBB>
    <XXX>
        <DDD>
            <EEE/>
            <DDD/>
            <CCC/>
            <FFF/>
            <FFF>
                <GGG/>
            </FFF>
        </DDD>
    </XXX>
    <CCC>
        <DDD/>
    </CCC>
</AAA>
