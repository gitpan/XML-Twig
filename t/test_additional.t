#!/bin/perl -w

# test designed to improve coverage of the module

use strict;
use Carp;

#$|=1;

use XML::Twig;

my $perl= $];
my $DEBUG=0;

my $TMAX=441; 

print "1..$TMAX\n";

{
my $t= XML::Twig->new->parse( q{
  <doc>
    <cdata><![CDATA[cdata 01]]></cdata>
    <cdata>foo <![CDATA[cdata <02>]]> bar </cdata>
  </doc>
});

# use CDATA
my $cdata= $t->first_elt( CDATA)->text;
is( $cdata, 'cdata 01', 'first_elt( CDATA)');
is( $t->first_elt( CDATA)->cdata_string, '<![CDATA[cdata 01]]>', 'cdata_string');
is( $t->root->cdata_string, '', 'cdata_string for non cdata element');

my $cdata2= $t->root->first_child( 'cdata[2]')->next_elt( CDATA)->text;
is( $cdata2, 'cdata <02>', 'first_child( cdata[2])');
}

# test warning for invalid options
my $old_warning_handler= $SIG{__WARN__};

{
my $warning="";
$SIG{__WARN__} = sub { $warning.= join '', @_ };
XML::Twig->new( dummy_opt => 1);
$SIG{__WARN__}= $old_warning_handler;
ok( $warning=~ m{^invalid option DummyOpt}, "expecting 'invalid option DummyOpt...', got '$warning'\n");

# test no warming if more_options is used
$warning="";
$SIG{__WARN__} = sub { $warning.= join '', @_ };
XML::Twig->new( more_options => 1, dummy_opt => 1);
$SIG{__WARN__}= $old_warning_handler;
nok( $warning, "expecting no warning, got '$warning'\n");

$warning="";
$SIG{__WARN__} = sub { $warning.= join '', @_ };
XML::Twig::add_options( 'dummy_opt');
XML::Twig->new( dummy_opt => 1);
$SIG{__WARN__}= $old_warning_handler;
nok( $warning, "expecting no warning (2), got '$warning'\n");
}


{
# test do_not_chain_handlers
my $nb_calls=0;
my $t= XML::Twig->new( twig_handlers => { chain      => sub { $nb_calls++; 1;},
                                         'doc/chain' => sub { $nb_calls++; 1;},
                                        },
                     )->parse( '<doc><chain>chained</chain></doc>');
is( $nb_calls, 2, "chained calls");

$nb_calls=0;
$t= XML::Twig->new( twig_handlers => { chain      => sub { $nb_calls++; 1 },
                                      'doc/chain' => sub { $nb_calls++; 1 },
                                        },
                     do_not_chain_handlers => 1,
                     )->parse( '<doc><chain>chained</chain></doc>');
is( $nb_calls, 1, "not chained calls");

$nb_calls=0;
$t= XML::Twig->new( twig_handlers => { chain      => sub { $nb_calls++; 0; },
                                      'doc/chain' => sub { $nb_calls++; 0; },
                                        },
                     )->parse( '<doc><chain>chained</chain></doc>');
is( $nb_calls, 1, "chained handlers returning 0");
}

# test ignore_elt
{ my $t= XML::Twig->new( ignore_elts => { i1 => 1, i2 => 2})
                  ->parse( '<doc><i1><t/></i1>
                                 <t/><y><t/></y>
                                 <i2><t/><y><t/><i1><t/></i1><t/></y></i2>
                                 <i2><t/><y><t/><i2><t/></i2><t/></y></i2>
                                 <t><t/></t>
                           </doc>');
  my @t= $t->findnodes( '//t');
  my $nb_t= scalar @t;
  is( $nb_t, 4, 'findnodes //t');
}

# test elt_class
{ 

my $t= XML::Twig->new( elt_class => 'twig_test')->parse( '<doc><elt/></doc>');

package twig_test;
use base 'XML::Twig::Elt';
sub test { return 25 }

package main;
is( $t->root->test, 25, 'elt_class');
} 

# test char_handler
{ 
my $t= XML::Twig->new( char_handler => sub { my $s= shift; $s=~ s/\w/./g; return $s; })
                 ->parse( '<doc><elt>foo</elt><elt att="bar">baz</elt></doc>');
my $text= $t->root->text;
is( $text, '......', 'silly char_handler');

my $att= $t->root->last_child( 'elt')->att( 'att');
is( $att, 'bar', 'last_child');
$att= $t->root->last_child( 'elt')->att( 'att'); # to use the cache
is( $att, 'bar', 'last_child');
}

# test various methods
{ my $t= XML::Twig->new->parse( '<doc><elt/><elt/></doc>');
  my @new_children= $t->root->children_copy;
  $t->set_id_seed( 'toto_');
  $_->add_id foreach @new_children;
  my $id= $new_children[0]->att( 'id');
  is( $id, 'toto_1', 'copy att');
  $new_children[1]->change_att_name( id => 'foo');
  my $foo=  $new_children[1]->att( 'foo');
  is( $foo, 'toto_2', 'change_att_name');

  ok( $t->root->all_children_are( 'elt'), "all_children_are( 'elt')");
  nok( $t->root->all_children_are( 'none'), "all_children_are( 'none')");

  my $count= $t->root->children_count( 'elt');
  is( $count, 2, "children_count( 'elt')");
  $count= $t->root->children_count( 'none');
  is( $count, 0, "children_count( 'none')");
  $count= $t->root->children_count;
  is( $count, 2, "children_count");
  ok( $t->root->first_child_matches( 'elt'), "first_child_matches"); 

  $t->root->insert_new_elt( 'p');
  nok( $t->root->all_children_are( 'elt'), "all_children_are( 'elt') (with p child)");

}

# test cdata append_cdata, append_extra_data, append_pcdata
{
my $t=XML::Twig->new->parse( '<doc><elt>text <![CDATA[some cdata]]> more text</elt></doc>');

my $cdata= $t->root->next_elt( CDATA)->cdata;
is( $cdata, 'some cdata', 'created CDATA element');

$t->root->next_elt( CDATA)->append_cdata( ' appended<>');
$t->root->next_elt( PCDATA)->append_pcdata( 'more ');
$t->root->first_child( 'elt')->append_extra_data( '<!-- comment -->');

is( $t->sprint, '<doc><!-- comment --><elt>text more <![CDATA[some cdata appended<>]]> more text</elt></doc>', "append_extra_data");
}

# test att_names and att_to_field
{ 
my $t= XML::Twig->new->parse( '<doc><elt att1="foo" att2="bar"/></doc>');
my $elt= $t->root->first_child_matches( 'elt');
ok( $elt, "first_child_matches");
my $att_names= join ':', sort $elt->att_names;
is( $att_names, 'att1:att2', "att_names");
$elt->att_to_field( 'att1');
$elt->att_to_field( att2 => "new");
my $elt_string= $elt->sprint;
is( $elt_string, '<elt><new>bar</new><att1>foo</att1></elt>', "att_to_field")
}

# test child_matches child_text child_trimmed_text children_text
{ 
my $t= XML::Twig->new->parse( '<doc><elt> text </elt><elt2>  text  text</elt2></doc>');
my $root= $t->root;
ok( $root->child_matches( 1, 'elt2'), "child_matches");

my $text= $root->child_text( 0);
is( $text, ' text ', "child_text");

$text= $root->child_trimmed_text( -1, 'elt2');
is( $text, 'text text', "child_trimmed_text", 25 );

$text= join( '-', $root->children_text( qr/elt/));
is( $text, ' text -  text  text', "children_text");
}

# test _ancestors _children _descendants 
{ my $t= XML::Twig->new->parse( '<doc><elt1/><elt2><elt3/></elt2></doc>');
  is( tags( $t->root->_children), 'elt1:elt2', "_children");
  is( tags( $t->root->_descendants), 'elt1:elt2:elt3', "_descendants");
  is( $t->root->last_child_matches( 'elt3') ? "matches" : "no match",
      "no match", "last_child_matches (no match)");
  my $elt3= $t->root->last_child_matches( 'elt2')->first_child;
  is( $elt3->gi, 'elt3', "last_child_matches (match)");
  is( tags( $elt3->_ancestors), 'elt2:doc', "_ancestors");
  is( tags( $elt3->_ancestors(1)), 'elt3:elt2:doc', "_ancestors(1)");

  is( tags( $t->root->descendants( 'elt1')), 'elt1', 'descendants with gi');
  is( tags( $t->root->descendants( qr/^elt/)), 'elt1:elt2:elt3', 'descendants with qr');
  is( tags( $t->root->descendants( qr/^elt/)), 'elt1:elt2:elt3', 'descendants with qr (using cache)');

} 

# test comment methods
{ 
my $t= XML::Twig->new( comments => 'process')
                ->parse( '<doc><elt>text <!-- foo --></elt></doc>');
my $comment= $t->first_elt( '#COMMENT');
is( $comment->comment, ' foo ', "comment");
is( $comment->comment_string, '<!-- foo -->', "comment");
}

# test element creation
{
my $t= XML::Twig->new->parse( '<doc/>');
my $root= $t->root;
my $elt= $root->insert_new_elt( first_child => 'elt');
my $elt3= $elt->insert_new_elt( after => elt3 => "elt3 text");
my $elt2= $elt3->insert_new_elt( before => elt2 => { att => "foo" }, "elt2 text");
is( $t->sprint, '<doc><elt/><elt2 att="foo">elt2 text</elt2><elt3>elt3 text</elt3></doc>',
    "insert_new_elt");

$root->cut_children;
is( $t->sprint, '<doc></doc>', "cut_children");
$elt= $root->insert_new_elt( last_child => 'elt' => { '#ASIS' => 1 }, "<p>bar</p>");
is( $elt->is_asis ? 'asis' : 'not asis', 'asis', "is_asis (initial, yes)");
is( $t->sprint, '<doc><elt><p>bar</p></elt></doc>', "insert_new_elt (ASIS)");
$elt->set_not_asis;
is( $elt->is_asis ? 'asis' : 'not asis', 'not asis', "is_asis (unset, no)");
is( $t->sprint, '<doc><elt>&lt;p>bar&lt;/p></elt></doc>', "set_not_asis");
$elt->set_asis;
is( $elt->is_asis ? 'asis' : 'not asis', 'asis', "is_asis (set, yes)");
is( $t->sprint, '<doc><elt><p>bar</p></elt></doc>', "set_asis");

$root->cut_children;
$root->insert_new_elt( first_child => '#CDATA' => "toto");
is( $t->sprint, '<doc><![CDATA[toto]]></doc>', "create CDATA");
is($root->last_child_matches( '#CDATA') ? "match" : "no match", "match", "last_child_matches (yes)");
is($root->last_child_matches( "foo") ? "match" : "no match", "no match", "last_child_matches (no)");
my $cdata= $root->last_child_matches( '#CDATA');
ok( $cdata->is_cdata, "cdata is_cdata");
nok( $cdata->is_comment, "cdata is_comment");
nok( $cdata->is_pi, "cdata is_pi");
nok( $cdata->is_empty, "cdata is_empty");
nok( $cdata->is_ent, "cdata is_ent");
ok( $cdata->is_first_child, "cdata is_first_child");
ok( $cdata->is_last_child, "cdata is_last_child");

}

# test field last_child_text last_child_trimmed_text
{ my $t= XML::Twig->new->parse( '<doc><field1>val1</field1><field2>val2</field2></doc>');
  my $root= $t->root;
  $root->set_field( field2 => "new  val2 ");
  is( $root->last_child_text( 'field2'), "new  val2 ", "set_field");
  is( $root->last_child_trimmed_text( 'field2'), "new val2", "set_field (trimmed text)");
  is( $root->last_child_text( 'field1'), "val1", "last_child_text");
  $root->set_field( field3 => "val3");
  is( $t->sprint, '<doc><field1>val1</field1><field2>new  val2 </field2><field3>val3</field3></doc>',
      "set_field (new field)");
}

# test next/prev navigation functions
{ my $t= XML::Twig->new->parse( 
  q{<doc><elt id="elt_1">elt 1</elt>
         <elt id="elt_2">elt 2</elt>
         <sect id="sect_1"><elt id="elt_3">elt 3</elt><elt id="elt_4">elt 4</elt></sect>
         <elt id="elt_5">elt 5 </elt>
    </doc>}
                             );
  my $root= $t->root;
  my $elt1= $t->getElementById( 'elt_1');
  is( $elt1->sprint, '<elt id="elt_1">elt 1</elt>', "getElementById");
  my $sect= $elt1->getElementById( 'sect_1');
  is( $sect->sprint, '<sect id="sect_1"><elt id="elt_3">elt 3</elt><elt id="elt_4">elt 4</elt></sect>', "getElementById (sect)");
  ok( $elt1->next_elt_matches( '#PCDATA[text()="elt 1"]'), "next_elt_matches (elt1 => elt)");
  ok( $elt1->prev_elt_matches( 'doc'), "prev_elt_matches (elt1 => doc)");
  ok( $sect->next_elt_matches( 'elt[@id="elt_3"]'), "next_elt_matches (sect => elt_3)");
  ok( $sect->prev_elt_matches( '#PCDATA[text()="elt 2"]'), "prev_elt_matches (sect => elt_2)");
  is( $sect->next_elt_text( 'elt[@id="elt_5"]'), 'elt 5 ', "next_elt_text");
  is( $sect->next_elt_trimmed_text( 'elt[@id="elt_5"]'), 'elt 5', "next_elt_trimmed_text");
  nok( $sect->next_elt( $sect, 'elt[@id="elt_5"]'), "next_elt (outside the subtree)");
  nok( $sect->next_elt_text( $sect, 'elt[@id="elt_5"]'), "next_elt_text (outside the subtree)");
  is( $sect->first_child_trimmed_text, "elt 3", "first_child_trimmed_text");
  is( $sect->first_child_trimmed_text( 'goofy'), "", "first_child_trimmed_text (no child)");

  # test comparisons $elt1 < $sect < $elt3
  my $elt3= $t->elt_id( 'elt_3');
  ok( $elt1->le( $sect), "\$elt1 le \$sect");
  ok( $elt1->lt( $sect), "\$elt1 lt \$sect");
  nok( $elt1->ge( $sect), "\$elt1 ge \$sect");
  nok( $elt1->gt( $sect), "\$elt1 gt \$sect");

  nok( $elt3->le( $sect), "\$elt3 le \$sect");
  nok( $elt3->lt( $sect), "\$elt3 lt \$sect");
  ok( $elt3->ge( $sect), "\$elt3 ge \$sect");
  ok( $elt3->gt( $sect), "\$elt3 gt \$sect");
}

# test keep_attribute_order
{ eval { require Tie::IxHash; };
  if( $@) { skip( 7, "Tie::IxHash not available"); }
  else
    { import Tie::IxHash;
      my $t= XML::Twig->new( keep_atts_order => 1)
                    ->parse( '<doc att_z="foo" att_a="bar"/>');
      is( $t->sprint, '<doc att_z="foo" att_a="bar"/>', "keep_atts_order");
      ok( $t->keep_atts_order, "keep_atts_order");
      $t= XML::Twig->new->parse( '<doc att_z="foo" att_a="bar"/>');
      is( $t->sprint, '<doc att_a="bar" att_z="foo"/>', "do not keep_atts_order");
      nok( $t->keep_atts_order, "keep_atts_order not used");

      $t->set_keep_atts_order(1);
      my $elt1= $t->root->new( 'elt');
      $elt1->set_att( a1 => 'v1');
      $elt1->set_att( a2 => 'v2');
      is( $elt1->sprint, '<elt a1="v1" a2="v2"/>', 'keep_atts_order with new elt');
      my $elt2= $t->root->new( 'elt');
      $elt2->set_att( a2 => 'v2');
      $elt2->set_att( a1 => 'v1');
      is( $elt2->sprint, '<elt a2="v2" a1="v1"/>', 'keep_atts_order with new elt (reverse order)');
      $t->set_keep_atts_order(0);
      my $elt3= $t->root->new( 'elt');
      $elt3->set_att( a2 => 'v2');
      $elt3->set_att( a1 => 'v1');
      is( $elt3->sprint, '<elt a1="v1" a2="v2"/>', 'no keep_atts_order with new elt (reverse order)');
    }
}

# test wrap_children xml_string
{
my $t= XML::Twig->new->parse( '<doc><elt/><elt/><elt2/></doc>');
$t->set_id_seed( 'id_');;
$t->root->wrap_children( '<elt>+', wrap => { foo => "bar"});
is( $t->sprint, '<doc><wrap foo="bar"><elt id="id_1"/><elt id="id_2"/></wrap><elt2 id="id_3"/></doc>', "wrap_children");
$t->root->strip_att( 'id');
is( $t->sprint, '<doc><wrap foo="bar"><elt/><elt/></wrap><elt2/></doc>', "wrap_children");
is( $t->root->xml_string, '<wrap foo="bar"><elt/><elt/></wrap><elt2/>', "xml_string");
}

# test set_output_encoding xml_text
{ 
my $t= XML::Twig->new->parse( '<doc><elt>elt 1</elt><elt> elt 2</elt></doc>');
is( $t->root->xml_text, 'elt 1 elt 2', "xml_text");
is( $t->root->xml_string, '<elt>elt 1</elt><elt> elt 2</elt>', "xml_text");
$t->set_output_filter( sub { return '.' x length $_[0] });
is( $t->root->xml_text, '...........', "xml_text (encoded)");
is( $t->root->xml_string, '.................................', "xml_text (encoded)");
 
}

# is_first_child is_last_child test contains_a_single contains_only
{
my $t= XML::Twig->new->parse( q{
<doc><elt><elt2>e2_1</elt2></elt>
     <elt><elt2>e2_2</elt2><elt2>e2_3</elt2></elt>
     <elt><elt2>e2_4</elt2><elt2>e2_5</elt2><elt3>e3_1</elt3></elt>
     <elt/>
</doc>});

my $elt1= $t->root->first_child('*');
my $elt2= $t->root->child( 1);
my $elt3= $t->root->first_child( sub { $_[0]->children_count( 'elt3') == 1 });
my $elt4= $t->root->last_child;

nok( $t->root->child( 6), 'child(6)');
nok( $t->root->child( -6), 'child(-6)');
nok( $t->root->child( 1, 'foo'), 'child(1, foo)');
nok( $t->root->child( -1, 'foo'), 'child(-1, foo)');
nok( $elt4->child( 1), 'child(1) on empty elt on empty elt');
nok( $elt4->child( 1, 'foo'), 'child(1, foo) on empty elt');
nok( $elt4->child( -1), 'child(-1) on empty elt');
nok( $elt4->child( -1, 'foo'), 'child(-1, foo) on empty elt');

ok( $elt1->is_first_child, "\$elt1->is_first_child");
nok( $elt2->is_first_child, "\$elt2->is_first_child is false");
nok( $elt3->is_first_child, "\$elt3->is_first_child is false");

nok( $elt1->is_last_child, "\$elt1->is_last_child");
nok( $elt2->is_last_child, "\$elt2->is_last_child");
ok( $elt4->is_last_child, "\$elt3->is_last_child is false");

ok( $elt1->contains_a_single( 'elt2'), "\$elt1->contains_a_single( 'elt2')");
nok( $elt1->contains_a_single( 'elt'), "\$elt1->contains_a_single( 'elt')");
nok( $elt2->contains_a_single( 'elt2'), "\$elt2->contains_a_single( 'elt2')");
nok( $elt3->contains_a_single( 'elt2'), "\$elt3->contains_a_single( 'elt2')");
nok( $elt4->contains_a_single( 'elt2'), "\$elt4->contains_a_single( 'elt2')");

ok( scalar $elt1->contains_only( 'elt2'), "\$elt1->contains_only( 'elt2')");
nok( $elt1->contains_only( 'elt'), "\$elt1->contains_only( 'elt') is false");
ok( scalar $elt2->contains_only( 'elt2'), "\$elt2->contains_only( 'elt2')");
nok( $elt3->contains_only( 'elt2'), "\$elt3->contains_only( 'elt2') is false");
ok( $elt4->contains_only( 'elt2'), "\$elt4->contains_only( 'elt2')");

is( $elt1->next_sibling_text, $elt2->text, "next_sibling_text");
is( $elt1->next_sibling_text, $elt2->text, "next_sibling_text using the cache");
is( $elt1->parent_text, $t->root->text, "parent_text");
is( $elt1->parent_text('doc'), $t->root->text, "parent_text");
is( $elt1->first_child->parent_text('doc'), $t->root->text, "parent_text");
ok( $elt2->parent_matches( 'doc'), "elt->parent_matches( 'doc')");
nok( $elt2->parent_matches( 'elt'), "elt->parent_matches( 'elt') is false");

nok( $t->root->parent, 'root parent');
nok( $t->root->parent_matches( 'doc'), 'root parent( doc)');
nok( $t->root->parent_matches( 'foo'), 'root parent( foo)');

is( $elt2->level, 1, "level");
is( $elt2->level( 'elt'), 0, "level( elt)");
is( $elt2->level( 'doc'), 1, "level( doc)");
is( $elt2->level( 'foo'), 0, "level( foo)");

nok( $elt2->first_child_text( 'foo'), "first_child_text on empty elt( 'foo')");
nok( $elt2->first_child_trimmed_text( 'foo'), "first_child_trimmed_text on empty elt( 'foo')");

nok( $elt4->next_sibling, 'next_sibling on last');
nok( $elt4->first_child, 'first_child on empty');
nok( $elt4->last_child, 'last_child on empty');
nok( $elt4->next_sibling_text, 'next_sibling_text on last');
nok( $elt4->first_child_text, 'first_child_text on empty');
nok( $elt4->last_child_text, 'last_child_text on empty');
nok( $elt4->next_sibling_trimmed_text, 'next_sibling_trimmed_text on last');
nok( $elt4->first_child_trimmed_text, 'first_child_trimmed_text on empty');
nok( $elt4->last_child_trimmed_text, 'last_child_trimmed_text on empty');

nok( $elt1->prev_sibling, 'prev_sibling on last');
nok( $elt1->prev_sibling_text, 'prev_sibling_text on last');
nok( $elt1->prev_sibling_trimmed_text, 'prev_sibling_trimmed_text on last');
}
 
# test next_n_elt del_id delete empty_tag_style
{
my $t= XML::Twig->new->parse( '<doc><elt id="id1"/></doc>');
my $elt= $t->root->next_n_elt( 1);
is( $elt->gi, 'elt', "next_n_elt");
is( $t->elt_id( 'id1')->gi, 'elt', "elt_id");
$elt->del_id;
is( $t->sprint, '<doc><elt/></doc>', "del_id");
nok( $t->elt_id( 'id1'), "no elt_id( 'id1')");
$elt->set_id( 'id2');
is( $t->sprint, '<doc><elt id="id2"/></doc>', "set_id");
is( $t->elt_id( 'id2')->gi, "elt", "elt_id after set_id");
$elt->delete;
is( $t->sprint, '<doc></doc>', "delete");
$t->root->insert_new_elt( first_child => '#COMMENT' => "a comment");
is( $t->sprint, '<doc><!--a comment--></doc>', "add comment");

$elt= $t->root->insert_new_elt( last_child => elt => { '#EMPTY' => 1 });
is( $t->sprint, '<doc><!--a comment--><elt/></doc>', "empty element");
ok( $elt->is_empty, "\$elt is empty");
$elt->set_not_empty;
is( $t->sprint, '<doc><!--a comment--><elt></elt></doc>', "non empty element");
nok( $elt->is_empty, "\$elt is not empty");
$elt->set_empty;
ok( $elt->is_empty, "\$elt is empty");
is( $t->sprint, '<doc><!--a comment--><elt/></doc>', "empty element again");
$t->set_empty_tag_style( 'html');
is( $t->sprint, '<doc><!--a comment--><elt /></doc>', "empty element (html style)");
$t->set_empty_tag_style( 'expand');
is( $t->sprint, '<doc><!--a comment--><elt></elt></doc>', "empty element (expand style)");
$t->set_empty_tag_style( 'normal');
is( $t->sprint, '<doc><!--a comment--><elt/></doc>', "empty element (normal style)");

$elt->set_content( "toto");
nok( $elt->is_empty, "\$elt is not empty");
is( $t->sprint, '<doc><!--a comment--><elt>toto</elt></doc>', "element with content");

nok( $elt->prev_sibling_matches( '#PI'), "prev_sibling_matches nok");
my $comment= $elt->prev_sibling_matches( '#COMMENT');
ok( $comment, "prev_sibling_matches ok");
$comment= $elt->prev_sibling;
is( $comment->gi, '#COMMENT', 'prev_sibling');
$comment= $elt->prev_sibling;
is( $comment->gi, '#COMMENT', 'prev_sibling using the cached cond');
$comment= $elt->prev_sibling( '#COMMENT');
is( $comment->gi, '#COMMENT', 'prev_sibling');
$comment= $elt->prev_sibling( '#COMMENT');
is( $comment->gi, '#COMMENT', 'prev_sibling using the cached cond');

$comment->set_comment( "another comment");
is( $t->sprint, '<doc><!--another comment--><elt>toto</elt></doc>', "element with content");

$t->root->field_to_att( 'elt');
is( $t->sprint, '<doc elt="toto"><!--another comment--></doc>', "field_to_att");

$t->root->del_att( 'elt');
$t->root->first_child( '#COMMENT')->delete;
is( $t->sprint, '<doc></doc>', "back to a very simple doc");

$t->root->insert( elt => { att => "v2" });
$t->root->first_child->set_content( "val 3");
$t->root->insert_new_elt( first_child => elt => { att => "v1" }, "val 2");
$t->root->insert_new_elt( last_child => elt => { att => "v3" }, "val 1");
is( $t->sprint, '<doc><elt att="v1">val 2</elt><elt att="v2">val 3</elt><elt att="v3">val 1</elt></doc>',
    "insert 3 elements");
$t->root->sort_children_on_value;
is( $t->sprint, '<doc><elt att="v3">val 1</elt><elt att="v1">val 2</elt><elt att="v2">val 3</elt></doc>',
    "sort_children_on_value");
$t->root->sort_children_on_att( "att",  order => "reverse" );
is( $t->sprint, '<doc><elt att="v3">val 1</elt><elt att="v2">val 3</elt><elt att="v1">val 2</elt></doc>',
    "sort_children_on_att (reverse)");

$t->root->set_text( "fini fini");
is( $t->sprint, '<doc>fini fini</doc>');
my $p= $t->root->insert( 'p');
my $new_p= $p->split_at( 4);
is( $t->sprint, '<doc><p>fini</p><p> fini</p></doc>', "split_at");
$p->split( qr/(i)/, 'b' );
is( $p->sprint, '<p>f<b>i</b>n<b>i</b></p>', "split");
$new_p->split( qr/(i)/, b => { foo => "bar" } );
is( $new_p->sprint, '<p> f<b foo="bar">i</b>n<b foo="bar">i</b></p>', "split (with att)");
}

# test start_tag_handlers
{ 
my @results;
my $handler;
my $t=XML::Twig->new( start_tag_handlers =>{ elt => \&sth1});

sub sth1 
  { my( $t, $elt)= @_;
    push @results, "handler 1: ". $elt->id;
    $handler= $t->setStartTagHandler( elt => \&sth2);
  }
 
sub sth2 
  { my( $t, $elt)= @_;
    push @results, "handler 2: ". $elt->id;
    $t->setStartTagHandler( elt => $handler);
  }
 
$t->parse( '<doc><elt id="id1"><elt2><elt id="id2"></elt></elt2><elt id="id3"></elt></elt></doc>');

is( shift @results, "handler 1: id1", "handler 1");
is( shift @results, "handler 2: id2", "handler 2");
is( shift @results, "handler 1: id3", "handler 1 again");
}

{
my $t= XML::Twig->new( pi =>'process')->parse( '<doc><?t1 data1?><elt/></doc>');
my $pi= $t->root->first_child( '#PI');
$pi->set_target( 't2');
$pi->set_data( 'data2');
is( $pi->sprint, '<?t2 data2?>', "pi");
my $elt= $pi->next_sibling;
$elt->set_extra_data( '<!-- comment -->');
is( $elt->sprint, "<!-- comment --><elt/>", "elt with comment");
}

{
my $t= XML::Twig->new->parse( '<doc><elt>  elt  1 </elt> <elt>  elt   2 </elt></doc>');
my $elt1= $t->root->first_child;
my $elt2= $t->root->last_child;
is( $elt2->prev_sibling_text, '  elt  1 ', "prev_sibling_text");
is( $elt2->prev_sibling_trimmed_text, 'elt 1', "prev_sibling_trimmed_text");
is( $elt1->next_sibling_trimmed_text, 'elt 2', "next_sibling_trimmed_text");
ok( $elt1->next_sibling_matches( 'elt'), "next_sibling_matches ok");
nok( $elt2->next_sibling_matches( 'elt'), "next_sibling_matches nok");

is( $elt2->prev_elt_text( 'elt'), "  elt  1 ", "prev_elt_text");
is( $elt2->prev_elt_trimmed_text( 'elt'), "elt 1", "prev_elt_trimmed_text");

is( $elt2->parent_trimmed_text, "elt 1 elt 2", "parent_trimmed_text");

is( $elt1->sibling( 1)->trimmed_text, "elt 2", "sibling(1)");
is( $elt2->sibling( -1)->trimmed_text, "elt 1", "sibling(-1)");

is( $elt1->sibling_text( 1), "  elt   2 ", "sibling(1)");
is( $elt2->sibling_text( -1), "  elt  1 ", "sibling(-1)");

is( scalar $elt1->next_siblings, 1, "next_siblings");
is( scalar $elt1->next_siblings( 'elt2'), 0, "next_siblings (none)");

}

{
my $t= XML::Twig->new->parse( '<doc><elt1/><elt2/></doc>');
my $elt1= $t->first_elt( 'elt1');
my $elt2= $t->first_elt( 'elt2');
$elt2->move( before => $elt1);
is( $t->sprint, '<doc><elt2/><elt1/></doc>', "cut");
$elt2->cut;
is( $t->sprint, '<doc><elt1/></doc>', "cut");
$elt2->replace( $elt1);
is( $t->sprint, '<doc><elt2/></doc>', "replace");
$elt2->set_content( "toto");
$elt2->suffix( ":foo");
is( $elt2->xml_string, "toto:foo", "suffix");
$elt2->replace_with( $elt1);
is( $t->sprint, '<doc><elt1/></doc>', "replace_with");
$elt1->set_content( "tto");
my $o= XML::Twig::Elt->new( b => "o");
$o->paste_within( $elt1, 1);
is( $t->sprint, '<doc><elt1>t<b>o</b>to</elt1></doc>', "replace_with");

}

# test methods inherited from XML::Parser::Expat
{
my $t= XML::Twig->new( twig_handlers => { elt => \&test_inherited })
                ->parse( '<doc><sect><elt>toto</elt></sect></doc>');

sub test_inherited
  { my( $t, $elt)= @_;
    is( $t->depth, 2, "depth");
    ok( $t->in_element( 'sect'), "in_element");
    nok( $t->in_element( 'elt'), "in_element (false)");
    ok( $t->within_element( 'sect'), "within_element");
    ok( $t->within_element( 'doc'), "within_element");
    nok( $t->within_element( 'elt'), "within_element (false)");
    is( join( '/', $t->context), "doc/sect", "context");
    is( $t->current_line, 1, "current_line");
    is( $t->current_byte, 20, "current_byte");
    is( $t->original_string, "</elt>", "original_string");
    is( $t->recognized_string, "</elt>", "recognized_string");
    is( $t->current_element, "sect", "current_element");
    if( $XML::Parser::VERSION>2.27)
      { is( $t->element_index, 3, "element_index"); }
    else
      { is( $t->element_index, 2, "element_index"); }
    $t->base( "foo");
    is( $t->base, "foo", "base");
    ok( $t->position_in_context( 1), "position_in_context");

    my $xml= '<elt>toto</elt>';
    my $expected= '&lt;elt>toto&lt;/elt>';
    my $broken= '&lt;elt>toto</elt>';
    my $xml_escape= $t->xml_escape( $xml);
    if( $xml_escape eq $expected)
      { ok( 1, "xml_escape"); }
    elsif( $xml_escape eq $broken)
      { warn "your version of expat/XML::Parser has a broken xml_escape method\n",
             "xml_escape( '$xml') should be '$expected' but is '$broken' instead\n";
        ok( 1);
      }
    else
      { is( $xml_escape, $expected, "xml_escape"); }
               
    $xml= '<elt>toto</elt>';
    $expected= '&lt;elt>t&#x6F;t&#x6F;&lt;/elt>';
    $broken= '&lt;elt>t&#x6F;t&#x6F;</elt>';
    $xml_escape= $t->xml_escape( $xml, 'o');
    if( $xml_escape eq $expected)
      { ok( 1, "xml_escape"); }
    elsif( $xml_escape eq $broken)
      { warn "your version of expat/XML::Parser has a broken xml_escape method\n",
             "xml_escape( '$xml', 'o') should be '$expected' but is '$broken' instead\n";
        ok( 1);
      }
    else
      { is( $xml_escape, $expected, "xml_escape"); }
  }
}

{
my $t= XML::Twig->new( start_tag_handlers => { i => sub { $_[0]->ignore }, }, 
                       twig_handlers      => { s => sub { $_[0]->finish }, } )
                ->parse( '<doc><elt>foo</elt><i><elt>toto</elt></i><elt2/><s>toto</s><elt>bar</elt></doc>');
is( $t->sprint, "<doc><elt>foo</elt><elt2/><s>toto</s></doc>", "ignore + finish");
}

# test xml declaration and entity related methods
{
my $t= XML::Twig->new->parse( '<?xml version="1.0" encoding="ISO-8859-1" standalone="no"?>
<!DOCTYPE doc SYSTEM "dummy.dtd" [
<!ENTITY ent1 "toto">
<!ENTITY ent2 "<p>tata</p>">
<!ENTITY ent3 SYSTEM "ent3.png" NDATA PNG> ]>
<doc><elt>&ent1;</elt><elt>&ent2;</elt><elt img="ent3"/></doc>');

is( $t->xml_version, "1.0", "xml_version");
is( $t->encoding, "ISO-8859-1", "encoding");
nok( $t->standalone, "standalone (no)");
is( $t->xmldecl, qq{<?xml version="1.0" encoding="ISO-8859-1" standalone="no"?>\n}, "xmldecl");

$t->set_xml_version( "1.1");
is( $t->xml_version, "1.1", "set_xml_version");
$t->set_encoding( "UTF-8");
is( $t->encoding, "UTF-8", "set_encoding");
$t->set_standalone( 1);
ok( $t->standalone||'', "set_standalone");
is( $t->xmldecl, qq{<?xml version="1.1" encoding="UTF-8" standalone="yes"?>\n}, "xmldecl");

is( join( ':', sort $t->entity_names), "ent1:ent2:ent3", "entity_names");

my $ent1= $t->entity( 'ent1');
is( $ent1->name, "ent1", "entity name");
is( $ent1->val, "toto", "entity val");
nok( $ent1->sysid, "entity sysid (none)");
nok( $ent1->pubid, "entity pubid (none)");
nok( $ent1->ndata, "entity ndata (none)");

my $ent3= $t->entity( 'ent3');
is( $ent3->name, "ent3", "entity name");
nok( $ent3->val, "entity val (none)");
is( $ent3->sysid, "ent3.png", "entity sysid");
nok( $ent3->pubid, "entity pubid (none)");
is( $ent3->ndata, "PNG", "entity ndata");

my $doctype= qq{<!DOCTYPE doc SYSTEM "dummy.dtd" [\n<!ENTITY ent1 "toto">\n<!ENTITY ent2 "<p>tata</p>">\n<!ENTITY ent3 SYSTEM "ent3.png" NDATA PNG> \n]>};
is( $t->doctype, $doctype, "doctype");

my $ent4= $t->entity_list->add_new_ent( ent4 =>  "ent 4");
is( $ent4->text, qq{<!ENTITY ent4 "ent 4">}, "add_new_ent");

my $ent5= $t->entity_list->add_new_ent( ent5 =>  "", "ent5.png", "", "PNG" );
is( $ent5->text, qq{<!ENTITY ent5 SYSTEM "ent5.png" NDATA PNG>}, "add_new_ent (ndata)");

is( join( ':', sort $t->entity_names), "ent1:ent2:ent3:ent4:ent5", "entity_names");

is( $t->doctype, $doctype, "doctype");

my $prolog=qq{<?xml version="1.1" encoding="UTF-8" standalone="yes"?>
<!DOCTYPE doc SYSTEM "dummy.dtd"[
<!ENTITY ent1 "toto">
<!ENTITY ent2 "<p>tata</p>">
<!ENTITY ent3 SYSTEM "ent3.png" NDATA PNG>
<!ENTITY ent4 "ent 4">
<!ENTITY ent5 SYSTEM "ent5.png" NDATA PNG>]>};

is( $t->prolog( UpdateDTD => 1), $prolog, "prolog, updated DTD");

$t->entity_list->delete( 'ent3');
is( join( ':', sort $t->entity_names), "ent1:ent2:ent4:ent5", "entity_names");
$t->entity_list->delete( ($t->entity_list->list)[0]);
is( join( ':', sort $t->entity_names), "ent2:ent4:ent5", "entity_names");

}

{
my $t= XML::Twig->new( comments => 'process', pi =>'process')
                ->parse( '<doc><!--comment--><?target pi?>text<![CDATA[cdata]]></doc>');
is( $t->root->first_child( '#COMMENT')->get_type, "#COMMENT", "get_type #COMMENT");
is( $t->root->first_child( '#PI')->get_type, "#PI", "get_type #PI");
is( $t->root->first_child( '#CDATA')->get_type, "#CDATA", "get_type #CDATA");
is( $t->root->first_child( '#PCDATA')->get_type, "#PCDATA", "get_type #PCDATA");
is( $t->root->get_type, "#ELT", "get_type #ELT");
my $cdata= $t->root->first_child( '#CDATA');
$cdata->set_cdata( "new cdata");
is( $cdata->sprint, "<![CDATA[new cdata]]>", "set_cdata");
my $copy= $t->root->copy;
is( $copy->sprint, $t->root->sprint, 'copy of an element with extra data');

is( $t->sprint( pretty_print => 'indented'),
    qq{<doc><!--comment--><?target pi?>text<![CDATA[new cdata]]></doc>\n},
    'indented elt');

}


{ 
my $t= XML::Twig->new->parse( '<!DOCTYPE doc SYSTEM "dummy.dtd"><doc> text &ent; more</doc>');
my $ent= $t->first_elt( '#ENT');
is( $ent->get_type, "#ENT", "get_type");
is( $ent->ent, '&ent;', "ent");
is( $ent->ent_name, 'ent', "ent_name");
$ent->set_ent( '&new_ent;');
is( $ent->ent, '&new_ent;', "new_ent ent");
is( $ent->ent_name, 'new_ent', "new_ent ent_name");
}

{ 
my $t= XML::Twig->new->parse( '<doc>text xx more text xx end</doc>');
$t->root->mark( ' (xx) ', b => { att => "y" });
is( $t->sprint, '<doc>text<b att="y">xx</b>more text<b att="y">xx</b>end</doc>',
    "mark");
}

{
my $t= XML::Twig->new->parse( '<doc att="foo"/>');
is( $t->sprint, '<doc att="foo"/>');
$t->save_global_state;
$t->set_quote( 'single');
is( $t->sprint, "<doc att='foo'/>");
$t->restore_global_state;
is( $t->sprint, '<doc att="foo"/>');
}

{
my $t= XML::Twig->new->parse( '<doc><elt>text <b>bold text</b> more text and text </elt><elt> even more text</elt></doc>');
$t->subs_text( 'text', 'stuff');
is( $t->sprint, "<doc><elt>stuff <b>bold stuff</b> more stuff and stuff </elt><elt> even more stuff</elt></doc>", "subs_text");
$t->subs_text( qr{stuf+}, 'text');
is( $t->sprint, "<doc><elt>text <b>bold text</b> more text and text </elt><elt> even more text</elt></doc>", "subs_text");
my $elt= $t->root->first_child;
my $bold= $elt->first_child( 'b');
$bold->erase;
is( $t->sprint, "<doc><elt>text bold text more text and text </elt><elt> even more text</elt></doc>", "erase");
$elt->first_child->merge_text( $elt->child( 1));
is( $elt->first_child_text, "text bold text", "merge_text");
}

# more tests on subs_text
{ 
my $doc='<doc><p>link to http://www.xmltwig.com but do not link to http://bad.com, though link to toto and link to http://www.xml.com</p><p>now http://www.nolink.com and do not link to this and do not link to http://www.bad.com and do not link to http://www.bad2.com and link to http://link.com also</p></doc>';
my $expected='<doc><p>see <a href="http://www.xmltwig.com">www.xmltwig.com</a> but do not link to http://bad.com, though link to toto and see <a href="http://www.xml.com">www.xml.com</a></p><p>now http://www.nolink.com and do not link to this and do not link to http://www.bad.com and do not link to http://www.bad2.com and see <a href="http://link.com">link.com</a> also</p></doc>';
my $t= XML::Twig->new->parse( $doc);
my $got= $t->subs_text( qr{(?<!do not )link to (http://([^\s,]*))}, 'see &elt( a =>{ href => $1 }, $2)');
is( $got->sprint, $expected, 'complex substitution with subs_text');
}

{ 
my $doc='<doc>text <p>and  more text</p></doc>';
(my $expected= $doc)=~ s{ }{&nbsp;}g;
my $t= XML::Twig->new->parse( $doc);
my $got= $t->subs_text( qr{ }, '&ent( "&nbsp;")');
is( $got->sprint, $expected, 'creating entities with subs_text');
$t= XML::Twig->new->parse( $doc);
my $ent="&nbsp;";
$got= $t->subs_text( qr{ }, "&ent( '$ent')");
is( $got->sprint, $expected, 'creating entities from a variable with subs_text');
}

{
my $t= XML::Twig->new->parse( 
'<doc>
  <record><key>03</key><val>val 1</val></record>
  <record><key>2</key><val>val 2</val></record>
  <record><key>4</key><val>val 3</val></record>
  <record><key>01</key><val>val 4</val></record>
</doc>');

$t->root->sort_children_on_field( 'key', type =>'numeric' );
my $expected=
'
<doc>
 <record><key>01</key><val>val 4</val></record>
 <record><key>2</key><val>val 2</val></record>
 <record><key>03</key><val>val 1</val></record>
 <record><key>4</key><val>val 3</val></record>
</doc>
';
$t->set_pretty_print( 'record_c');
$t->set_indent( ' ');
is( $t->sprint, $expected, "sort_children_on_field");
$t->set_indent( '  ');
}

{ 
my $t= XML::Twig->new( empty_tags => 'expand', pretty_print => 'none')->parse( '<doc><elt/></doc>');
is( $t->sprint, "<doc><elt></elt></doc>", "empty_tags expand");
is( $t->sprint( empty_tags => 'normal'), "<doc><elt/></doc>", "empty_tags normal");
is( $t->sprint( pretty_print => 'indented', empty_tags => 'normal'), "<doc>\n  <elt/>\n</doc>\n", "empty_tags expand");
$t->set_pretty_print( 'none');
$t->set_empty_tag_style( 'normal');
}

{
my $t= XML::Twig->new->parse( '<doc xmlns="uri_def" xmlns:ns1="uri1"><elt/><ns1:elt/></doc>');
my $elt1= $t->root->first_child( 'elt');
my $elt2= $t->root->first_child( 'ns1:elt');
is( $elt1->namespace, "uri_def", "default namespace");
is( $elt2->namespace, "uri1", "namespace");
is( $elt1->expand_ns_prefix, "uri_def", "expand_ns_prefix default");
is( $elt1->expand_ns_prefix( 'ns1'), "uri1", "expand_ns_prefix not default");
is( join( ' - ', $elt1->current_ns_prefixes), '#default', "current_ns_prefixes");
is( join( ' - ', $elt2->current_ns_prefixes), '#default - ns1', "current_ns_prefixes");
}

{
my $t=XML::Twig->new( ignore_elts => { i => 1 });
$t->parse( '<doc><elt1/><i><elt2/></i><elt3><i/><elt4/></elt3></doc>');
is( $t->sprint, '<doc><elt1/><elt3><elt4/></elt3></doc>', "setIgnoreEltsHandler");
}
{
my $t=XML::Twig->new;
$t->setIgnoreEltsHandler( i => 'discard');
$t->parse( '<doc><elt1/><i><elt2/></i><elt3><i/><elt4/></elt3></doc>');
is( $t->sprint, '<doc><elt1/><elt3><elt4/></elt3></doc>', "setIgnoreEltsHandler");
}

# test setEndTagHandler
{ my $called="";
  my $t= XML::Twig->new( twig_roots => { title => 1 });
  my $doc=q{<doc><sect id="sect1"><title id="title1">title 1</title><p id="p1"/></sect>
                 <sect id="sect2"><title id="title2">title 2</title><p id="p2"/></sect>
            </doc>};
  $t->parse( $doc);
  is( $called, "", "no end_tag_handler");
  $called= '';
  $t->setEndTagHandler( sect => sub { $called.= ":" if( $called); $called .= $_[1]});
  $t->parse( $doc);
  is( $called, "sect:sect", "end_tag_handler");
  $called= '';
  $t->setEndTagHandler( sect => sub { return });
  $t->parse( $doc);
  is( $called, "", "empty end_tag_handler");
}

# test replace_prefix
{ my $called='';
  my $not_called='';
  my $t= XML::Twig->new( namespaces => 1,
                         map_xmlns => { "uri1" => "foo", "uri2" => "whatever" },
                         twig_handlers => { "foo:bar" => sub  { $called.= ":" if( $called); 
                                                                $called .= $_->id
                                                               },
                                            "toto:bar" => sub  { $not_called.= ":" if( $not_called); 
                                                                 $not_called .= $_->id
                                                               },
                                          },
                       );
  $t->parse( q{<doc xmlns:toto="uri1" xmlns:foo="uri2" xmlns:no="uri3"><toto:bar id="ok1"/><foo:bar id="nok1" />
                 <toto:bar id="ok2"/><foo:bar id="nok2" /><no:bar id="no1" /> <bar id="no2"/></doc>});
  is( $called, "ok1:ok2", "map_xmlns");
  is( $not_called, "", "map_xmlns (no hit)");
}

# test parser
{ my $t= XML::Twig->new( twig_handlers => 
    { doc => sub { is( ref( $_[0]->parser), 'XML::Parser::Expat', "parser"); } },
                       )
                  ->parse( "<doc />");
  is( ref( $t->parser), '', "parser (empty, after the parse)");
  $t->set_doctype( doc => "doc.dtd");
  is( $t->sprint, qq{<!DOCTYPE doc SYSTEM "doc.dtd"><doc/>}, "set_doctype");
  $t->set_doctype( doc => "doc.dtd", "-//public id/");
  is( $t->sprint, qq{<!DOCTYPE doc PUBLIC "-//public id/" "doc.dtd"><doc/>}, "set_doctype");
  $t->set_doctype( doc => "doc.dtd", undef, qq{[<!ENTITY toto "foo">]});
  is( $t->sprint, qq{<!DOCTYPE doc SYSTEM "doc.dtd"\n[<!ENTITY toto "foo">]><doc/>}, "set_doctype");
#set_doctype ($name, $system, $public, $internal)
}

{ if( $perl < 5.008)  
    { skip( 3, "need perl 5.8 or above to perform these tests (you have $perl)"); }
  else
    { my $out='';
      open( my $fh, ">", \$out);
      my $doc= q{<doc><sect><p>p1</p><p>p2</p><flush/></sect></doc>};
      my $t= XML::Twig->new( twig_handlers => { flush => sub { $_[0]->flush( $fh) } } )
                      ->parse( $doc);
      is( $out, q{<doc><sect><p>p1</p><p>p2</p><flush/>}, "flush");
      close $fh;

      $out="";
      open( $fh, ">", \$out);
      $t= XML::Twig->new( twig_handlers => { flush => sub { $_[0]->flush_up_to( $_->prev_sibling, $fh) } } )
                      ->parse( $doc);
      is( $out, q{<doc><sect><p>p1</p><p>p2</p>}, "flush_up_to");

      $t= XML::Twig->new( twig_handlers => { purge => sub { $_[0]->purge_up_to( $_->prev_sibling->prev_sibling, $fh) } } )
                      ->parse( q{<doc><sect2/><sect><p>p1</p><p><sp>sp 1</sp></p><purge/></sect></doc>});
      is( $t->sprint, q{<doc><sect><p><sp>sp 1</sp></p><purge/></sect></doc>}, "purge_up_to");
    }
}
      
# test next_n_elt for a twig
{ my $t= XML::Twig->new->parse( q{<doc><e1><e2>e 2</e2><e3>e 3</e3></e1></doc>});
  is( $t->next_n_elt( 1)->gi, "doc", "next_n_elt(1)");
  is( $t->next_n_elt( 3)->gi, "e2", "next_n_elt(3)");
  is( $t->next_n_elt( 1, "e3")->gi, "e3", "next_n_elt(1, e3)");
  nok( $t->next_n_elt( 2, "e3"), "next_n_elt(2, e3)");
  is( join(':', map { $_->gi } $t->_children), 'doc', "$t->_children");
}

# test dtd_print
{ if( $perl < 5.008)  
    { skip( 2, "need perl 5.8 or above to perform these tests (you have $perl)"); }
  else
    { 
      { my $out='';
        open( my $fh, ">", \$out);
        my $t= XML::Twig->new()->parse( q{<!DOCTYPE doc [<!ELEMENT doc (#PCDATA)*>]><doc>toto</doc>});
        $t->dtd_print( $fh);
        is( $out, "<!DOCTYPE doc [\n<!ELEMENT doc (#PCDATA)*>\n\n]>\n", "dtd_print");
        close $fh;
      }
      { my $out="";
        open( my $fh, ">", \$out);
        my $t= XML::Twig->new( twig_handlers => { stop => sub { print $fh "[X]"; $_->set_text( '[Y]'); $_[0]->flush( $fh); $_[0]->finish_print( $fh); } })
                        ->parse( q{<doc>before<stop/>finish</doc>});
        select STDOUT;
        is( $out, q{[X]<doc>before<stop>[Y]</stop>finish</doc>}, "finish_print");
      }
    }
}

# test set_input_filter
{ my $t=XML::Twig->new( input_filter => \&rot13)
                 ->parse( q{<doc att="foo">text</doc>});
  is( $t->sprint, q{<qbp ngg="sbb">grkg</qbp>}, "input filter");
  $t=XML::Twig->new;
  $t->parse( q{<doc att="foo">text</doc>});
  is( $t->sprint, q{<doc att="foo">text</doc>}, "input filter (none)");
  $t->set_input_filter( \&rot13);
  $t->parse( q{<qbp ngg="sbb">grkg</qbp>});
  is( $t->sprint, q{<doc att="foo">text</doc>}, "set_input_filter");
}

sub rot13 { $_[0]=~ tr/a-z/n-za-m/; $_[0]; }

# test global_state methods
{ my $doc= q{<doc att="foo"><p>p 1</p><p>p 2</p></doc>};
  my $t=XML::Twig->new->parse( $doc);
  is( $t->sprint, $doc, "initial state");
  my $state= $t->global_state;
  $t->set_pretty_print( 'indented');
  $t->set_indent( 8);
  nok( $t->sprint eq $doc, "changed state");
  $t->set_global_state( $state);
  is( $t->sprint, $doc, "re-set initial state");
  $t->save_global_state;
  $t->set_pretty_print( 'nice');
  $t->set_quote( 'single');
  nok( $t->sprint eq $doc, "changed state");
  $t->restore_global_state( $state);
  is( $t->sprint, $doc, "restored initial state");
}

# test encoding functions
{  if( $perl < 5.008)  
    { skip( 19, "need perl 5.8 or above to perform these tests (you have $perl)"); }
  else
    { require Encode; import Encode;
      my $text= "\x{E9}t\x{E9}";
      my $text_latin1 = encode( latin1 => $text);
      my $text_utf8   = encode( utf8   => $text);
      my $text_html="&eacute;t&eacute;";
      my $text_safe= "&#233;t&#233;";
      my $text_safe_hex= "&#xe9;t&#xe9;";
      my $doc_latin1=qq{<?xml version="1.0" encoding="ISO-8859-1"?>\n<doc>$text_latin1</doc>};
      my $doc_utf8=qq{<?xml version="1.0" encoding="UTF-8"?>\n<doc>$text_utf8</doc>};
      my $doc_html=qq{<?xml version="1.0" encoding="UTF-8"?>\n<doc>$text_html</doc>};
      my $doc_safe=qq{<?xml version="1.0" encoding="UTF-8"?>\n<doc>$text_safe</doc>};
      my $doc_safe_hex=qq{<?xml version="1.0" encoding="UTF-8"?>\n<doc>$text_safe_hex</doc>};
      my $doc_escaped= xml_escape( $doc_html);

      my $t= XML::Twig->new( output_encoding => "ISO-8859-1")->parse( $doc_utf8);
      $t->save_global_state;
      is( $t->output_encoding, 'ISO-8859-1', "output_encoding (ISO-8859-1)");
      is( $t->sprint, $doc_latin1, "output_encoding ISO-8859-1");
      $t->set_output_encoding( "UTF-8");
      is( $t->output_encoding, 'UTF-8', "output_encoding (UTF-8)");
      is( $t->sprint, $doc_utf8, "output_encoding UTF-8");
      $t->set_output_text_filter( 'safe');
      is( $t->sprint, $doc_safe, 'safe');
      $t->set_output_text_filter( 'safe_hex');
      is( $t->sprint, $doc_safe_hex, 'safe_hex');
      $t->set_output_text_filter( );
      
      $t->restore_global_state;

      eval "require HTML::Entities";
      if( $@) 
        { skip( 4, "need HTML::Entities for those tests"); }
      else
        { import HTML::Entities;
          $t->save_global_state;
          $t->set_output_encoding( "UTF-8");

          my $original_output_text_filter= $t->output_text_filter;
          $t->set_output_text_filter( "html");
          my $html_output_text_filter= $t->output_text_filter;
          is( $t->sprint, $doc_html, "output_text_filter html");
          $t->set_output_text_filter( $original_output_text_filter);
          is( $t->sprint, $doc_utf8, "no output_text_filter ");

          my $original_output_filter= $t->output_filter;
          $t->set_output_filter( "html");
          is( $t->sprint, $doc_escaped, "output_filter html");

          $t->restore_global_state;
          $t->set_output_encoding( "UTF-8");
          is( $t->sprint, $doc_utf8, "no output_text_filter ");
        }

      $t->restore_global_state;
      $t->set_output_encoding();

      eval "require Text::Iconv";
      if( $@) 
        { skip( 3, "need Text::Iconv for those tests"); }
      else
        { $t->set_output_filter( $t->iconv_convert( 'latin1') );
          $t->set_encoding( "ISO-8859-1");
          is( $t->encoding, "ISO-8859-1", "set_encoding"); 
          is( $t->sprint, $doc_latin1, "output_filter latin-1 (using Text::Iconv)");
          $t->restore_global_state;
          $t->set_output_encoding( "UTF-8");
          is( $t->sprint, $doc_utf8, "no output_filter ");
        }

      $t->restore_global_state;
      $t->set_output_encoding();

      eval( 'require Unicode::Map8 && require Unicode::String;');
      if( $@) 
        { skip( 3, "need Unicode::Map8 and Unicode::String for those tests" ); }
      else
        { $t->set_output_filter( $t->unicode_convert( 'latin1') );
          $t->set_encoding( "ISO-8859-1");
          is( $t->encoding, "ISO-8859-1", "set_encoding"); 
          is( $t->sprint, $doc_latin1, "output_filter latin-1 (using Unicode::*)");
          $t->restore_global_state;
          $t->set_output_encoding( "UTF-8");
          is( $t->sprint, $doc_utf8, "no output_filter ");
          $t->restore_global_state;
          $t->set_output_encoding();
        }

      $t->set_output_filter( $t->regexp2latin1 );
      $t->set_encoding( "ISO-8859-1");
      is( $t->encoding, "ISO-8859-1", "set_encoding"); 
      is( $t->sprint, $doc_latin1, "output_filter latin-1 (using regexp2latin1)");
      $t->restore_global_state;
      $t->set_output_encoding( "UTF-8");
      is( $t->sprint, $doc_utf8, "no output_filter ");
      $t->restore_global_state;
      $t->set_output_encoding();

    }
}

sub xml_escape
  { my $string= shift;
    #$string=~ s{&}{&amp;}g;
    $string=~ s{<}{&lt;}g;
    $string=~ s{>}{&gt;}g;
    $string=~ s{"}{&quot;}g; #"
    $string=~ s{'}{&apos;}g; #'
    return $string;
  }

# test SAX1 export
{ eval "require XML::Handler::YAWriter";
  if( $@)
    { skip(3, "require XML::Handler::YAWriter"); }
  else
    { import XML::Handler::YAWriter;
      my $xmldecl= qq{<?xml version="1.0" encoding="UTF-8"?>};
      my $body= qq{<doc><p att="p1">text</p></doc>};
      my $doc= $xmldecl.$body;
      my $t= XML::Twig->new->parse( $doc);
      my $writer = XML::Handler::YAWriter->new( AsString => 1);
      is( normalize_xml( $t->toSAX1( $writer)), $doc, 'toSAX1');
      $writer->start_document;
      $t->root->toSAX1( $writer);
      is( normalize_xml( $writer->end_document), $doc, 'root toSAX1');

      my $doc_flush="<doc><p>p 1</p><add/><p/><p>text<flush/> more text</p></doc>";
      my $doc_flushed=qq{<?xml version="1.0" encoding="UTF-8"?><doc><p>p 1</p><add/><g>a</g><p/><p>text<flush/> more text</p></doc>};
      $writer = XML::Handler::YAWriter->new( AsString => 1, Pretty => { CatchEmptyElement => 1 });
      $writer->start_document;

      $SIG{__WARN__} = sub {  };
      $t= XML::Twig->new( twig_handlers => 
              { add =>   sub { $_[0]->flush_toSAX1( $writer);
                               $_->new( g => "a")->toSAX1( $writer);
                             },
                flush => sub { $_[0]->flush_toSAX1( $writer); },
              }
                           )
                      ->parse( $doc_flush);
      my $output=  $t->flush_toSAX1( $writer) || '';
      $SIG{__WARN__}= $old_warning_handler;
      is( normalize_xml( $output), $doc_flushed, 'root toSAX1');

    }
}

# test SAX2 export
{ eval "require XML::SAX::Writer";
  if( $@)
    { skip(3, "XML::SAX::Writer not available"); }
  else
    { import XML::SAX::Writer;
      my $xmldecl= qq{<?xml version="1.0" encoding="UTF-8"?>};
      my $body= qq{<doc><!-- comment --><p att="p1">text</p><?target pi ?><ns xmlns:foo="uri2"><foo:e foo:att="bar">foo:e text</foo:e></ns><ns xmlns="uri2"><e att="tata">t</e></ns></doc>};
      my $doc= $xmldecl.$body;
      my $t= XML::Twig->new( comments =>'process', pi => 'process')->parse( $doc);
      my $output='';
      my $writer = XML::SAX::Writer->new( Output => \$output);
      $t->toSAX2( $writer);
      is( normalize_xml( $output), $doc, 'toSAX2');
      $output='';
      $t->root->toSAX2( $writer);
      is( normalize_xml( $output), $body, 'flush_toSAX2');

      my $doc_flush="<doc><p>p 1</p><add/><p/><p>text<flush/> more text</p></doc>";
      my $doc_flushed=qq{<doc><p>p 1</p><add/><g>a</g><p/><p>text<flush/> more text</p></doc>};
      $output='';

      $t= XML::Twig->new( twig_handlers => 
              { add =>   sub { $_[0]->flush_toSAX2( $writer);
                               $_->new( g => "a")->toSAX2( $writer);
                             },
                flush => sub { $_[0]->flush_toSAX2( $writer); },
              }
                           )
                      ->parse( $doc_flush);
      $t->flush_toSAX2( $writer);
      is( normalize_xml( $output), $doc_flushed, 'flush_toSAX2');
    }
}

sub normalize_xml
  { my $xml= shift;
    $xml=~ s{\n}{}g;
    $xml=~ s{'}{"}g; #'
    $xml=~ s{ />}{/>}g;
    return $xml;
  }

# test flushed an twig_current status (not a very good test, but the methods are not used in practice)
{ my $t= XML::Twig->new->parse( '<doc />');
  nok( $t->root->flushed, "root is not flushed");
  $t->root->set_flushed;
  ok( $t->root->flushed, "root is flushed");
  $t->root->del_flushed;
  nok( $t->root->flushed, "root is not flushed");

  nok( $t->root->{twig_current}, "root is not twig current");
  $t->root->set_twig_current;
  ok( $t->root->{twig_current}, "root is twig current");
  $t->root->del_twig_current;
  nok( $t->root->{twig_current}, "root is not twig current");

  ok( $t->root->closed, "root is closed");

}


# test ignore
{ my $t= XML::Twig->new( start_tag_handlers => { ignore         => sub { $_[0]->ignore },
                                                 ignore_parent  => sub { $_->parent->ignore },
                                               },
                       )
                  ->parse( '<doc><p>yes 1</p><ignore><p>no 1</p></ignore><p>yes 2</p><ignore/>
                            <p><p>no 2</p><ignore_parent/></p></doc>');
  is( $t->sprint, '<doc><p>yes 1</p><p>yes 2</p></doc>', "ignore");
}

# test subs_text with replacement
{ my $doc= '<doc>text rep <p>text rep</p> text rep</doc>';
  (my $rep1= $doc)=~ s/rep/newr/g;
  (my $rep2= $doc)=~ s{rep}{<b>new</b>}g;
  (my $rep3= $rep2)=~ s{ }{&nbsp;}g;
  my $t= XML::Twig->new->parse( $doc);
  $t->root->subs_text( qr/(r)ep/,  'new$1');
  is( $t->sprint, $rep1, "subs_text");
  $t->root->subs_text( qr/(new)r/,  '&elt( b => $1)');
  is( $t->sprint, $rep2, "subs_text (with elt)");
  $t->root->subs_text( qr/ /,  '&ent( "&nbsp;")');
  is( $t->sprint, $rep3, "subs_text (with ent)");
  
}

# test handlers that are not activated in 5.8

package test_handlers;
sub new { bless { } }
sub recognized_string { return 'recognized_string'; }
sub original_string { return 'original_string'; }

package main;

{ if( $perl < 5.008)  
    { skip( 4, "need perl 5.8 or above to perform these tests (you have $perl)"); }
  else
    { 
      my $out='';
      open( my $fh, ">", \$out);
      my $stdout= select $fh;
      XML::Twig::twig_print_original_default( test_handlers->new);
      select $stdout;
      close $fh;
      is( $out, 'original_string', 'twig_print_original_default');

      $out='';
      open( $fh, ">", \$out);
      select $fh;
      XML::Twig::twig_print_default( test_handlers->new);
      select $stdout;
      close $fh;
      is( $out, 'recognized_string', 'twig_print_default');

      $out='';
      open( $fh, ">", \$out);
      select $fh;
      XML::Twig::twig_print_end_original( test_handlers->new);
      select $stdout;
      close $fh;
      is( $out, 'original_string', 'twig_print_end_original');

      $out='';
      open( $fh, ">", \$out);
      select $fh;
      XML::Twig::twig_print_end( test_handlers->new);
      select $stdout;
      close $fh;
      is( $out, 'recognized_string', 'twig_print_end');
    }
  XML::Twig::twig_print_entity; # does nothing!

}
      
{ 
  my %ents= ( foo => '"toto"', pile => 'SYSTEM "file.bar" NDATA bar');
  my %ent_text = hash_ent_text( %ents);
  my $ent_text = string_ent_text( %ents); 

  my $doc= "<!DOCTYPE doc [$ent_text]><doc/>";

  my $t= XML::Twig->new->parse( $doc);
  is( normalize_xml( $t->entity_list->text), $ent_text, 'entity_list');
  my @entities= $t->entity_list->list;
  is( scalar @entities, scalar keys %ents, 'entity_list');

  if( $perl < 5.008)  
    { skip( (scalar( keys %ents) + 1), "need perl 5.8 or above to perform these tests (you have $perl)"); }
  else
    { 
      foreach my $ent (@entities)
        { my $out='';
          open( my $fh, ">", \$out);
          my $stdout= select $fh;
          $ent->print;
          close $fh;
          select $stdout;
          is( normalize_xml( $out), $ent_text{$ent->name}, "print $ent->{name}");
        }
      my $out='';
      open( my $fh, ">", \$out);
      my $stdout= select $fh;
      $t->entity_list->print;
      close $fh;
      select $stdout;
      is( normalize_xml( $out), $ent_text, 'print entity_list');

    }
           
  delete $ents{pile}; 
  %ent_text = hash_ent_text( %ents);
  $ent_text = string_ent_text( %ents);
  $t->entity_list->delete( 'pile');
  @entities= $t->entity_list->list;
  is( scalar @entities, scalar keys %ents, '1 entity deleted');
  is( $t->entity_list->text, $ent_text, 'entity_list (one entity deleted)');

}

sub hash_ent_text
  { my %ents= @_;
    return map { $_ => "<!ENTITY $_ $ents{$_}>" } keys %ents;
  }
sub string_ent_text
  { my %ents= @_;
    my %hash_ent_text= hash_ent_text( %ents);
    return join( '', map { $hash_ent_text{$_} } sort keys %hash_ent_text);
  }

{
  if( $perl < 5.008)  
    { skip( 3, "need perl 5.8 or above to perform these tests (you have $perl)"); }
  else
    { my $out1=''; open( my $fh1, ">", \$out1);
      my $out2=''; open( my $fh2, ">", \$out2);
      my $out3=''; open( my $fh3, ">", \$out3);

      my $stdout= select $fh3; 
      my $t= XML::Twig->new( twig_handlers => { e => sub { $_->print( $fh2); 
                                                           print $fh1 "X"; 
                                                           $_[0]->finish_print( $fh1);
                                                         },
                                              },
                           )
                      ->parse( '<doc>text<e>e <p>text</p></e>more text <p>foo</p></doc>');
      print 'should be in $out3';
      select $stdout;
      is( $out1, 'Xmore text <p>foo</p></doc>', 'finish_print');
      is( $out2, '<e>e <p>text</p></e>', 'print to fh');
      is( $out3, 'should be in $out3', 'restoring initial fh');
   
    }
}

# test prefix mappings

package test_sax_prefix_mapping;

sub new                  { return bless { out => 'start ' }; }
sub start_element        { my( $h, $element)= @_; $h->{out}.= "- start $element->{Name} "; }
sub end_element          { my( $h, $element)= @_; $h->{out}.= "- end $element->{Name} "; }
sub start_prefix_mapping { my( $h, $map)= @_; $h->{out}.= "- map $map->{Prefix} to $map->{NamespaceURI} "; }
sub end_prefix_mapping   { my( $h, $map)= @_; $h->{out}.= "- end map $map->{Prefix} "; }
sub end_document         { my( $h, $document)= @_; return $h->{out}; }

package main;

{ my $h= test_sax_prefix_mapping->new;
  my $t= XML::Twig->new->parse( q{<doc xmlns="uri1"><p xmlns:p1="uri2"><p1:e>text</p1:e></p>
                                  <p xmlns:p1="uri3"><p1:e>text</p1:e></p></doc>});
  my $out= $t->toSAX2( $h);
  is( $out, 'start - map  to uri1 - start doc - map p1 to uri2 - start p - start p1:e - end p1:e - end p - end map p1 - map p1 to uri3 - start p - start p1:e - end p1:e - end p - end map p1 - end doc - end map  ', 'prefix mapping');
}

# test parsing with keep_encoding (to check no spurious warnings are produced)
{ my $warnings='';
  $SIG{__WARN__}= sub { $warnings .= shift; };
  my $doc= '<doc><p att1="v1" att2="v2">text</p><p>more text &gt; &#xe9; </p></doc>';
  my $t= XML::Twig->new( keep_encoding => 1)->parse( $doc);
  $SIG{__WARN__}= $old_warning_handler;
  is( $warnings, '', 'keep_encoding with elements with no attributes');
  is( $t->sprint, $doc, 'twig output');
}

# test end_tag_handlers with ignore
{
my $out='';
my $t= XML::Twig->new( twig_roots         => { p => 1 },
                       start_tag_handlers => { x => sub { $out .= "s" } },
                       twig_handlers      => { n => sub { $out .="n";},
                                               x => sub { $out .="e"; }
                                             },
                     )
                ->parse( '<doc><p>text <x>text <n/> </x> more <x/> text</p><n/></doc>');
is( $out, 'snese', 'end_tag_handlers without ignore');

$out='';
$t= XML::Twig->new( twig_roots         => { p => 1 },
                       start_tag_handlers => { x => sub { $out .= "s"; $_->ignore } },
                       end_tag_handlers   => { x => sub { $out .="e"; },            },
                       twig_handlers      => { n => sub { $out .="n"; },            },
                     )
                ->parse( '<doc><p>text <x>text <n/> </x> more <x/> text</p><n/></doc>');
is( $out, 'sese', 'end_tag_handlers with ignore');

eval ' XML::Twig->new( start_tag_handlers => { x => sub { $out .= "s"; $_->ignore } },
                       end_tag_handlers   => { x => sub { $out .="e"; },            },
                       twig_handlers      => { n => sub { $out .="n"; },            },
                     );
     ';
matches( $@, '^you should not use EndTagHandlers without', "error using end_tag_handlers");

$out='';
$t= XML::Twig->new(    force_end_tag_handlers_usage => 1,
                       start_tag_handlers => { x => sub { $out .= "s"; $_->ignore } },
                       end_tag_handlers   => { x => sub { $out .="e"; },            },
                       twig_handlers      => { n => sub { $out .="n"; },            },
                     )
                ->parse( '<doc><p>text <x>text <n/> </x> more <x/> text</p><n/></doc>');
is( $out, 'sesen', 'end_tag_handlers with ignore and force_end_tag_handlers_usage');

}


{
my $warning="";
$SIG{__WARN__} = sub { $warning .= join '', @_ };
my $t= XML::Twig->new( dummy_opt2 => 1);
$SIG{__WARN__}= $old_warning_handler; 
matches( $warning, '^invalid option', "warning for extra option");
}


# test various handlers
{ my %got;
  my $doc= '<doc id="doc1"><e id="e1"/><no id="no1"/>
                           <a id="a1" a1="v11" a2="v12"/><a id="a2" a1="v21" a2="v22"/>
                           <b id="b1" a1="v11" a2="v12"/><b id="b2" a1="v21" a2="v22"/>
                           <t id="t1">foobar</t><t id="t2">foo</t><t id="t3">no</t>
            </doc>';
  my @handler_exp= ( 'e', 'doc/e', '/doc/e', 'a[@a1]', 'a[@a2]', 'a[@a1="v11"]',
                     'a[@a1="v21"]', '*[@a1]', '*[@a1="v11"]', '*[@a1="v21"]', '*[@a1=~/^v21$/]',
                     't[string()="foobar"]', 't[string()=~ /^foo/]', 't[string()=~ /bar$/]',
                     '_default_',
                   );
  my %handlers;
  foreach my $exp (@handler_exp)
    { my $code= "\$got{\$_->id}||=[]; push \@{\$got{\$_->id}}, '$exp'; 1";
      my $sub= eval "sub { $code }";
      die "oops, error in test, code is '$code'" if( $@);
      $handlers{$exp}= $sub;
    }
  my $t= XML::Twig->new( twig_handlers => \%handlers)->parse( $doc);
  my %expected= ( e1   => [ '/doc/e', 'doc/e', 'e' ],
                  no1  => [ '_default_'],
                  a1   => [ '*[@a1]', '*[@a1="v11"]', 'a[@a1]', 'a[@a2]', 'a[@a1="v11"]' ],
                  a2   => [ '*[@a1]', '*[@a1="v21"]', 'a[@a1]', 'a[@a2]', 'a[@a1="v21"]', '*[@a1=~/^v21$/]' ],
                  b1   => [ '*[@a1]', '*[@a1="v11"]' ],
                  b2   => [ '*[@a1="v21"]', '*[@a1]', '*[@a1=~/^v21$/]'],
                  t1   => [ 't[string()="foobar"]', 't[string()=~ /^foo/]', 't[string()=~ /bar$/]' ],
                  t2   => [ 't[string()=~ /^foo/]' ],
                  t3   => [ '_default_'],
                  doc1 => [ '_default_'],
                );
  foreach my $elt (sort keys %expected)
    { my $expected= join( ' - ', sort @{$expected{$elt}});
      my $got= $got{$elt} ? join( ' - ', sort @{$got{$elt}}) : '';
      is( $got, $expected, "handlers on $elt");
    }

  my %handlers2;
  my %got2;
  foreach my $exp (@handler_exp)
    { my $code= "\$got2{\$_->id}||=[]; push \@{\$got2{\$_->id}}, '$exp:2'; 1";
      my $sub= eval "sub { $code }";
      die "oops, error in test, code is '$code'" if( $@);
      $t->setTwigHandler( $exp, $sub);
    }
  $t->parse( $doc);
  foreach my $elt (sort keys %expected)
    { my $expected= join( ' - ', map { "$_:2" } sort @{$expected{$elt}});
      my $got= $got2{$elt} ? join( ' - ', sort @{$got2{$elt}}) : '';
      is( $got, $expected, "handlers on $elt (2)");
    }
  
}

{ my $t= XML::Twig->new->parse( '<doc><elt1/><elt2/><elt3/></doc>');
  $t->change_gi( elt1 => 'elt2');
  $t->change_gi( elt3 => 'elt4');
  is( $t->sprint, '<doc><elt2/><elt2/><elt4/></doc>', 'change_gi');
}

# these do not pass (yet?)
#{ my $doc= '<doc><p>text</p><i>&lt;ignored&gt;</i><p>more text</p></doc>';
#  my $t= XML::Twig->new( start_tag_handlers => { i => sub { $_->ignore( 'string') }})
#                  ->parse( $doc);
#  is( $t->sprint, '<doc><p>text</p><p>more text</p></doc>', 'ignore');
#  is( $t->buffered_string, '<i><ignored></i>', 'ignore');
#  $t->set_keep_encoding( 1);
#  $t->parse( $doc);
#  is( $t->sprint, '<doc><p>text</p><p>more text</p></doc>', 'ignore');
#  is( $t->buffered_string, '<i>&lt;ignored&gt;</i>', 'ignore');
#}

{ my $t= XML::Twig->new->parse( '<doc xmlns:ns1="uri2"><p xmlns="uri" ns1:att="foo"/></doc>');
  my $p= $t->first_elt( '*[@ns1:att=~/^f/]');
  is( $p->get_namespace, 'uri', 'get_namespace on elt');
  is( $p->get_namespace( 'ns1'), 'uri2', 'get_namespace with arg');
  is( $p->get_namespace( 'xmlns'), 'http://www.w3.org/2000/xmlns/', 'get_namespace for xmlns');
  is( $t->root->get_namespace(), '', 'default get_namespace');
  is( $t->root->get_namespace( '#default'), '', 'get_namespace with arg #default');
  is( $t->root->get_namespace( 'xml'), 'http://www.w3.org/XML/1998/namespace', 'get_namespace for xml');
}

{ my $t= XML::Twig->new->parse( '<doc><e id="e1"/><f id="f1" att="foo"/><e id="e2" att="foo"/><e id="e3"/><t id="t1">text</t></doc>');
  is( $t->root->first_child( 'e[@att="foo"]')->id, 'e2', 'cond on att value');
  is( $t->root->first_child( '*[@att="foo"]')->id, 'f1', 'cond on att value (with wc)');
  is( $t->root->first_child( '*[@att="foo" and @id="e2"]')->id, 'e2', 'and cond on att value');
  is( $t->root->first_child( '*[@att="foo" or @id="e2"]')->id, 'f1', 'and cond on att value');
  is(  $t->root->first_child( 't[string()="text"]')->id, 't1', 'string cond');
  is(  $t->root->first_child( '*[string()="text"]')->id, 't1', 'string cond wc');
  is(  $t->root->first_child( 't[string()=~/^t/]')->id, 't1', 'regexp cond');
  is(  $t->root->first_child( '*[string()=~/^t/]')->id, 't1', 'regexp cond wc');
  is(  $t->root->first_child( qr/^t/)->id, 't1', 'regexp cond wc');

  my $sprint= $t->root->first_child( 't')->sprint;
  $t->root->first_child( 't')->change_att_name( 'foo');

  is( $t->root->first_child( 't')->sprint, $sprint, 'change_att_name on non existent att');
  my $ids= join ':', sort keys %{$t->{twig_id_list}};
  my $elt= XML::Twig::Elt->new( 'e');
  is( $elt->sprint, '<e/>', 'new elt');
  $elt->del_id;
  is( $elt->sprint, '<e/>', 'del_id, no id');
  $elt->set_id( 'new_e');
  is( $elt->sprint, '<e id="new_e"/>', 'set_id');
  my( $new_ids)= join ':', sort keys %{$t->{twig_id_list}};
  is( $new_ids, $ids, 'set_id on elt not in the tree');
  $elt->del_id;
  is( $elt->sprint, '<e/>', 'del_id, no id');

  nok( $t->first_elt( 'e')->next_elt(  $t->first_elt( 'e')), 'next_elt on empty subtree');
  nok( $t->first_elt( 'e')->next_elt($t->first_elt( 'e'), 'e'), 'next_elt on empty subtree');

  is( $t->root->get_xpath( './e[1]', 0)->id, 'e1', 'get_xpath with ./');
  is( $t->root->first_child->get_xpath( '/doc/e[1]', 0)->id, 'e1', 'get_xpath with /');
  is( $t->root->first_child->get_xpath( '/doc/e[-1]', 0)->id, 'e3', 'get_xpath with /');
  is( $t->root->first_child->get_xpath( './../e[2]', 0)->id, 'e2', 'get_xpath with ..');
  is( $t->root->first_child->get_xpath( './../*[2]', 0)->id, 'f1', 'get_xpath with ../*[2]');
  is( $t->root->first_child->get_xpath( './../*', 0)->id, 'e1', 'get_xpath with ../*');

}

{ my $t= XML::Twig->new->parse( '<doc><e/><e/></doc>');
  is( $t->root->cmp( $t->root), 0, 'cmp root with itself');
  my $ne= $t->root->new( 'ne');
  is( $ne->cmp( $ne), 0, 'cmp with itself');
  is_undef( $t->root->cmp( $ne), 'cmp elt in different trees');
  my $t_sprint= $t->sprint;
  $t->root->field_to_att( 'foo');
  is( $t->sprint, $t_sprint, 'field_to_att on wrong field');
  my $ne_sprint= $ne->sprint;
  $ne->field_to_att( 'foo');
  is( $ne->sprint, $ne->sprint, 'field_to_att on wrong field (no child)');

  $ne->prefix( '<p1>p 1</p1>pr', 'asis');
  is(  $ne->sprint, '<ne><p1>p 1</p1>pr</ne>', 'prefix asis');
  $ne->prefix( '<p2>p 2</p2>', 'asis');
  is(  $ne->sprint, '<ne><p2>p 2</p2><p1>p 1</p1>pr</ne>', 'prefix asis');
  $ne->suffix( '<s1>s 1</s1>su', 'asis');
  is(  $ne->sprint, '<ne><p2>p 2</p2><p1>p 1</p1>pr<s1>s 1</s1>su</ne>', 'prefix asis');
  $ne->suffix( '<s2>s 2</s2>', 'asis');
  is(  $ne->sprint, '<ne><p2>p 2</p2><p1>p 1</p1>pr<s1>s 1</s1>su<s2>s 2</s2></ne>', 'prefix asis');
}

{ my $t=  XML::Twig->new( twig_handlers => { w => sub { $_->wrap_in( 'ww'); } })
                   ->parse( '<doc><p/><w>text <i/></w><p/></doc>');
  is( $t->sprint, '<doc><p/><ww><w>text <i/></w></ww><p/></doc>', 'wrap current elt');
  $t->root->wrap_in( 'd');
  is( $t->sprint, '<d><doc><p/><ww><w>text <i/></w></ww><p/></doc></d>', 'wrap root');
}

ok(1, "ok");

############################################################################
# tools                                                                    #
  
############################################################################

{ my $test_nb;
  sub is
    { my $got     = shift; my $expected= shift; my $message = shift;
      $test_nb++; 

      if( $expected eq $got) 
        { print "ok $test_nb\n";
          warn "$message" if( $DEBUG); 
        }
      else 
        { print "not ok $test_nb\n"; 
          if( length( $expected) > 20)
            { warn "$message:\nexpected: '$expected'\ngot     : '$got'\n"; }
          else
            { warn "$message: expected '$expected', got '$got'\n"; }
        }
    }

  sub matches
    { my $got     = shift; my $expected_regexp= shift; my $message = shift;
      $test_nb++; 

      if( $got=~ /$expected_regexp/) { print "ok $test_nb\n"; }
      else { print "not ok $test_nb\n"; 
             warn "$message: expected to match /$expected_regexp/, got '$got'\n";
           }
    }

  sub ok
    { my $cond   = shift; my $message=shift;
      $test_nb++; 

      if( $cond) { print "ok $test_nb\n"; }
      else { print "not ok $test_nb\n"; warn "$message: false\n"; }
    }

  sub nok
    { my $cond   = shift; my $message=shift;
      $test_nb++; 

      if( !$cond) { print "ok $test_nb\n"; }
      else { print "not ok $test_nb\n"; warn "$message: true (should be false): '$cond'\n"; }
    }

  sub is_undef
    { my $cond   = shift; my $message=shift;
      $test_nb++; 

      if( ! defined( $cond)) { print "ok $test_nb\n"; }
      else { print "not ok $test_nb\n"; warn "$message is defined: '$cond'\n"; }
    }


my %seen_message;
  sub skip
    { my( $nb_skip, $message)= @_;
      unless( $seen_message{$message})
        { warn "$message: skipping $nb_skip tests\n";
          $seen_message{$message}++;
        }
      for my $test ( ($test_nb + 1) .. ($test_nb + $nb_skip))
        { print "ok $test\n"; }
      $test_nb= $test_nb + $nb_skip;
    }
}


sub tags { return join ':', map { $_->gi } @_ }
