# $Id: xmlxpath_18axispreceding.t,v 1.6 2004/03/26 16:30:40 mrodrigu Exp $

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
@nodes = $t->findnodes( '/AAA/XXX/preceding::*');
ok(@nodes, 4);

@nodes = $t->findnodes( '//GGG/preceding::*');
ok(@nodes, 8);

exit 0;

__DATA__
<AAA>
    <BBB>
        <CCC/>
        <ZZZ>
            <DDD/>
        </ZZZ>
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
