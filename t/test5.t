#!/bin/perl -w
use strict;

use XML::Twig;

$|=1;

my $doc= '<doc>
  <elt1>
    <elt2 id="elt1">
      <elt3 id="elt2">
      </elt3>
    </elt2>
    <elt2 id="elt3">
    </elt2>
  </elt1>
  <p1 id="p1_1"><p2 id="p2_1">p2 (/doc/p1/p2) </p2>
                <p3 id="p3_1"><p2 id="p2_2">p2 (/doc/p1/p3/p2) </p2></p3>
  </p1>
  <p2 id="p2_3">p2 (/doc/p2) </p2>
  <p2 id="p2_4">p2 (/doc/p2) </p2>
  <p4><p2 id="p2_5">p2 (/doc/p2) </p2></p4>
  <p4><p2 id="p2_6">p2 (/doc/p2) </p2></p4>
  <p3 id="p3_2"><p2 id="p2_7">p2 (/doc/p3/p2) </p2></p3>
</doc>
';

my $TMAX=21; # don't forget to update
print "1..$TMAX\n";

my $t= new XML::Twig;
$t->parse( $doc);

my $elt1= $t->elt_id( 'elt1');
my $elt2= $t->elt_id( 'elt2');
my $elt3= $t->elt_id( 'elt3');
my $root= $t->root;

# testing before and after
my $res= $elt1->before( $elt2);
if( $res) { print "ok 1\n"; } else { print "nok 1\n"; }

$res= $elt2->before( $elt3);
if( $res) { print "ok 2\n"; } else { print "nok 2\n"; }

$res= $elt1->before( $elt3);
if( $res) { print "ok 3\n"; } else { print "nok 3\n"; }

$res= $elt3->before( $elt2);
unless( $res) { print "ok 4\n"; } else { print "nok 4\n"; }

$res= $elt1->after( $elt2);
unless( $res) { print "ok 5\n"; } else { print "nok 5\n"; }

$res= $elt1->after( $elt3);
unless( $res) { print "ok 6\n"; } else { print "nok 6\n"; }

$res= $elt3->after( $elt2);
if( $res) { print "ok 7\n"; } else { print "nok 7\n"; }

$res= $elt1->before( $root);
unless( $res) { print "ok 8\n"; } else { print "nok 8\n"; }

$res= $root->before( $elt1);
if( $res) { print "ok 9\n"; } else { print "nok 9\n"; }

# testing path capabilities
my $path=  $elt1->path;
my $exp_path=  '/doc/elt1/elt2';
if( $path eq $exp_path)
  { print "ok 10\n"; } else { print "nok 10 ($path instead of $exp_path\n"; } 

$path=  $elt2->path;
$exp_path=  '/doc/elt1/elt2/elt3';
if( $path eq $exp_path)
  { print "ok 11\n"; } else { print "nok 11 ($path instead of $exp_path\n"; } 

$path=  $elt3->path;
$exp_path=  '/doc/elt1/elt2';
if( $path eq $exp_path)
  { print "ok 12\n"; } else { print "nok 12 ($path instead of $exp_path\n"; } 

$path=  $root->path;
$exp_path=  '/doc';
if( $path eq $exp_path)
  { print "ok 13\n"; } else { print "nok 13 ($path instead of $exp_path\n"; } 

my $id1=''; my $exp_id1= 'p2_1';
my $id2=''; my $exp_id2= 'p2_3p2_4';
my $id3=''; my $exp_id3= 'p2_2p2_7';
my $id4=''; my $exp_id4= 'p2_5p2_6';
my $path_error='';
my $t2= new XML::Twig( TwigHandlers => 
                         { '/doc/p1/p2' => sub { $id1.= $_[1]->id; },
                           '/doc/p2'    => sub { $id2.= $_[1]->id; },
                           'p3/p2'      => sub { $id3.= $_[1]->id; },
                           'p2'         => sub { $id4.= $_[1]->id; },
   _all_  => sub { my( $t, $elt)= @_;
                   my $gi= $elt->gi;
                   my $tpath= $t->path( $gi); my $epath= $elt->path;
                   unless( $tpath eq $epath)
                     { $path_error.= " $tpath <> $epath\n"; }
                 }  
                         }
                     );
$t2->parse( $doc);
if( $id1 eq $exp_id1) 
  { print "ok 14\n"; } else { print "nok 14: $id1 instead of $exp_id1\n"; } 
if( $id2 eq $exp_id2) 
  { print "ok 15\n"; } else { print "nok 15: $id2 instead of $exp_id2\n"; } 
if( $id3 eq $exp_id3) 
  { print "ok 16\n"; } else { warn "nok 16: $id3 instead of $exp_id3\n"; } 
if( $id4 eq $exp_id4) 
  { print "ok 17\n"; } else { warn "nok 17: $id4 instead of $exp_id4\n"; } 
unless( $path_error)
  { print "ok 18\n"; } else { warn "nok 18: $path_error\n"; } 

$id1=''; $exp_id1= 'p2_1';
my $t3= new XML::Twig( TwigRoots => { '/doc/p1/p2' => sub { $id1.= $_[1]->id; } } );
$t3->parse( $doc);
if( $id1 eq $exp_id1) 
  { print "ok 19\n"; } else { print "nok 19: $id1 instead of $exp_id1\n"; }

$id2=''; $exp_id2= 'p2_3p2_4';
$t3= new XML::Twig( TwigRoots => { '/doc/p2'    => sub { $id2.= $_[1]->id;} } );
$t3->parse( $doc);
if( $id2 eq $exp_id2) 
  { print "ok 20\n"; } else { print "nok 20: $id2 instead of $exp_id2\n"; } 

$id3=''; $exp_id3= 'p2_2p2_7';
$t3= new XML::Twig( TwigRoots => { 'p3/p2'    => sub { $id3.= $_[1]->id;} } );
$t3->parse( $doc);
if( $id3 eq $exp_id3) 
  { print "ok 21\n"; } else { print "nok 21: $id3 instead of $exp_id3\n"; } 
