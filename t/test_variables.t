#!/usr/bin/perl -w
# $Id: test_variables.t,v 1.2 2003/09/19 11:09:24 mrodrigu Exp $
use strict;
use XML::Twig;

$|=1;

print "1..6\n";
warn "\nwarnings are normal here \n";

my $t= XML::Twig->new->parse( \*DATA);

my $s= $t->simplify( var_attr => 'var', variables => { 'v2' => 'elt2'});
if( $s->{elt2} eq 'elt using elt1') { print "ok 1\n" }
else { print "nok 1\n"; warn "test 1: /$s->{elt2}/ instead of 'elt using elt1'\n"; }
if( $s->{elt3} eq 'elt using elt1') { print "ok 2\n" }
else { print "nok 2\n"; warn "test 2: /$s->{elt3}/ instead of 'elt using elt1'\n"; }
if( $s->{elt4} eq 'elt using elt2') { print "ok 3\n"; warn "\n"; }
else { print "nok 3\n"; warn "test 3: /$s->{elt4}/ instead of 'elt using elt2'\n"; }
if( $s->{elt5}->{att1} eq 'att with elt1') { print "ok 4\n" }
else { print "nok 4\n"; warn "test 4: /$s->{elt5}->{att1}/ instead of 'att with elt1'\n"; }


$s= $t->simplify( variables => { 'v2' => 'elt2'});
if( $s->{elt2} eq 'elt using $v1') { print "ok 5\n" }
else { print "nok 5\n"; warn "test 5: /$s->{elt2}/ instead of 'elt using \$v1'\n"; }
if( $s->{elt4} eq 'elt using elt2') { print "ok 6\n" }
else { print "nok 6\n"; warn "test 6: /$s->{elt4}/ instead of 'elt using elt2'\n"; }
__DATA__
<doc>
  <elt1 var="v1">elt1</elt1>
  <elt2>elt using $v1</elt2>
  <elt3>elt using ${v1}</elt3>
  <elt4>elt using $v2</elt4>
  <elt5 att1="att with $v1"/>
</doc>
