# $Id: xmlxpath_09string_length.t,v 1.5 2004/01/23 23:16:45 mrodrigu Exp $

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
@nodes = $t->findnodes( '//*[string-length(name()) = 3]');
ok(@nodes, 2);

@nodes = $t->findnodes( '//*[string-length(name()) < 3]');
ok(@nodes, 2);

@nodes = $t->findnodes( '//*[string-length(name()) > 3]');
ok(@nodes, 3);

__DATA__
<AAA>
<Q/>
<SSSS/>
<BB/>
<CCC/>
<DDDDDDDD/>
<EEEE/>
</AAA>
