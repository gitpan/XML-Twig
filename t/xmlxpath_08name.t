# $Id: /xmltwig/trunk/t/xmlxpath_08name.t 4 2007-03-16T12:16:25.259192Z mrodrigu  $

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
@nodes = $t->findnodes( '//*[name() = "BBB"]');
ok(@nodes, 5);

@nodes = $t->findnodes( '//*[starts-with(name(), "B")]');
ok(@nodes, 7);

@nodes = $t->findnodes( '//*[contains(name(), "C")]');
ok(@nodes, 3);

exit 0;

__DATA__
<AAA>
<BCC><BBB/><BBB/><BBB/></BCC>
<DDB><BBB/><BBB/></DDB>
<BEC><CCC/><DBD/></BEC>
</AAA>
