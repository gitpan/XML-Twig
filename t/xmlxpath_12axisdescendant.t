# $Id: /xmltwig/trunk/t/xmlxpath_12axisdescendant.t 4 2007-03-16T12:16:25.259192Z mrodrigu  $

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
