# $Id: xmlxpath_25scope.t,v 1.6 2004/01/23 23:16:45 mrodrigu Exp $

use strict;

BEGIN 
  { if( eval( 'require XML::XPath'))
      { import XML::XPath; require Test; import Test; plan( tests => 4); }
    else
      { print "1..1\nok 1\n"; warn "skipping: XML::XPath not available\n"; exit; }
  }
 

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
