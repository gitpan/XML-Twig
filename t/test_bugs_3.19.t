#!/usr/bin/perl -w
use strict;

# $Id: test_bugs_3.19.t,v 1.2 2005/08/10 14:48:38 mrodrigu Exp $

use strict;
use Carp;
use FindBin qw($Bin);
BEGIN { unshift @INC, $Bin; }
use tools;

$|=1;
my $DEBUG=0;

use XML::Twig;

my $TMAX=26;
print "1..$TMAX\n";

{
#bug with long CDATA

# get an accented char in iso-8859-1
my $char_file="t/latin1_accented_char.iso-8859-1";
open( my $fh, "<$char_file") or die "cannot open $char_file: $!";
my $latin1_char=<$fh>;
chomp $latin1_char;
close $fh;

            
my %cdata=( "01- 1025 chars"                    => 'x' x 1025 . 'a',
            "02- short CDATA with nl"           =>  "first line\nsecond line",
            "03- short CDATA with ]"            =>  "first part]second part",
            "04- short CDATA with ] and spaces" =>  "first part ] second part",
            "05- 1024 chars with accent"        =>  $latin1_char x 1023 . 'a',
            "06- 1025 chars with accent"        =>  $latin1_char x 1024 . 'a',
            "07- 1023 chars, last a nl"         => 'x' x 1022 . "\n",
            "08- 1023 chars, last a ]"          => 'x' x 1022 . "]",
            "09- 1024 chars, last a nl"         => 'x' x 1023 . "\n",
            "10- 1024 chars, last a ]"          => 'x' x 1023 . "]",
            "11- 1025 chars, last a nl"         => 'x' x 1024 . "\n",
            "12- 1025 chars, last a ]"          => 'x' x 1024 . "]",
            "13- 1050 chars, last a nl"         => ('1' x 1024) . ('2' x 25) . "\n",
            "14- 1050 chars, last a ]"          => ('1' x 1024) . ('2' x 25) . "]",
            '15- 1060 chars, ] and \n'          => ('1' x 1024) . ('2' x 26) . "\n  \n ]\n]]\n",
            '16- 1060 chars, ] and \n'          => ('1' x 1024) . ('2' x 26) . "\n  \n   ]\n]]",
            '17- 1060 chars, ] and \n'          => ('1' x 1024) . ('2' x 26) . "\n  \n ]\n]]  ",
            '18- 1060 chars, ] and \n'          => ('1' x 1024) . ('2' x 26) . "\n \n ]\n]]  a",
            '19- 1060 chars, ] and \n'          => '1' x 500 . "\n  \n  ]\n]] a" . '2' x 500 . "\n  \n  ]\n]] a", 
            "20- 800 chars with accent"         =>  $latin1_char x 800,
            "21- 800 chars with accent"         =>  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa$latin1_char" x 16,
            "22- 1600 chars with accent"        =>  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa$latin1_char" x 32,
            '23- 1600 chars with accent and \n' =>  "aaaaaaaa]aaaaaaaaaaaaaaaaaaaaaaaaa\naaaaaaaaaaaaaaa$latin1_char" x 32,
          );

if( $] == 5.008)
  { skip( scalar keys %cdata,   "KNOWN BUG in 5.8.0 with keep_encoding and long (>1024 char) CDATA, "
                              . "see http://rt.cpan.org/Ticket/Display.html?id=14008"
        );
  }
else
  {
    foreach my $test (sort keys %cdata)
      { my $cdata=$cdata{$test};
        my $doc= qq{<?xml version="1.0" encoding="iso-8859-1" ?><doc><![CDATA[$cdata]]></doc>};
        my $twig= XML::Twig->new( keep_encoding => 1)->parse($doc);
        my $res = $twig->root->first_child->cdata;
        is( $res, $cdata, "long CDATA with keep_encoding $test");
      }
  }
}

{ # testing _dump
  my $doc= q{<doc><!-- comment --><elt att="xyz">foo</elt><elt>bar<![CDATA[baz]]></elt><?t pi?><elt2>toto<b>tata</b>titi</elt2><elt3 /><elt>and now a long (more than 40 characters) text to see if it gets shortened by default (or not)</elt></doc>};
  my $t= XML::Twig->new->parse( $doc);
  my $dump= q{document
|-doc
| |- (not a node) '<!-- comment -->
| |-elt att="xyz"
| | |-PCDATA:  'foo'
| |-elt
| | |-PCDATA:  'bar'
| | |-CDATA:   'baz'
| |- (not a node) '<?t pi?>
| |-elt2
| | |-PCDATA:  'toto'
| | |-b
| | | |-PCDATA:  'tata'
| | |-PCDATA:  'titi'
| |-elt3
| |-elt
| | |-PCDATA:  'and now a long (more than 40 characters) tex ... see if it gets shortened by default (or not)'
};

  is( $t->_dump( { extra => 1 }), $dump, "_dump with extra on");

  (my $no_extra= $dump)=~ s{^.*not a node.*\n}{}gm;
  is( $t->_dump( ), $no_extra, "_dump without extra");

  (my $no_att= $no_extra)=~ s{ att=.*}{}g;
  is( $t->_dump( { atts => 0 }), $no_att, "_dump without atts");
  
}

