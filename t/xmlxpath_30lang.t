# $Id: xmlxpath_30lang.t,v 1.6 2004/03/26 16:30:40 mrodrigu Exp $

BEGIN 
  { if( eval( 'require XML::XPath'))
      { import XML::XPath; require Test; import Test; plan( tests => 4); }
    else
      { print "1..1\nok 1\n"; warn "skipping: XML::XPath not available\n"; exit; }
  }
 

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
