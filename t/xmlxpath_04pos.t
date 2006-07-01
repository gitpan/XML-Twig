# $Id: xmlxpath_04pos.t,v 1.7 2006/05/25 11:06:02 mrodrigu Exp $

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

my $first = $t->findvalue( '/AAA/BBB[1]/@id');
ok($first, "first");

my $last = $t->findvalue( '/AAA/BBB[last()]/@id');
ok($last, "last");

exit 0;

__DATA__
<AAA>
<BBB id="first"/>
<BBB/>
<BBB/>
<BBB id="last"/>
</AAA>
