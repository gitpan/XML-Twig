#!/usr/bin/perl -w
use strict;

# $Id: test_bugs_3.15.t,v 1.4 2004/08/30 18:24:28 mrodrigu Exp $

use strict;
use Carp;

#$|=1;
my $DEBUG=0;

use XML::Twig;

my $TMAX=17;
print "1..$TMAX\n";

{ # test bug outputing end tag with pretty_print => nsgmls on
  my $out= XML::Twig->new( pretty_print => 'nsgmls')->parse( "<doc><elt>text</elt></doc>")->sprint;
  ok( XML::Twig->new( error_context => 1)->safe_parse( $out), "end tag with nsgmls option" . ($@ || '') );
}
  

{ # test bug RT #8830: simplify dies on mixed content
  ok( XML::Twig->new->parse( "<doc>text1<elt/></doc>")->root->simplify, "simplify mixed content");
}


{ # testing to see if bug RT #7523 is still around
  my $t= XML::Twig->new->parse( '<doc/>');
  $t->set_output_encoding( 'utf8');
  $t->sprint;
  ok(1);
}

{ # bug on comments
  my $doc= "<doc>\n  <!-- comment -->\n  <elt>foo</elt>\n</doc>\n";

  my $t= XML::Twig->new( comments => 'keep', pretty_print => 'indented')
                  ->parse( $doc);
  is( $t->sprint => $doc, "comment with comments => 'keep'");
}

{ # bug with disapearing entities in attributes
  my $text= '<doc att="M&uuml;nchen"><elt att="&ent2;"/><elt att="A&amp;E">&ent3;</elt></doc>';
  my $doc= qq{<!DOCTYPE doc SYSTEM "test_ent_in_att.dtd"[<!ENTITY foo "toto">]>$text};

  XML::Twig::Elt::init_global_state();
  my $regular=XML::Twig->new( pretty_print => 'none')->parse( $doc)->root->sprint;
  (my $expected= $text)=~ s{&(uuml|ent2);}{}g;
  is( $regular => $expected, "entities in atts, no option");

  XML::Twig::Elt::init_global_state();
  my $with_keep=XML::Twig->new(keep_encoding => 1)->parse( $doc)->root->sprint;
  is( $with_keep => $text, "entities in atts with keep_encoding");

  XML::Twig::Elt::init_global_state();
  my $with_dneaia=XML::Twig->new(do_not_escape_amp_in_atts => 1)->parse( $doc)->root->sprint;
  is( $with_dneaia => $text, "entities in atts with do_not_escape_amp_in_atts");

  # checking that all goes back to normal
  XML::Twig::Elt::init_global_state();
  $regular=XML::Twig->new()->parse( $doc)->root->sprint;
  is( $regular => $expected, "entities in atts, no option");

}

# bug on xmlns in path expression trigger
{ my $matched=0;
  my $twig = XML::Twig->new( map_xmlns => { uri1  => 'aaa', },
                             twig_handlers => { '/aaa:doc/aaa:elt' => sub { $matched=1; } }
                           )
                      ->parse( q{<xxx:doc xmlns:xxx="uri1"><xxx:elt/></xxx:doc>});
  ok( $matched, "using name spaces in path expression trigger");
  $matched=0;
  $twig = XML::Twig->new( map_xmlns => { uri1  => 'aaa', },
                          twig_handlers => { 'aaa:doc/aaa:elt' => sub { $matched=1; } }
                        )
                      ->parse( q{<xxx:doc xmlns:xxx="uri1"><xxx:elt/></xxx:doc>});
  ok( $matched, "using name spaces in partial path expression trigger");
}

# bug where the leading spaces are discarded in an element like <p>  <b>foo</b>bar</p>
{ # check that leading spaces after a \n are discarded
  my $doc= "<p>\n  <b>foo</b>\n</p>";
  my $expected= "<p><b>foo</b></p>";
  my $result=  XML::Twig->new->parse( $doc)->sprint;
  is( $result => $expected, 'leading spaces kept when not after a \n');
}
{
  # check that leading spaces NOT after a \n are kept around
  my $doc= "<p>  <b>foo</b>bar</p>";
  my $result=  XML::Twig->new->parse( $doc)->sprint;
  is( $result => $doc, 'leading spaces kept when not after a \n');
}

{
my $t= XML::Twig->new->parse( "<doc><elt>  elt  1 </elt> <elt>  elt   2 </elt></doc>");
is( scalar $t->descendants( '#PCDATA'), 3, 'properly parsed pcdata');
}

{
my $t= XML::Twig->new->parse( "<doc>\n  <elt>  elt  1 </elt>\n  <elt>  elt   2 </elt>\n</doc>");
is( scalar $t->descendants( '#PCDATA'), 2, 'properly parsed pcdata');
}

{ # bug RT 8137
  my $doc= q{<doc  att="val"/>};
  (my $expected= $doc)=~ s{  }{ };
  is( XML::Twig->new( keep_encoding => 1)->parse( $doc)->sprint, $expected, 
      'keep_encoding and 2 spaces between gi and attribute'
    );
}

{ # copy of an element with extra_data_before_end_tag
  my $doc= '<doc>data<?pi here?>more</doc>';
  my $expected= '<doc>data<?pi here?>more</doc>'; # pi's are not being moved around anymore
  my $elt= XML::Twig->new( pi => 'keep')->parse( $doc)->root->copy;
  is( $elt->sprint, $expected, 'copy of an element with extra_data_before_end_tag');
}

{ # copy of an element with extra_data_before_end_tag
  my $doc= '<doc><?pi here?></doc>';
  my $elt= XML::Twig->new( pi => 'keep')->parse( $doc)->root->copy;
  is( $elt->sprint, $doc, 'copy of an element with extra_data_before_end_tag');
}

############################################################################
# tools                                                                    #
############################################################################

{ my $test_nb;
  sub is
    { my( $got, $expected, $message) = @_;
      $test_nb++; 

      if( $expected eq $got) 
        { print "ok $test_nb\n";
          warn "ok $test_nb $message\n" if( $DEBUG); 
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

      if( $got=~ /$expected_regexp/) 
        { print "ok $test_nb\n"; 
          warn "ok $test_nb $message\n" if( $DEBUG); 
        }
      else { print "not ok $test_nb\n"; 
             warn "$message: expected to match /$expected_regexp/, got '$got'\n";
           }
    }

  sub ok
    { my $cond   = shift; my $message=shift;
      $test_nb++; 

      if( $cond)
        { print "ok $test_nb\n"; 
          warn "ok $test_nb $message\n" if( $DEBUG); 
        }
      else { print "not ok $test_nb\n"; warn "$message: false\n"; }
    }

  sub nok
    { my $cond   = shift; my $message=shift;
      $test_nb++; 

      if( !$cond)
        { print "ok $test_nb\n"; 
          warn "ok $test_nb $message\n" if( $DEBUG); 
        }
      else { print "not ok $test_nb\n"; warn "$message: true (should be false): '$cond'\n"; }
    }

  sub is_undef
    { my $cond   = shift; my $message=shift;
      $test_nb++; 

      if( ! defined( $cond)) 
        { print "ok $test_nb\n"; 
          warn "ok $test_nb $message\n" if( $DEBUG); 
        }
      else { print "not ok $test_nb\n"; warn "$message is defined: '$cond'\n"; }
    }


my %seen_message;
  sub skip
    { my( $nb_skip, $message)= @_;
      $message ||='';
      unless( $seen_message{$message})
        { warn "$message: skipping $nb_skip tests\n";
          $seen_message{$message}++;
        }
      for my $test ( ($test_nb + 1) .. ($test_nb + $nb_skip))
        { print "ok $test\n";
          warn "skipping $test ($message)\n" if( $DEBUG); 
        }
      $test_nb= $test_nb + $nb_skip;
    }
}

sub tags { return join ':', map { $_->gi } @_ }
sub ids  { return join ':', map { $_->att( 'id') || '<' . $_->gi . ':no_id>' } @_ }
