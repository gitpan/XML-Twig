# $Id: xmlxpath_23func.t,v 1.6 2004/03/26 16:30:40 mrodrigu Exp $

BEGIN 
  { if( eval( 'require XML::XPath'))
      { import XML::XPath; require Test; import Test; plan( tests => 5); }
    else
      { print "1..1\nok 1\n"; warn "skipping: XML::XPath not available\n"; exit; }
  }
 

use XML::Twig::XPath;
ok(1);

my $t= XML::Twig::XPath->new->parse( \*DATA);

ok( $t);

my @nodes;
@nodes = $t->findnodes( '//BBB[position() mod 2 = 0 ]');
ok(@nodes, 4);

@nodes = $t->findnodes('//BBB
        [ position() = floor(last() div 2 + 0.5) 
            or
          position() = ceiling(last() div 2 + 0.5) ]');

ok(@nodes, 2);

@nodes = $t->findnodes('//CCC
        [ position() = floor(last() div 2 + 0.5) 
            or
          position() = ceiling(last() div 2 + 0.5) ]');

ok(@nodes, 1);

exit 0;

__DATA__
<AAA>
    <BBB/>
    <BBB/>
    <BBB/>
    <BBB/>
    <BBB/>
    <BBB/>
    <BBB/>
    <BBB/>
    <CCC/>
    <CCC/>
    <CCC/>
</AAA>
