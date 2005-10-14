#!/usr/bin/perl -w
use strict;

# $Id: test_new_features_3.22.t,v 1.6 2005/10/14 16:14:48 mrodrigu Exp $
use Carp;

use FindBin qw($Bin);
BEGIN { unshift @INC, $Bin; }
use tools;

use XML::Twig;

my $DEBUG=0;
print "1..14\n";


{ # testing parse_html
 
  if( _use 'HTML::TreeBuilder')
    { my $html= q{<html><head><title>T</title><meta content="mv" name="mn"></head><body>t<br>t2<p>t3</body></html>};
      my $expected= HTML::TreeBuilder->new->parse( $html)->as_XML;
      is_like( XML::Twig->new->parse_html( $html)->sprint, $expected, 'parse_html string using HTML::TreeBuilder');

      my $html_file= "t/test_new_features_3.22.html";
      spit( $html_file => $html);
      is_like( XML::Twig->new->parsefile_html( $html_file)->sprint, $expected, 'parsefile_html using HTML::TreeBuilder');

      open( HTML, "<$html_file") or die "cannot open HTML file '$html_file': $!";
      is_like( XML::Twig->new->parse_html( \*HTML)->sprint, $expected, 'parse_html fh using HTML::TreeBuilder');
      
    }
  else
    { skip( 3 => 'need XML::LibXML to test parse_html'); }
}

{ # testing _use
  ok( XML::Twig::_use( 'XML::Parser'));
  ok( XML::Twig::_use( 'XML::Parser')); # second time tests the caching
  nok( XML::Twig::_use( 'I::HOPE::THIS::MODULE::NEVER::MAKES::IT::TO::CPAN'));
  nok( XML::Twig::_use( 'I::HOPE::THIS::MODULE::NEVER::MAKES::IT::TO::CPAN'));
}

{ # testing auto-new features
  my $doc= '<doc/>';
  is( XML::Twig->nparse( $doc)->sprint, $doc, 'nparse string');
  is( XML::Twig->nparse( empty_tags => 'expand', $doc)->sprint, '<doc></doc>', 'nparse string and option');
  my $doc_file= 'doc.xml';
  
  spit( $doc_file => $doc);
  # doc is still expanded because empty_tags was set above
  is( XML::Twig->nparse( $doc_file)->sprint, '<doc></doc>', 'nparse file');
  is( XML::Twig->nparse( twig_handlers => { doc => sub { $_->set_tag( 'foo'); } }, $doc_file)->sprint, '<foo></foo>', 'nparse file and option');
  unlink $doc_file;

  $doc=q{<html><head><title>foo</title></head><body><p>toto</p></body></html>}; 
  is( XML::Twig->nparse( $doc)->sprint, $doc, 'nparse well formed html string');
  $doc_file="doc.html";
  spit( $doc_file => $doc);
  is( XML::Twig->nparse( $doc_file)->sprint, $doc, 'nparse well formed html file');
  #is( XML::Twig->nparse( "file://$doc_file")->sprint, $doc, 'nparse well formed url');
  unlink $doc_file;

  if( _use 'HTML::TreeBuilder')
    { $doc=q{<html><head><title>foo</title></head><body><p>toto<br>tata</p></body></html>}; 
      (my $expected= $doc)=~ s{<br>}{<br></br>};
      $doc_file="doc.html";
      spit( $doc_file => $doc);
      is( XML::Twig->nparse( $doc_file)->sprint, $expected, 'nparse html file');
      #is( XML::Twig->nparse( "file://$doc_file")->sprint, $doc, 'nparse html url');
      unlink $doc_file;
    }
  else
    { skip ( 1); }
}
