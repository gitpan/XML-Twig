# $Id: xmlxpath_18axispreceding.t,v 1.7 2006/05/25 11:06:02 mrodrigu Exp $

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
