#!/bin/perl -w

# $Id: test_mark.t,v 1.1 2004/06/28 14:11:20 mrodrigu Exp $

# test the mark method

use strict;
use Carp;

#$|=1;
my $DEBUG=0;

use XML::Twig;

my $perl= $];

my @data= map { chomp; [split /\t+/] } <DATA>;

my $TMAX= 2 * @data; 
print "1..$TMAX\n";

foreach my $test (@data)
  { my( $doc, $regexp, $elts, $hits, $result)= @$test;
    (my $quoted_elts= $elts)=~ s{(\w+)}{'$1'}g;
    my @elts= eval( "($quoted_elts)"); 
    my $t= XML::Twig->new->parse( $doc);
    my $root= $t->root;
    my @hits= $root->mark( $regexp, @elts);
    is( $t->sprint, $result, "mark( /$regexp/, $quoted_elts) on $doc");
    is( scalar @hits, $hits, 'nb hits');
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
}

# doc										regexp				elts	hits	result
__DATA__
<doc>text X</doc>				(X)							s			1		<doc>text <s>X</s></doc>
<doc>text X </doc>			X								s			1		<doc>text <s/> </doc>
<doc>text</doc>					X								s			0		<doc>text</doc>
<doc>text</doc>					(X)							s			0		<doc>text</doc>
<doc>text X</doc>				X								s			1		<doc>text <s/></doc>
<doc>text X</doc>				(X)							s			1		<doc>text <s>X</s></doc>
<doc>text X </doc>			\s*X\s*					s			1		<doc>text<s/></doc>
<doc>text X </doc>			\s*(X)\s*				s			1		<doc>text<s>X</s></doc>
<doc>text X </doc>			(\s*X\s*)				s			1		<doc>text<s> X </s></doc>
<doc>text X text</doc>	X								s			1		<doc>text <s/> text</doc>
<doc>text X text</doc>	(X)							s			1		<doc>text <s>X</s> text</doc>
<doc>text X text</doc>	\s*X\s*					s			1		<doc>text<s/>text</doc>
<doc>text X text</doc>	\s*(X)\s*				s			1		<doc>text<s>X</s>text</doc>
<doc>text X text</doc>	(\s*X\s*)				s			1		<doc>text<s> X </s>text</doc>
<doc>text XX </doc>			X								s			2		<doc>text <s/><s/> </doc>
<doc>text XX</doc>			(X)							s			2		<doc>text <s>X</s><s>X</s></doc>
<doc>text X X </doc>		X								s			2		<doc>text <s/> <s/> </doc>
<doc>text X X</doc>			(X)							s			2		<doc>text <s>X</s> <s>X</s></doc>
<doc>text XX text</doc>	X								s			2		<doc>text <s/><s/> text</doc>
<doc>text XX text</doc>	(X)							s			2		<doc>text <s>X</s><s>X</s> text</doc>
<doc>text XY text Y text X</doc>	([XY]+)	s		3		<doc>text <s>XY</s> text <s>Y</s> text <s>X</s></doc>
<doc>text X</doc>				X								s, {a => 1}			1		<doc>text <s a="1"/></doc>
<doc>text X</doc>				(X)							s, {a => 1, b => 2}			1		<doc>text <s a="1" b="2">X</s></doc>
<doc>text X1Y2 text X0 Y0X3Y4 text X</doc>	X(\d)Y(\d)		s		4		<doc>text <s>1</s><s>2</s> text X0 Y0<s>3</s><s>4</s> text X</doc>
