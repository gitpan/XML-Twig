# $Id: xmlxpath_06attrib_val.t,v 1.7 2006/05/25 11:06:02 mrodrigu Exp $

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
@nodes = $t->findnodes( '//BBB[@id = "b1"]');
ok(@nodes, 1);

@nodes = $t->findnodes( '//BBB[@name = "bbb"]');
ok(@nodes, 1);

@nodes = $t->findnodes( '//BBB[normalize-space(@name) = "bbb"]');
ok(@nodes, 2);

exit 0;

__DATA__
<AAA>
<BBB id='b1'/>
<BBB name=' bbb '/>
<BBB name='bbb'/>
</AAA>
