# $Id: xmlxpath_12axisdescendant.t,v 1.6 2004/03/26 16:30:40 mrodrigu Exp $

BEGIN 
  { if( eval( 'require XML::XPath'))
      { import XML::XPath; require Test; import Test; plan( tests => 6); }
    else
      { print "1..1\nok 1\n"; warn "skipping: XML::XPath not available\n"; exit; }
  }
 

use XML::Twig::XPath;
ok(1);

my $t= XML::Twig::XPath->new->parse( \*DATA);

ok( $t);

my @nodes;
@nodes = $t->findnodes( '/descendant::*');
ok(@nodes, 11);

@nodes = $t->findnodes( '/AAA/BBB/descendant::*');
ok(@nodes, 4);

@nodes = $t->findnodes( '//CCC/descendant::*');
ok(@nodes, 6);

@nodes = $t->findnodes( '//CCC/descendant::DDD');
ok(@nodes, 3);

exit 0;

__DATA__
<AAA>
<BBB><DDD><CCC><DDD/><EEE/></CCC></DDD></BBB>
<CCC><DDD><EEE><DDD><FFF/></DDD></EEE></DDD></CCC>
</AAA>
