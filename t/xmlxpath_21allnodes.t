# $Id: xmlxpath_21allnodes.t,v 1.6 2004/03/26 16:30:40 mrodrigu Exp $

BEGIN 
  { if( eval( 'require XML::XPath'))
      { import XML::XPath; require Test; import Test; plan( tests => 11); }
    else
      { print "1..1\nok 1\n"; warn "skipping: XML::XPath not available\n"; exit; }
  }
 

use XML::Twig::XPath;
ok(1);

my $t= XML::Twig::XPath->new->parse( \*DATA);

ok( $t);

my @nodes;
@nodes = $t->findnodes( '//GGG/ancestor::*');
ok(@nodes, 4);

@nodes = $t->findnodes( '//GGG/descendant::*');
ok(@nodes, 3);

@nodes = $t->findnodes( '//GGG/following::*');
ok(@nodes, 3);
ok($nodes[0]->getName, "VVV");

@nodes = $t->findnodes( '//GGG/preceding::*');
ok(@nodes, 5);
ok($nodes[0]->getName, "BBB"); # document order, not HHH

@nodes = $t->findnodes( '//GGG/self::*');
ok(@nodes, 1);
ok($nodes[0]->getName, "GGG");

@nodes = $t->findnodes( '//GGG/ancestor::* | //GGG/descendant::* | //GGG/following::* | //GGG/preceding::* | //GGG/self::*');
ok(@nodes, 16);

exit 0;

__DATA__
<AAA>
    <BBB>
        <CCC/>
        <ZZZ/>
    </BBB>
    <XXX>
        <DDD>
            <EEE/>
            <FFF>
                <HHH/>
                <GGG> <!-- Watch this node -->
                    <JJJ>
                        <QQQ/>
                    </JJJ>
                    <JJJ/>
                </GGG>
                <VVV/>
            </FFF>
        </DDD>
    </XXX>
    <CCC>
        <DDD/>
    </CCC>
</AAA>
