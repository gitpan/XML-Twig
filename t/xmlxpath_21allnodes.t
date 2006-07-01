# $Id: xmlxpath_21allnodes.t,v 1.7 2006/05/25 11:06:02 mrodrigu Exp $

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
plan( tests => 11);
 

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
