# $Id: xmlxpath_26predicate.t,v 1.6 2004/03/26 16:30:40 mrodrigu Exp $

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

my @bbb = $t->findnodes( '//a/b[2]');
ok(@bbb, 2);

@bbb = $t->findnodes( '(//a/b)[2]');
ok(@bbb, 1);

exit 0;

__DATA__
<xml>
    <a>
        <b>some 1</b>
        <b>value 1</b>
    </a>
    <a>
        <b>some 2</b>
        <b>value 2</b>
    </a>
</xml>
