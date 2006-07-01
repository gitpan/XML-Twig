#!/usr/bin/perl -w
use strict;

# $Id: test_3_26.t,v 1.5 2006/05/26 08:07:15 mrodrigu Exp $

use strict;
use Carp;
use File::Spec;
use lib File::Spec->catdir(File::Spec->curdir,"t");
use tools;

$|=1;
my $DEBUG=0;
 
use XML::Twig;

my $TMAX=13;
print "1..$TMAX\n";

{ # testing set_inner_xml
  my $doc= '<doc><elt/><elt2>with content <p>toto</p></elt2></doc>';
  my $t= XML::Twig->nparse( $doc);
  my $inner= '<p1/><p>foo</p><bar><elt id="toto">duh</elt></bar>';
  $t->first_elt( 'elt')->set_inner_xml( $inner);
  (my $expected= $doc)=~ s{<elt/>}{<elt>$inner</elt>};
  is( $t->sprint, $expected, "set_inner_xml");

  $t->first_elt( 'elt2')->set_inner_xml( $inner);
  $expected=~ s{<elt2>.*</elt2>}{<elt2>$inner</elt2>};
  is( $t->sprint, $expected, "set_inner_xml (of an elt with content)");

}

{ # testing set_inner_html
  if( !XML::Twig::_use( 'HTML::TreeBuilder', 3.13))
    { skip( 4 => "need HTML::TreeBuilder 3.13+ to use set_inner_html method");
    }
  else
    {
      my $doc= '<html><head><title>a title</title></head><body>par 1<p>par 2<br>after the break</body></html>';
      my $t= XML::Twig->nparse( $doc);
      my $inner= '<ul><li>foo</li><li>bar</li></ul>';
      $t->first_elt( 'p')->set_inner_html( $inner);
      (my $expected= $t->sprint)=~ s{<p>.*</p>}{<p>$inner</p>};
      is( $t->sprint, $expected, "set_inner_html");

      $inner= q{<title>2cd title</title><meta content="bar" name="foo">};
      $t->first_elt( 'head')->set_inner_html( $inner);
      $inner=~ s{>$}{/>};
      $expected=~ s{<head>.*</head>}{<head>$inner</head>};
      is( $t->sprint, $expected, "set_inner_html (in head)");

      $inner= q{<p>just a p</p>};
      $t->root->set_inner_html( $inner);
      $expected= qq{<html><head></head><body>$inner</body></html>};
      is( $t->sprint, $expected, "set_inner_html (all doc)");

      $inner= q{the content of the <br/> body};
      $t->first_elt( 'body')->set_inner_html( $inner);
      $expected= qq{<html><head></head><body>$inner</body></html>};
      is( $t->sprint, $expected, "set_inner_html (body)");
    }
  
}

{ if( !XML::Twig::_use( "File::Temp"))
    { skip( 5, "File::Temp not available"); }
  else
    {
      # parsefile_inplace
      my $file= "test_3_26.xml";
      spit( $file, q{<doc><foo>nice hey?</foo></doc>});
      XML::Twig->new( twig_handlers => { foo => sub { $_->set_tag( 'bar')->flush; }})
               ->parsefile_inplace( $file);
      matches( slurp( $file), qr/<bar>/, "parsefile_inplace");
      
      XML::Twig->new( twig_handlers => { bar => sub { $_->set_tag( 'toto')->flush; }})
               ->parsefile_inplace( $file, '.bak');
      matches( slurp( $file), qr/<toto>/, "parsefile_inplace (with backup, checking file)");
      matches( slurp( "$file.bak"), qr/<bar>/, "parsefile_inplace (with backup, checking backup)");
      unlink( "$file.bak");
    
      XML::Twig->new( twig_handlers => { toto => sub { $_->set_tag( 'tata')->flush; }})
               ->parsefile_inplace( $file, 'bak_*');
      matches( slurp( $file), qr/<tata>/, "parsefile_inplace (with complex backup, checking file)");
      matches( slurp( "bak_$file"), qr/<toto>/, "parsefile_inplace (with complex backup, checking backup)");
      unlink( "bak_$file");
      unlink $file;
    }
}

{ use Cwd;
  my $file = "test_uri";
  my $uri  = sprintf( "file://%s/%s", getcwd, $file);
  my $content= "ok";
  spit( test_uri => $content);
  is( XML::Twig::_slurp_uri( $uri), $content, "testing _slurp_uri");
}

{ # test syntax error in XPath predicate (RT #19499)
  my $t= XML::Twig->nparse( '<doc/>');
  eval { $t->get_xpath( '/*[@!a]'); };
  matches( $@, qr/^error in xpath expression/, "syntax error in XPath predicate");
}
