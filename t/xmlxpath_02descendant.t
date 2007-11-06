#!/usr/bin/perl -w
use strict; 

# $Id: /xmltwig/trunk/t/xmlxpath_02descendant.t 4 2007-03-16T12:16:25.259192Z mrodrigu  $

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

ok(1);

my $t= XML::Twig::XPath->new->parse( \*DATA);
ok($t);

my @bbb = $t->findnodes('//BBB');
ok(@bbb, 5);

my @subbbb = $t->findnodes('//DDD/BBB');
ok(@subbbb, 3);

exit 0;

__DATA__
<AAA>
<BBB/>
<CCC/>
<BBB/>
<DDD><BBB/></DDD>
<CCC><DDD><BBB/><BBB/></DDD></CCC>
</AAA>
