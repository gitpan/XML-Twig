# $Id: xmlxpath_09a_string_length.t,v 1.7 2004/03/26 16:30:40 mrodrigu Exp $

BEGIN 
  { if( eval( 'require XML::XPath'))
      { import XML::XPath; require Test; import Test; plan( tests => 5); }
    else
      { print "1..1\nok 1\n"; warn "skipping: XML::XPath not available\n"; exit; }
  }
 

use XML::Twig::XPath;

my $doc_one = qq|<doc><para>para one</para></doc>|;

my $t= XML::Twig::XPath->new( keep_spaces => 1);
$t->parse( $doc_one);
ok( $t);

my $doc_one_chars = $t->find( 'string-length(/doc/text())');
ok($doc_one_chars == 0, 1);

my $doc_two = qq|
<doc>
  <para>para one has <b>bold</b> text</para>
</doc>
|;

$t->parse( $doc_two);
ok( $t);

my $doc_two_chars = $t->find( 'string-length(/doc/text())');
ok($doc_two_chars == 3, 1);

my $doc_two_para_chars = $t->find( 'string-length(/doc/para/text())');
ok($doc_two_para_chars == 13, 1);

exit 0;

