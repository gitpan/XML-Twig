#!/bin/perl -w

# $Id$

# tests that require IO::Scalar to run
use strict;
use Carp;

#$|=1;
my $DEBUG=0;

use XML::Twig;

BEGIN 
  { eval "require IO::Scalar";
    if( $@) 
      { print "1..1\nok 1\n"; 
        warn "skipping, need IO::Scalar\n";
        exit;
      } 
    else
      { import IO::Scalar; }
  }

print "1..27\n";

{ my $out=''; my $out2='';
  my $fh= new IO::Scalar \$out;
  my $fh2= new IO::Scalar \$out;
  my $t= XML::Twig->new( empty_tags => 'expand', pretty_print => 'none')->parse( '<doc><elt/></doc>');
  $t->print( $fh);
  is( $out, "<doc><elt></elt></doc>", "empty_tags expand");  # test 287
  $t->print( $fh2);
  is( $t->sprint( empty_tags => 'normal'), "<doc><elt/></doc>", "empty_tags normal");  # test 288
  $out=''; $t->print( $fh);
  is( $t->sprint( pretty_print => 'indented', empty_tags => 'normal'), "<doc>\n  <elt/>\n</doc>\n", "empty_tags expand");  # test 289
  $t->set_pretty_print( 'none');
  $t->set_empty_tag_style( 'normal');
}

{ my $out=''; my $out2='';
  my $fh= new IO::Scalar \$out;
  my $fh2= new IO::Scalar \$out;
  my $t= XML::Twig->new( empty_tags => 'expand', pretty_print => 'none');
  $t->parse( '<doc><elt/></doc>')->flush( $fh);
  is( $out, "<doc><elt></elt></doc>", "empty_tags expand");  # test 290
  $t->parse( '<doc><elt/></doc>')->flush( $fh2);
  is( $t->sprint( empty_tags => 'normal'), "<doc><elt/></doc>", "empty_tags normal");  # test 291
  $out=''; $t->parse( '<doc><elt/></doc>')->flush( $fh);
  is( $t->sprint( pretty_print => 'indented', empty_tags => 'normal'), "<doc>\n  <elt/>\n</doc>\n", "empty_tags expand");  # test 292
  $t->set_pretty_print( 'none');
  $t->set_empty_tag_style( 'normal');
}

{ my $out='';
  my $fh= new IO::Scalar \$out;
  my $doc= q{<doc><sect><p>p1</p><p>p2</p><flush/></sect></doc>};
  my $t= XML::Twig->new( twig_handlers => { flush => sub { $_->flush( $fh) } } )
                  ->parse( $doc);
  is( $out, q{<doc><sect><p>p1</p><p>p2</p><flush/>}, "flush");  # test 314
  close $fh;

  $out="";
  $fh= new IO::Scalar \$out;
  $t= XML::Twig->new( twig_handlers => { flush => sub { $_[0]->flush_up_to( $_->prev_sibling, $fh) } } )
                  ->parse( $doc);
  is( $out, q{<doc><sect><p>p1</p><p>p2</p>}, "flush_up_to");  # test 315

  $t= XML::Twig->new( twig_handlers => { purge => sub { $_[0]->purge_up_to( $_->prev_sibling->prev_sibling, $fh) } } )
                  ->parse( q{<doc><sect2/><sect><p>p1</p><p><sp>sp 1</sp></p><purge/></sect></doc>});
  is( $t->sprint, q{<doc><sect><p><sp>sp 1</sp></p><purge/></sect></doc>}, "purge_up_to");  # test 316
}

{ my $out='';
  my $fh= new IO::Scalar \$out;
  my $t= XML::Twig->new()->parse( q{<!DOCTYPE doc [<!ELEMENT doc (#PCDATA)*>]><doc>toto</doc>});
  $t->dtd_print( $fh);
  is( $out, "<!DOCTYPE doc [\n<!ELEMENT doc (#PCDATA)*>\n\n]>\n", "dtd_print");  # test 322
  close $fh;
}

{ my $out="";
  my $fh= new IO::Scalar \$out;
  my $t= XML::Twig->new( twig_handlers => { stop => sub { print $fh "[X]"; $_->set_text( '[Y]'); $_[0]->flush( $fh); $_[0]->finish_print( $fh); } })
            ->parse( q{<doc>before<stop/>finish</doc>});
        select STDOUT;
  is( $out, q{[X]<doc>before<stop>[Y]</stop>finish</doc>}, "finish_print");  # test 323
}


package test_handlers;
sub new { bless { } }
sub recognized_string { return 'recognized_string'; }
sub original_string { return 'original_string'; }
package main;


{ 
  my $out='';
  my $fh= new IO::Scalar \$out;
  my $stdout= select $fh;
  XML::Twig::_twig_print_original_default( test_handlers->new);
  select $stdout;
  close $fh;
  is( $out, 'original_string', 'twig_print_original_default');  # test 371

  $out='';
  $fh= new IO::Scalar \$out;
  select $fh;
  XML::Twig::_twig_print( test_handlers->new);
  select $stdout;
  close $fh;
  is( $out, 'recognized_string', 'twig_print_default');  # test 372

  $out='';
  $fh= new IO::Scalar \$out;
  select $fh;
  XML::Twig::_twig_print_end_original( test_handlers->new);
  select $stdout;
  close $fh;
  is( $out, 'original_string', 'twig_print_end_original');  # test 373

  $out='';
  $fh= new IO::Scalar \$out;
  select $fh;
  XML::Twig::_twig_print( test_handlers->new);
  select $stdout;
  close $fh;
  is( $out, 'recognized_string', 'twig_print_end');  # test 374
}

XML::Twig::_twig_print_entity; # does nothing!

{ 
  my %ents= ( foo => '"toto"', pile => 'SYSTEM "file.bar" NDATA bar');
  my %ent_text = hash_ent_text( %ents);
  my $ent_text = string_ent_text( %ents); 

  my $doc= "<!DOCTYPE doc [$ent_text]><doc/>";

  my $t= XML::Twig->new->parse( $doc);
  is( normalize_xml( $t->entity_list->text), $ent_text, 'entity_list');  # test 375
  my @entities= $t->entity_list->list;
  is( scalar @entities, scalar keys %ents, 'entity_list');  # test 376

      foreach my $ent (@entities)
        { my $out='';
          my $fh= new IO::Scalar \$out;
          my $stdout= select $fh;
          $ent->print;
          close $fh;
          select $stdout;
          is( normalize_xml( $out), $ent_text{$ent->name}, "print $ent->{name}");  # test 377
        }
      my $out='';
      my $fh= new IO::Scalar \$out;
      my $stdout= select $fh;
      $t->entity_list->print;
      close $fh;
      select $stdout;
      is( normalize_xml( $out), $ent_text, 'print entity_list');  # test 378

}

{ my( $out1, $out2, $out3);
  my $fh1= new IO::Scalar \$out1;
  my $fh2= new IO::Scalar \$out2;
  my $fh3= new IO::Scalar \$out3;

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
  is( $out1, 'Xmore text <p>foo</p></doc>', 'finish_print');  # test 381
  is( $out2, '<e>e <p>text</p></e>', 'print to fh');  # test 382
  is( $out3, 'should be in $out3', 'restoring initial fh');  # test 383

}


{ my $doc= '<doc><![CDATA[toto]]>tata<!-- comment -->t<?pi data?> more</doc>';
  my $out;
  my $fh= new IO::Scalar \$out;
  my $t= XML::Twig->new( comments => 'process', pi => 'process')->parse( $doc);
  $t->flush( $fh);
  is( $out, $doc, 'flush with cdata');
}

{ my $out=''; 

  my $fh= new IO::Scalar \$out;
  my $doc='<doc><elt>text</elt><elt1/><elt2/><elt3>text</elt3></doc>';
  my $t= XML::Twig->new( twig_roots=> { elt2 => 1 },
                          start_tag_handlers => { elt  => sub { print $fh '<e1/>'; } },  
                          end_tag_handlers   => { elt3 => sub { print $fh '<e2/>'; } },  
                          twig_print_outside_roots => $fh,
                          keep_encoding => 1
                        )
                   ->parse( $doc);
  is( $out, '<doc><e1/><elt>text</elt><elt1/><elt3>text<e2/></elt3></doc>', 
            'twig_print_outside_roots, start/end_tag_handlers, keep_encoding');
  close $fh;
  $out='';
  $fh= new IO::Scalar \$out;
  $t= XML::Twig->new( twig_roots=> { elt2 => 1 },
                      start_tag_handlers => { elt  => sub { print $fh '<e1/>'; } },  
                      end_tag_handlers   => { elt3 => sub { print $fh '<e2/>'; } },  
                      twig_print_outside_roots => $fh,
                    )
               ->parse( $doc);
  is( $out, '<doc><e1/><elt>text</elt><elt1/><elt3>text<e2/></elt3></doc>', 
         'twig_print_outside_roots and start_tag_handlers');
}

{ my $t= XML::Twig->new->parse( '<doc/>');
  eval( '$t->set_output_encoding( "ISO-8859-1");');
  if( $@) 
    { skip( 1 => "your system does not seem to support conversions to ISO-8859-1: $@\n"); }
  else
    { is( $t->sprint, qq{<?xml version="1.0" encoding="ISO-8859-1"?><doc/>}, 
          'creating an output encoding'
        );
    }
}

exit 0;

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


sub xml_escape
  { my $string= shift;
    #$string=~ s{&}{&amp;}g;
    $string=~ s{<}{&lt;}g;
    $string=~ s{>}{&gt;}g;
    $string=~ s{"}{&quot;}g; #"
    $string=~ s{'}{&apos;}g; #'
    return $string;
  }

sub normalize_xml
  { my $xml= shift;
    $xml=~ s{\n}{}g;
    $xml=~ s{'}{"}g; #'
    $xml=~ s{ />}{/>}g;
    return $xml;
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
