#!/bin/perl -w

use strict;


# This just tests a complete twig, no callbacks

$|=1;

use XML::Twig;

my $doc='<?xml version="1.0" standalone="no"?>
<!DOCTYPE doc [
<!NOTATION gif PUBLIC "gif">
<!ENTITY e1 SYSTEM "e1.gif" NDATA gif>
<!ENTITY e2 SYSTEM "e2.gif" NDATA gif>
<!ENTITY e3 \'internal entity\'>
]>
<doc id="doc1">
  <section id="section1">
    <intro id="intro1">
      <para id="paraintro1">S1 I1</para>
      <para id="paraintro2">S1 I2</para>
    </intro>
    <title no="1" id="title1">S1 Title</title>
    <para id="para1">S1 P1</para>
    <para id="para2">S2 P2</para>
    <note id="note1">
      <para id="paranote1">Note P1</para>
    </note>
    <para id="para3">S1 <xref refid="section2"/>para 3</para>
  </section>
  <section id="section2">
    <intro id="intro2">
      <para id="paraintro3">S2 intro</para>
    </intro>
    <title no="2" id="title2">S2 Title</title>
    <para id="para4">S2 P1</para>
    <para id="para5">S2 P2</para>
    <para id="para6">S2 P3</para>
  </section>
  <annex id="annex1">
    <title no="A" id="titleA">Annex Title</title>
    <para id="paraannex1">Annex P1</para>
    <para id="paraannex2">Annex P2</para>
  </annex>
</doc>';


my $i=0;
my $failed=0;

my $TMAX=81; # don't forget to update!

print "1..$TMAX\n";

# test twig creation
my $t= new XML::Twig();
test( $t, 'twig creation');

# test parse
$t->parse( $doc, ErrorContext=>2);
test( $t, 'parse');

# test the root
my $root= etest( $t->root, 'doc', 'doc1', 'root');

# test the element root and twig functions on the root
test( $root->twig, 'root->twign');
etest( $root->root, 
      'doc', 'doc1', 'root->root');


# navigation
my $section1= 
etest( $root->first_child, 
      'section', 'section1', 'first_child');
my $annex= 
etest( $root->first_child( 'annex'), 
      'annex', 'annex1', 'first_child( annex)');

etest( $root->last_child, 
      'annex', 'annex1', 'last_child');
my $section2= 
etest( $root->last_child( 'section'), 
      'section', 'section2', 'last_child( section)');

etest( $section2->prev_sibling,
     'section', 'section1', 'prev_sibling');
etest( $section1->next_sibling,
      'section', 'section2', 'next_sibling');

my $note= 
etest( $root->next_elt( 'note'),
      'note', 'note1', 'next_elt( note)');
etest( $note->root,
      'doc', 'doc1', 'root');
test( $note->twig, 'twig');
etest( $note->twig->root,
      'doc', 'doc1', 'twig->root');

# playing with next_elt and prev_elt
my $para2=
etest( $note->prev_sibling,
      'para', 'para2', 'prev_sibling');
etest( $note->prev_elt( 'para'),
      'para', 'para2', 'prev_elt( para)');
my $para3=
etest( $note->next_sibling,
      'para', 'para3', 'next_sibling');
my $paranote1=
etest( $note->next_elt( 'para'),
      'para', 'paranote1', 'next_elt( para)');
etest( $paranote1->next_elt( 'para'),
      'para', 'para3', 'next_elt( para)');

# difference between next_sibling and next_sibling( gi)
etest( $para2->next_sibling,
      'note', 'note1', 'next_sibling');
etest( $para2->next_sibling( 'para'),
          'para', 'para3', 'next_sibling( para)');

# testing in/parent/in_context
test( $paranote1->in( $note), 'in');
test( $paranote1->in( $section1), 'in');
test( !$paranote1->in( $section2), 'not in');
test( $paranote1->in_context( 'note'), 'in_context');
test( $paranote1->in_context( 'section'), 'in_context');
test( !$paranote1->in_context( 'intro'), 'not in_context');
etest( $paranote1->parent,
          'note', 'note1', 'parent');

# testing list methods (ancestors/children)
stest( (join ":", map { $_->id} $paranote1->ancestors),
       'note1:section1:doc1', 'ancestors');
stest( (join ":", map { $_->id} $paranote1->ancestors('section')),
       'section1', 'ancestors( section)');
stest( (join ":", map { $_->id} $section1->children), 
       'intro1:title1:para1:para2:note1:para3', 'children');
stest( (join ":", map { $_->id} $section1->children( 'para')), 
       'para1:para2:para3', 'children( para)');

stest( $paranote1->level, 3, 'level');

# testing attributes
my $title1=
   etest( $root->next_elt( 'title'),
          'title', 'title1', 'next_elt( title)');
stest( $title1->id, 'title1', 'id');
stest( $title1->att('id'), 'title1', 'att( id)');
stest( $title1->att('no'), '1', 'att( no)');
$title1->set_att('no', 'Auto');
stest( $title1->att('no'), 'Auto', 'set att( no)');
$title1->set_att('no', '1');

$title1->set_att('newatt', 'newval');
stest( $title1->att('newatt'), 'newval', 'set att( newval)');
$title1->del_att('newatt');
stest( stringify( %{$title1->atts}), 'id:title1:no:1', 'del_att');

$title1->set_att('id', 'newid');
stest( $title1->id, 'newid', 'set_att(id)');
stest( $title1->att( 'id'), 'newid', 'set_att(id)');
$title1->set_id( 'title1');
stest( $title1->id, 'title1', 'set_id');
stest( $title1->att( 'id'), 'title1', 'set_id');


stest( stringify( %{$title1->atts}), 'id:title1:no:1', 'atts');

$title1->del_atts;
stest( stringify( %{$title1->atts}), '', 'del_atts');
$title1->set_atts( { 'no' => '1', 'id' => 'newtitleid'});
stest( stringify( %{$title1->atts}), 'id:newtitleid:no:1', 'set_atts');
stest( $title1->id, 'newtitleid', 'id');
stest( $title1->att('id'), 'newtitleid', 'att( id)');
$title1->set_id( 'title1');


# now let's cut and paste
$title1->cut;
stest( (join ":", map { $_->id} $section1->children), 
       'intro1:para1:para2:note1:para3', 'cut (1)');
my $intro1= $section1->first_child( 'intro');
$intro1->cut;
stest( (join ":", map { $_->id} $section1->children), 
       'para1:para2:note1:para3', 'cut (2)');
$intro1->paste( $section1);
stest( (join ":", map { $_->id} $section1->children), 
       'intro1:para1:para2:note1:para3', 'paste');

$title1->paste( 'first_child', $section2, );
stest( (join ":", map { $_->id} $section2->children), 
       'title1:intro2:title2:para4:para5:para6', 'paste( first_child)');
$title1->cut;
stest( (join ":", map { $_->id} $section2->children), 
       'intro2:title2:para4:para5:para6', 'paste');
$title1->paste( $section2);
stest( (join ":", map { $_->id} $section2->children), 
       'title1:intro2:title2:para4:para5:para6', 'paste');
$title1->cut;
stest( (join ":", map { $_->id} $section2->children), 
       'intro2:title2:para4:para5:para6', 'cut (3)');
$title1->paste( 'last_child', $section2);
stest( (join ":", map { $_->id} $section2->children), 
       'intro2:title2:para4:para5:para6:title1', 'paste( last_child)');
$title1->cut;
stest( (join ":", map { $_->id} $section2->children), 
       'intro2:title2:para4:para5:para6', 'cut(4)');

my $intro2= 
   etest( $section2->first_child( 'intro'),
          'intro', 'intro2', 'first_sibling( intro)');

$title1->paste( 'after', $intro2);
stest( (join ":", map { $_->id} $section2->children), 
       'intro2:title1:title2:para4:para5:para6', 'paste( after)');
$title1->cut;
stest( (join ":", map { $_->id} $section2->children), 
       'intro2:title2:para4:para5:para6', 'cut (5)');

$title1->paste( 'before', $intro2);
stest( (join ":", map { $_->id} $section2->children), 
       'title1:intro2:title2:para4:para5:para6', 'paste( before)');
$title1->cut;
stest( (join ":", map { $_->id} $section2->children), 
       'intro2:title2:para4:para5:para6', 'cut (6)');

my $para4=  etest( $t->elt_id( 'para4'), 'para', 'para4', 'elt_id');
$title1->paste( 'after', $para4);
stest( (join ":", map { $_->id} $section2->children), 
       'intro2:title2:para4:title1:para5:para6', 'paste( after)');
$title1->cut;
stest( (join ":", map { $_->id} $section2->children), 
       'intro2:title2:para4:para5:para6', 'cut (7)');

$title1->paste( 'before', $para4);
stest( (join ":", map { $_->id} $section2->children), 
       'intro2:title2:title1:para4:para5:para6', 'paste( before)');
$title1->cut;
stest( (join ":", map { $_->id} $section2->children), 
       'intro2:title2:para4:para5:para6', 'cut (8)');

# now let's mess up the document
# let's erase that pesky intro
$intro2->erase;
stest( (join ":", map { $_->id} $section2->children), 
       'paraintro3:title2:para4:para5:para6', 'erase');

$para4->delete;
stest( (join ":", map { $_->id} $section2->children), 
       'paraintro3:title2:para5:para6', 'delete');
$t->change_gi( 'paraintro', 'para');
stest( (join ":", map { $_->gi} $section2->children), 
       'para:title:para:para', 'change_gi');

$para3=  etest( $t->elt_id( 'para3'), 'para', 'para3', 'elt_id');
$para3->cut;
stest( $section1->text, 'S1 I1S1 I2S1 P1S2 P2Note P1', 'text');

stest( $section1->sprint,
'<section id="section1"><intro id="intro1"><para id="paraintro1">S1 I1</para><para id="paraintro2">S1 I2</para></intro><para id="para1">S1 P1</para><para id="para2">S2 P2</para><note id="note1"><para id="paranote1">Note P1</para></note></section>',
 'sprint');

# let's have a look at those entities
# first their names
stest( join( ':', $t->entity_names), 'e1:e2:e3', 'entity_list');
# let's look at their content
my $e1= $t->entity( 'e1');
stest( $e1->text, '<!ENTITY e1 SYSTEM "e1.gif" NDATA gif>', 'e1 text');
my $e2= $t->entity( 'e2');
stest( $e2->text, '<!ENTITY e2 SYSTEM "e2.gif" NDATA gif>', 'e2 text');
my $e3= $t->entity( 'e3');
stest( $e3->text, '<!ENTITY e3 "internal entity">', 'e3 text');


# additionnal erase test
$section1= $root->first_child;
stest( (join ":", map { $_->id} $section1->children), 
       'intro1:para1:para2:note1', 'erase (2)');
$intro1= $section1->first_child( 'intro');
$intro1->erase;
stest( (join ":", map { $_->id} $section1->children), 
       'paraintro1:paraintro2:para1:para2:note1', 'erase (3)');




##################################################################################
# test functions
##################################################################################

# element test
sub etest 
  { my ($elt, $gi, $id, $message)= @_;
    $i++;
    unless( $elt)
      { print "not ok $i\n    -- $message\n";
        warn "         -- no element returned";
        return;
      }
    if( ($elt->gi eq $gi) && ($elt->att( 'id') eq $id))
      { print "ok $i\n"; 
        return $elt;
      }
    print "not ok $i\n    -- $message\n";
    warn "         -- expecting ", $gi, " ", $id, "\n";
    warn "         -- found     ", $elt->gi, " ", $elt->id, "\n";
    return $elt;
  }

# element text test
sub ttest
  { my ($elt, $text, $message)= @_;
    $i++;
    unless( $elt)
      { print "not ok $i\n    -- $message\n";
        warn "         -- no element returned ";
        return;
      }
    if( $elt->text eq $text)
      { print "ok $i\n"; 
        return $elt;
      }
    print "not ok $i\n    -- $message\n";
    warn "          expecting ", $text, "\n";
    warn "          found     ", $elt->text, "\n";
    return $elt;
  }

# testing if the result is a  strings
sub stest
  { my ($result, $expected, $message)= @_;
    $i++;
    if( $result eq $expected)
      { print "ok $i\n"; }
    else
      { print "not ok $i\n    -- $message\n";  
        warn "          expecting ", $expected, "\n";
         warn"          found     ", $result, "\n";
      }
  }
sub test
  { my ($result, $message)= @_;
    $i++;
    if( $result)
      { print "ok $i\n"; }
    else
      { print "not ok $i\n";
        warn "  $message\n"; }
  }


sub stringify
  { return join ":", @_; }
