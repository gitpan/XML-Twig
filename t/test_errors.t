#!/bin/perl -w

# test error conditions

use strict;
use Carp;

use FindBin qw($Bin);
BEGIN { unshift @INC, $Bin; }
use tools;

#$|=1;

use XML::Twig;

my $TMAX=99; 
print "1..$TMAX\n";

my $error_file= "t/test_errors.errors";

{ # test insufficient version of XML::Parser (not that easy, it is already too late here)
my $need_version= 2.23;

my $q= $^O eq "MSWin32" ? '"' : "'";

my $version= $need_version - 0.01;
unlink $error_file if -f $error_file;
system( qq{$^X -e$q use XML::Parser; BEGIN { \$XML::Parser::VERSION=$version}; use XML::Twig$q 2> $error_file});
ok( -f $error_file, "error generated for low version of XML::Parser");
matches( slurp( $error_file), "^need at least XML::Parser version 2\.23", "error message for low version of XML::Parser");

$version= $need_version;
unlink $error_file if -f $error_file;
system( qq{$^X -e$q use XML::Parser; BEGIN { \$XML::Parser::VERSION=$version}; use XML::Twig$q 2> $error_file});
ok( ! -f $error_file || ! slurp( $error_file), "no error generated for proper version of XML::Parser");

$version= $need_version + 0.01;
unlink $error_file if -f $error_file;
system( qq{$^X -e$q use XML::Parser; BEGIN { \$XML::Parser::VERSION=$version}; use XML::Twig$q 2> $error_file});
ok( ! -f $error_file || ! slurp( $error_file), "no error generated for high version of XML::Parser");

unlink $error_file if -f $error_file;

}

my $warning;
my $init_warn= $SIG{__WARN__};

{ $SIG{__WARN__}= sub { $warning= join '', @_; };
  XML::Twig->new( dummy => 1);
  $SIG{__WARN__}= $init_warn;
  matches( $warning, "^invalid option Dummy", "invalid option");
}

{ eval { XML::Twig::_slurp( $error_file) };
  matches( $@, "^cannot open '\Q$error_file\E'", "_slurp inexisting file");
}

{ eval {XML::Twig->new->parse( '<doc/>')->root->first_child( 'du,')};
  matches( $@, "^wrong condition", "invalid navigation expression");
}

{ eval {XML::Twig->new->parse( '<doc/>')->root->first_child( '@val=~/[/')};
  matches( $@, "^wrong navigation condition", "invalid navigation expression");
}



{ eval {XML::Twig->new( twig_print_outside_roots => 1)};
  matches( $@, "^cannot use TwigPrintOutsideRoots without TwigRoots", "invalid option");
}

{ eval {XML::Twig->new( keep_spaces => 1, discard_spaces => 1 )};
  matches( $@, "^cannot use both keep_spaces and discard_spaces", "invalid option combination 1");
  eval {XML::Twig->new( keep_spaces => 1, keep_spaces_in => ['p'])};
  matches( $@, "^cannot use both keep_spaces and keep_spaces_in", "invalid option combination 2");
  eval {XML::Twig->new( discard_spaces => 1, keep_spaces_in => ['p'])};
  matches( $@, "^cannot use both discard_spaces and keep_spaces_in", "invalid option combination 3");
  eval {XML::Twig->new( keep_spaces_in => [ 'doc' ], discard_spaces_in => ['p'])};
  matches( $@, "^cannot use both keep_spaces_in and discard_spaces_in", "invalid option combination 4");
  eval {XML::Twig->new( comments => 'wrong') };
  matches( $@, "^wrong value for comments argument: 'wrong'", "invalid option value for comment");
  eval {XML::Twig->new( pi => 'wrong') };
  matches( $@, "^wrong value for pi argument: 'wrong'", "invalid option value for pi");
}

{ my $t=XML::Twig->new->parse( '<doc><p> p1</p><p>p 2</p></doc>');
  my $elt= $t->root;
  eval { $elt->sort_children( sub  { }, type => 'wrong'); };
  matches( $@, "^wrong sort type 'wrong', should be either 'alpha' or 'numeric'", "sort type");
}
{
  foreach my $wrong_path ( 'wrong path', 'wrong#path', '1', '1tag', '///tag', 'tag/')
    { eval {XML::Twig->new( twig_handlers => { $wrong_path => sub {}});};
      matches( $@, "^unrecognized expression in handler: '$wrong_path'", "wrong handler ($wrong_path)");
    }

  eval {XML::Twig->new( input_filter => 'dummy')};
  matches( $@, "^invalid input filter:", "input filter");
  eval {XML::Twig->new( input_filter => {})};
  matches( $@, "^invalid input filter:", "input filter");
}

{ foreach my $bad_tag ( 'toto', '<1toto', '<foo:bar:baz', '< foo::bar', '<_toto', '<-toto', '<totoatt=', '<#toto', '<toto')
    { eval {XML::Twig::_parse_start_tag( qq{$bad_tag})};
      matches( $@, "^error parsing tag '$bad_tag'", "bad tag '$bad_tag'");
      eval {XML::Twig::Elt::_match_expr( qq{$bad_tag})};
      matches( $@, "^error parsing tag '$bad_tag'", "bad tag '$bad_tag'");
    }
}

{ my $t= XML::Twig->new( twig_handlers => { sax => sub { $_[0]->toSAX1 } });
  eval {$t->parse( '<doc><sax/></doc>')};
  matches( $@, "^cannot use toSAX1 while parsing", "toSAX1 during parsing");
}

{ my $t= XML::Twig->new( twig_handlers => { sax => sub { $_[0]->toSAX2 } });
  eval {$t->parse( '<doc><sax/></doc>')};
  matches( $@, "^cannot use toSAX2 while parsing", "toSAX2 during parsing");
}

{ my $t= XML::Twig->new->parse( '<doc/>');
  foreach my $bad_cond ( 'foo bar', 'foo:bar:baz', '.', '..', '...', '**', 'con[@to:ta:ti]')
    { eval { $t->root->first_child( qq{$bad_cond})};
      matches( $@, "^wrong condition '\Q$bad_cond\E'", "bad navigation condition '$bad_cond'");
    }
}

{ my $t= XML::Twig->new->parse( '<doc><field/></doc>');
  eval { $t->root->set_field( '*[2]'); };
  matches( $@, "^can't create a field name from", 'set_field');
}

{ my $t= XML::Twig->new( twig_handlers => { erase => sub { $_->parent->erase } });
  eval { $t->parse( '<doc><p><erase>toto</erase></p></doc>'); };
  matches( $@, "^trying to erase an element before it has been completely parsed", 'erase current element');
}

{ my $t= XML::Twig->new->parse( '<doc><erase><e1/><e2/></erase></doc>');
  my $e= $t->first_elt( 'erase')->cut;
  eval { $e->erase };
  matches( $@, "^can only erase an element with no parent if it has a single child", 'erase cut element');
  $e->paste( $t->root);
  eval { $e->paste( first_child => $t->root); };
  matches( $@, "^cannot paste an element that belongs to a tree", 'paste uncut element');
  $e->cut;
  eval { $e->paste( $t->root => 'first_child' ); };
  matches( $@, "^wrong argument order in paste, should be", 'paste uncut element');
  eval { $e->paste( first_child  => {} ); };
  matches( $@, "^wrong target type in paste: 'HASH', should be XML::Twig::Elt", 'paste with wrong ref');
  eval { $e->paste( 'first_child' ); };
  matches( $@, "^missing target in paste", 'paste with no target');
  eval { $e->paste( 'first_child', 1 ); };
  matches( $@, '^wrong target type in paste \(not a reference\)', 'paste with no ref');
  eval { $e->paste( 'first_child', bless( {}, 'foo') ); };
  matches( $@, "^wrong target type in paste: 'foo'", 'paste with wrong object type');
  eval { $e->paste( wrong => $t->root ); };
  matches( $@, "^tried to paste in wrong position 'wrong'", 'paste in wrong position');
  eval { $e->paste( before => $t->root); };
  matches( $@, "^cannot paste before root", 'paste before root');
  eval { $e->paste( after => $t->root); };
  matches( $@, "^cannot paste after root", 'paste after root');
  eval { $e->paste_before( $t->root); };
  matches( $@, "^cannot paste before root", 'paste before root');
  eval { $e->paste_after( $t->root); };
  matches( $@, "^cannot paste after root", 'paste after root');
  
}

{ my $t= XML::Twig->new->parse( '<doc><p>text1</p><p>text2</p></doc>');
  my $p1= $t->root->first_child( 'p');
  my $p2= $t->root->first_child( 'p[2]');
  eval { $p1->merge_text( 'toto'); } ;
  matches( $@, "^invalid merge: can only merge 2 elements", 'merge elt and string');
  eval { $p1->merge_text( $p2); } ;
  matches( $@, "^invalid merge: can only merge 2 text elements", 'merge non text elts');
  $p1->first_child->merge_text( $p2->first_child);
  is( $t->sprint, '<doc><p>text1text2</p><p></p></doc>');
  my $p3= XML::Twig::Elt->new( '#CDATA' => 'foo');
  eval { $p1->first_child->merge_text( $p3); };
  matches( $@, "^invalid merge: can only merge 2 text elements", 'merge cdata and pcdata elts');
  
}

{ my $t= XML::Twig->new;
  $t->save_global_state;
  eval { $t->set_pretty_print( 'foo'); };
  matches( $@, "^invalid pretty print style 'foo'", 'invalid pretty_print style');
  eval { $t->set_pretty_print( 987); };
  matches( $@, "^invalid pretty print style 987", 'invalid pretty_print style');
  eval { $t->set_empty_tag_style( 'foo'); };
  matches( $@, "^invalid empty tag style 'foo'", 'invalid empty_tag style');
  eval { $t->set_empty_tag_style( '987'); };
  matches( $@, "^invalid empty tag style 987", 'invalid empty_tag style');
  eval { $t->set_quote( 'foo'); };
  matches( $@, "^invalid quote 'foo'", 'invalid quote style');
  eval { $t->set_output_filter( 'foo'); };
  matches( $@, "^invalid output filter 'foo'", 'invalid output filter style');
  eval { $t->set_output_text_filter( 'foo'); };
  matches( $@, "^invalid output text filter 'foo'", 'invalid output text filter style');
}
  
{ my $t= XML::Twig->new->parse( '<doc/>');
  my @methods= qw( depth in_element within_element context current_line current_column current_byte
                   recognized_string original_string xpcroak xpcarp xml_escape base current_element 
                   element_index position_in_context
                 );
  my $method;
  foreach $method ( @methods)
    { eval "\$t->$method"; 
      matches( $@, "^calling $method after parsing is finished", $method);
    }
  $SIG{__WARN__}= $init_warn;
}

{ my $t= XML::Twig->new->parse( '<doc><elt/></doc>');
  my $elt= $t->root->first_child( 'elt')->cut;
  foreach my $pos ( qw( before after))
    { eval { $elt->paste( $pos => $t->root); };
      matches( $@, "^cannot paste $pos root");
    }
}

{  my $t= XML::Twig->new->parse( '<doc><a><f1>f1</f1><f2>f2</f2></a></doc>');
   eval { $t->root->simplify( group_tags => { a => 'f1' }); };
   matches( $@, "^error in grouped tag a");
   eval { $t->root->simplify( group_tags => { a => 'f2' }); };
   matches( $@, "^error in grouped tag a");
   eval { $t->root->simplify( group_tags => { a => 'f3' }); };
   matches( $@, "^error in grouped tag a");
}

{  eval { XML::Twig::Elt->parse( '<e>foo</e>')->subs_text( "foo", '&elt( invalid/0)'); };
   matches( $@, "^invalid replacement expression ");
}

{ eval { my $t=XML::Twig->new( twig_handlers => { e => sub { $_[0]->parse( "<doc/>") } });
            $t->parse( "<d><e/></d>");
       };
  matches( $@, "^cannot reuse a twig that is already parsing");
}

exit 0;

