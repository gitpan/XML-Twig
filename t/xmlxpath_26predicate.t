# $Id: /xmltwig/trunk/t/xmlxpath_26predicate.t 4 2007-03-16T12:16:25.259192Z mrodrigu  $

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
