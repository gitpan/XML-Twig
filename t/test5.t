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

my $TMAX=55; # don't forget to update
print "1..$TMAX\n";

my $t= new XML::Twig;
$t->parse( $doc);

my $elt1= $t->elt_id( 'elt1');
my $elt2= $t->elt_id( 'elt2');
my $elt3= $t->elt_id( 'elt3');
my $root= $t->root;

# testing before and after
my $res= $elt1->before( $elt2);
if( $res) { print "ok 1\n"; } else { warn "nok 1\n"; }

$res= $elt2->before( $elt3);
if( $res) { print "ok 2\n"; } else { warn "nok 2\n"; }

$res= $elt1->before( $elt3);
if( $res) { print "ok 3\n"; } else { warn "nok 3\n"; }

$res= $elt3->before( $elt2);
unless( $res) { print "ok 4\n"; } else { warn "nok 4\n"; }

$res= $elt1->after( $elt2);
unless( $res) { print "ok 5\n"; } else { warn "nok 5\n"; }

$res= $elt1->after( $elt3);
unless( $res) { print "ok 6\n"; } else { warn "nok 6\n"; }

$res= $elt3->after( $elt2);
if( $res) { print "ok 7\n"; } else { warn "nok 7\n"; }

$res= $elt1->before( $root);
unless( $res) { print "ok 8\n"; } else { warn "nok 8\n"; }

$res= $root->before( $elt1);
if( $res) { print "ok 9\n"; } else { warn "nok 9\n"; }

# testing path capabilities
my $path=  $elt1->path;
my $exp_path=  '/doc/elt1/elt2';
if( $path eq $exp_path)
  { print "ok 10\n"; } else { warn "nok 10 ($path instead of $exp_path\n"; }

$path=  $elt2->path;
$exp_path=  '/doc/elt1/elt2/elt3';
if( $path eq $exp_path)
  { print "ok 11\n"; } else { warn "nok 11 ($path instead of $exp_path\n"; }

$path=  $elt3->path;
$exp_path=  '/doc/elt1/elt2';
if( $path eq $exp_path)
  { print "ok 12\n"; } else { warn "nok 12 ($path instead of $exp_path\n"; }

$path=  $root->path;
$exp_path=  '/doc';
if( $path eq $exp_path)
  { print "ok 13\n"; } else { warn "nok 13 ($path instead of $exp_path\n"; }

my $id1=''; my $exp_id1= 'p2_1';
my $id2=''; my $exp_id2= 'p2_3p2_4';
my $id3=''; my $exp_id3= 'p2_2p2_7';
my $id4=''; my $exp_id4= 'p2_5p2_6';
my $path_error='';
my $t2= new XML::Twig( TwigHandlers => 
                         { '/doc/p1/p2' => sub { $id1.= $_[1]->id; return; },
                           '/doc/p2'    => sub { $id2.= $_[1]->id; return; },
                           'p3/p2'      => sub { $id3.= $_[1]->id; return; },
                           'p2'         => sub { $id4.= $_[1]->id; return; },
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
  { print "ok 14\n"; } else { warn "nok 14: $id1 instead of $exp_id1\n"; }
if( $id2 eq $exp_id2) 
  { print "ok 15\n"; } else { warn "nok 15: $id2 instead of $exp_id2\n"; }
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
  { print "ok 19\n"; } else { warn "nok 19: $id1 instead of $exp_id1\n"; }

$id2=''; $exp_id2= 'p2_3p2_4';
$t3= new XML::Twig( TwigRoots => { '/doc/p2'    => sub { $id2.= $_[1]->id;} } );
$t3->parse( $doc);
if( $id2 eq $exp_id2) 
  { print "ok 20\n"; } else { warn "nok 20: $id2 instead of $exp_id2\n"; }

$id3=''; $exp_id3= 'p2_2p2_7';
$t3= new XML::Twig( TwigRoots => { 'p3/p2'    => sub { $id3.= $_[1]->id;} } );
$t3->parse( $doc);
if( $id3 eq $exp_id3) 
  { print "ok 21\n"; } else { warn "nok 21: $id3 instead of $exp_id3\n"; }

# test what happens to 0 in pcdata/cdata
my $pcdata= '<test><text>0</text></test>';
my $cdata= '<test><text><![CDATA[0]]></text></test>';
my $t4= new XML::Twig;

$t4->parse( $pcdata);
if( my $res= $t4->sprint eq $pcdata) { print "ok 22\n"; } 
else { warn "nok 22: sprint returns $res instead of $pcdata\n"; }

$t4->parse( $pcdata);
if( my $res= $t4->root->text eq '0') { print "ok 23\n"; } 
else { warn "nok 23: sprint returns $res instead of '0'\n"; }

$t4->parse( $cdata);
if( my $res= $t4->sprint eq $cdata) { print "ok 24\n"; } 
else { warn "nok 23: sprint returns $res instead of $cdata\n"; }

$t4->parse( $cdata);
if( my $res= $t4->root->text eq '0') { print "ok 25\n"; } 
else { warn "nok 25: sprint returns $res instead of '0'\n"; }

my $test_inherit=
'<doc att1="doc1" att2="doc2" att3="doc3"><elt att1="elt1" att_null="0">
  <subelt att1="subelt1" att2="subelt2"></subelt>
</elt></doc>';

my $t5= new XML::Twig;
$t5->parse( $test_inherit);
my $subelt= $t5->root->first_child->first_child;

if( my $att= $subelt->att( 'att1') eq "subelt1") { print "ok 26\n"; }
else { warn "nok 26: sprint returns $att instead of 'subelt1'\n"; }

if( my $att= $subelt->inherit_att( 'att1') eq "subelt1") { print "ok 27\n"; }
else { warn "nok 27: sprint returns $att instead of 'subelt1'\n"; }

if( my $att= $subelt->inherit_att( 'att1', 'elt') eq "elt1") { print "ok 28\n"; }
else { print "nok 28: sprint returns $att instead of 'elt1'\n"; }

if( my $att= $subelt->inherit_att( 'att1', 'elt', 'doc') eq "elt1") { print "ok 29\n"; }
else { warn "nok 29: sprint returns $att instead of 'elt1'\n"; }

if( my $att= $subelt->inherit_att( 'att1', "doc") eq "doc1") { print "ok 30\n"; }
else { warn "nok 30: sprint returns $att instead of 'doc1'\n"; }

if( my $att= $subelt->inherit_att( 'att3') eq "doc3") { print "ok 31\n"; }
else { warn "nok 31: sprint returns $att instead of 'doc3'\n"; }

if( my $att= $subelt->inherit_att( 'att3') eq "doc3") { print "ok 32\n"; }
else { warn "nok 32: sprint returns $att instead of 'doc3'\n"; }

if( my $att= $subelt->inherit_att( 'att_null') == 0) { print "ok 33\n"; }
else { warn "nok 33: sprint returns $att instead of '0'\n"; }

# test attribute paths
my $test_att_path=
'<doc>
  <elt id="elt1" att="val1">
    <subelt id="subelt1" att="val1"/>
    <subelt id="subelt2" att="val1"/>
    <subelt id="subelt3" att="val2"/>
  </elt>
  <elt id="elt2" att="val1">
    <subelt id="subelt4" att="val1"/>
    <subelt id="subelt5" att="val1"/>
    <subelt id="subelt6" att="val2"/>
  </elt>
 </doc>';

my $res1='';
my $t6= new XML::Twig
          ( TwigHandlers =>    #'' (or VIM messes up colors)
            { 'elt[@id="elt1"]' => sub { $res1.= $_[1]->id} } 
          );
$t6->parse( $test_att_path);

if( $res1 eq 'elt1') { print "ok 34\n"; }
else { warn "nok 34: returns $res1 instead of 'elt1'\n"; }

$res1='';
my $res2='';
$t6= new XML::Twig
          ( TwigHandlers =>
            { 'elt[@id="elt1"]'  => sub { $res1.= $_[1]->id},
              'elt[@att="val1"]' => sub { $res2.= $_[1]->id} },
          );
$t6->parse( $test_att_path);
if( $res1 eq 'elt1') { print "ok 35\n"; }
else { warn "nok 35: returns $res1 instead of 'elt1'\n"; }
if( $res2 eq 'elt1elt2') { print "ok 36\n"; }
else { warn "nok 36: returns $res2 instead of 'elt1elt2'\n"; }

my $doc_with_escaped_entities=
'<doc att="m &amp; m">&lt;apos>&apos;&apos;&lt;apos&gt;&lt;&quot;></doc>';
my $exp_res1=
'<doc att="m &amp; m">&lt;apos&gt;&apos;&apos;&lt;apos&gt;&lt;&quot;&gt;</doc>';
my $exp_res2='<doc att="m & m"><apos>\'\'<apos><"></doc>';
my $t7= new XML::Twig();
$t7->parse( $doc_with_escaped_entities);
$res= $t7->sprint;
if( $res eq $exp_res1) { print "ok 37\n"; }
else { warn "nok 37: returns \n$res instead of \n$exp_res1\n"; }

$t7= new XML::Twig( NoExpand => 1);
$t7->parse( $doc_with_escaped_entities);
$res= $t7->sprint;
if( $res eq $exp_res2) { print "ok 38\n"; }
else { warn "nok 38: returns \n$res instead of \n$exp_res2\n"; }

# test extra options for new
my $elt= new XML::Twig::Elt( 'p');
$res= $elt->sprint;
my $exp_res= '<p></p>';
if( $res eq $exp_res) { print "ok 39\n"; }
else { warn "nok 39: returns $res instead of $exp_res\n"; }

$elt= new XML::Twig::Elt( 'p', '#EMPTY');
$res= $elt->sprint;
$exp_res= '<p/>';
if( $res eq $exp_res) { print "ok 40\n"; }
else { warn "nok 40: returns $res instead of $exp_res\n"; }

$elt= new XML::Twig::Elt( 'p', { att => 'val'});
$res= $elt->sprint;
$exp_res= '<p att="val"></p>';
if( $res eq $exp_res) { print "ok 41\n"; }
else { warn "nok 41: returns $res instead of $exp_res\n"; }

$elt= new XML::Twig::Elt( 'p', { att => 'val'}, '#EMPTY');
$res= $elt->sprint;
$exp_res= '<p att="val"/>';
if( $res eq $exp_res) { print "ok 42\n"; }
else { warn "nok 42: returns $res instead of $exp_res\n"; }

$elt= new XML::Twig::Elt( 'p', { att1 => 'val1', att2=> 'val2'});
$res= $elt->sprint;
$exp_res= '<p att1="val1" att2="val2"></p>';
if( $res eq $exp_res) { print "ok 43\n"; }
else { warn "nok 43: returns $res instead of $exp_res\n"; }

$elt= new XML::Twig::Elt( 'p', { att1 => 'val1', att2=>'val2'}, '#EMPTY');
$res= $elt->sprint;
$exp_res= '<p att1="val1" att2="val2"/>';
if( $res eq $exp_res) { print "ok 44\n"; }
else { warn "nok 44: returns $res instead of $exp_res\n"; }


$elt= new XML::Twig::Elt( 'p', "content");
$res= $elt->sprint;
$exp_res= '<p>content</p>';
if( $res eq $exp_res) { print "ok 45\n"; }
else { warn "nok 45: returns $res instead of $exp_res\n"; }

$elt= new XML::Twig::Elt( 'p', { att1 => 'val1'}, "content");
$res= $elt->sprint;
$exp_res= '<p att1="val1">content</p>';
if( $res eq $exp_res) { print "ok 46\n"; }
else { warn "nok 46: returns $res instead of $exp_res\n"; }

$elt= new XML::Twig::Elt( 'p', { att1 => 'val1', att2=>'val2'}, "content");
$res= $elt->sprint;
$exp_res= '<p att1="val1" att2="val2">content</p>';
if( $res eq $exp_res) { print "ok 47\n"; }
else { warn "nok 47: returns $res instead of $exp_res\n"; }

$elt= new XML::Twig::Elt( 'p', { att1 => 'val1'}, "content", " more content");
$res= $elt->sprint;
$exp_res= '<p att1="val1">content more content</p>';
if( $res eq $exp_res) { print "ok 48\n"; }
else { warn "nok 48: returns $res instead of $exp_res\n"; }

my $sub1= new XML::Twig::Elt( 'sub', '#EMPTY');
my $sub2= new XML::Twig::Elt( 'sub', { att => 'val'}, '#EMPTY');
my $sub3= new XML::Twig::Elt( 'sub', "sub3");
my $sub4= new XML::Twig::Elt( 'sub', "sub4");
my $sub5= new XML::Twig::Elt( 'sub', "sub5", $sub3, "sub5 again", $sub4);

$elt= new XML::Twig::Elt( 'p', { att1 => 'val1'}, $sub1, $sub2, $sub5);
$res= $elt->sprint;
$exp_res= '<p att1="val1"><sub/><sub att="val"/>'.
          '<sub>sub5<sub>sub3</sub>sub5 again<sub>sub4</sub></sub></p>';
if( $res eq $exp_res) { print "ok 49\n"; }
else { warn "nok 49: returns \n$res\n instead of \n$exp_res\n"; }

$elt->set_empty_tag_style( 'html');
$res= $elt->sprint;
$exp_res= '<p att1="val1"><sub /><sub att="val" />'.
          '<sub>sub5<sub>sub3</sub>sub5 again<sub>sub4</sub></sub></p>';
if( $res eq $exp_res) { print "ok 50\n"; }
else { warn "nok 50: returns \n$res\n instead of \n$exp_res\n"; }

$elt->set_empty_tag_style( 'expand');
$res= $elt->sprint;
$exp_res= '<p att1="val1"><sub></sub><sub att="val"></sub>'.
          '<sub>sub5<sub>sub3</sub>sub5 again<sub>sub4</sub></sub></p>';
if( $res eq $exp_res) { print "ok 51\n"; }
else { warn "nok 51: returns \n$res\n instead of \n$exp_res\n"; }

$elt->set_empty_tag_style( 'normal');
$res= $elt->sprint;
$exp_res= '<p att1="val1"><sub/><sub att="val"/>'.
          '<sub>sub5<sub>sub3</sub>sub5 again<sub>sub4</sub></sub></p>';
if( $res eq $exp_res) { print "ok 52\n"; }
else { warn "nok 52: returns \n$res\n instead of \n$exp_res\n"; }

my $new_elt= parse XML::Twig::Elt( $res);
$res= $new_elt->sprint;
$exp_res= '<p att1="val1"><sub/><sub att="val"/>'.
          '<sub>sub5<sub>sub3</sub>sub5 again<sub>sub4</sub></sub></p>';
if( $res eq $exp_res) { print "ok 53\n"; }
else { warn "nok 53: returns \n$res\n instead of \n$exp_res\n"; }

$doc='<doc><elt att="val1">text1</elt><root>root1</root><elt>text 2</elt></doc>';
$res='';
$exp_res= '<elt att="val1">text1</elt>';
$t= new XML::Twig( TwigHandlers => 
                        { 'elt[string()="text1"]' => \&display1,
                          'elt[@att="val1"]' => \&display1,
			},
		    );
$t->parse( $doc);

sub display1 { $res .=$_[1]->sprint; return 0; }
if( $res eq $exp_res) { print "ok 54\n"; }
else { warn "nok 54: returns \n$res\n instead of \n$exp_res\n"; }

$res='';
$exp_res= '<elt att="val1">text1</elt>' x 2;
$t= new XML::Twig( TwigHandlers => 
                        { 'elt[string()="text1"]' => \&display2,
                          'elt[@att="val1"]' => \&display2,
			},
		    );
$t->parse( $doc);

sub display2 { $res .=$_[1]->sprint; }
if( $res eq $exp_res) { print "ok 55\n"; }
else { warn "nok 55: returns \n$res\n instead of \n$exp_res\n"; }
