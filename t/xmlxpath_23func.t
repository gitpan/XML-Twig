# $Id: xmlxpath_23func.t,v 1.7 2006/05/25 11:06:02 mrodrigu Exp $

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
plan( tests => 5);
 

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
