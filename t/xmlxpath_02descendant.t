#!/usr/bin/perl -w
use strict; 

# $Id: xmlxpath_02descendant.t,v 1.7 2004/03/26 16:30:40 mrodrigu Exp $

BEGIN 
  { if( eval( 'require XML::Twig::XPath'))
      { import XML::Twig::XPath; require Test; import Test; plan( tests => 4); }
    else
      { print "1..1\nok 1\n"; warn "skipping: XML::XPath not available\n"; exit; }
  }

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
