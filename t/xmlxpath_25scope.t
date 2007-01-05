# $Id: /xmltwig/trunk/t/xmlxpath_25scope.t 3 2006-08-16T15:53:26.215012Z mrodrigu  $

use strict;

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

eval
{
  # Removing the 'my' makes this work?!?
  my $t= XML::Twig::XPath->new->parse( '<test/>');
  ok( $t);

  $t->findnodes( '/test');

  ok(1);

  die "This should be caught\n";

};

if ($@)
{
  ok(1);
}
else {
    ok(0);
}

exit 0;
