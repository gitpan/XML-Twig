# $Id: xmlxpath_30lang.t,v 1.7 2006/05/25 11:06:03 mrodrigu Exp $

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

my $t= XML::Twig::XPath->new( keep_spaces => 1)->parse( \*DATA);
ok( $t);

my @en = $t->findnodes( '//*[lang("en")]');
ok(@en, 2);

my @de = $t->findnodes( '//content[lang("de")]');
ok(@de, 1);

exit 0;

__DATA__
<page xml:lang="en">
  <content>Here we go...</content>
  <content xml:lang="de">und hier deutschsprachiger Text :-)</content>
</page>
