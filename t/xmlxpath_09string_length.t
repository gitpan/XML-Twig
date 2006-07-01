# $Id: xmlxpath_09string_length.t,v 1.7 2006/05/25 11:06:02 mrodrigu Exp $

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
@nodes = $t->findnodes( '//*[string-length(name()) = 3]');
ok(@nodes, 2);

@nodes = $t->findnodes( '//*[string-length(name()) < 3]');
ok(@nodes, 2);

@nodes = $t->findnodes( '//*[string-length(name()) > 3]');
ok(@nodes, 3);

exit 0;

__DATA__
<AAA>
<Q/>
<SSSS/>
<BB/>
<CCC/>
<DDDDDDDD/>
<EEEE/>
</AAA>
