# $Id: xmlxpath_17axisfollowing.t,v 1.6 2004/03/26 16:30:40 mrodrigu Exp $

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
@nodes = $t->findnodes( '/AAA/XXX/following::*');
ok(@nodes, 2);

@nodes = $t->findnodes( '//ZZZ/following::*');
ok(@nodes, 12);

exit 0;

__DATA__
<AAA>
<BBB>
    <CCC/>
    <ZZZ>
        <DDD/>
        <DDD>
            <EEE/>
        </DDD>
    </ZZZ>
    <FFF>
        <GGG/>
    </FFF>
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
