# $Id: /xmltwig/trunk/t/xmlxpath_05attrib.t 3 2006-08-16T15:53:26.215012Z mrodrigu  $

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
plan( tests => 6);
 

use XML::Twig::XPath;
ok(1);

my $t= XML::Twig::XPath->new->parse( \*DATA);

ok( $t);

my @ids = $t->findnodes( '//BBB[@id]');
ok(@ids, 2);

my @names = $t->findnodes( '//BBB[@name]');
ok(@names, 1);

my @attribs = $t->findnodes( '//BBB[@*]');
ok(@attribs, 3);

my @noattribs = $t->findnodes( '//BBB[not(@*)]');
ok(@noattribs, 1);

exit 0;

__DATA__
<AAA>
<BBB id='b1'/>
<BBB id='b2'/>
<BBB name='bbb'/>
<BBB/>
</AAA>
