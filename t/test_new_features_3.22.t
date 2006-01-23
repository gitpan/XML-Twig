#!/usr/bin/perl -w
use strict;

# $Id: test_new_features_3.22.t,v 1.8 2005/12/08 10:47:43 mrodrigu Exp $
use Carp;

use FindBin qw($Bin);
BEGIN { unshift @INC, $Bin; }
use tools;

use XML::Twig;

my $DEBUG=0;
print "1..20\n";

         
{ my $doc= q{<?xml version="1.0" ?>
<!DOCTYPE doc [ <!ENTITY foo 'toto'>]>
<doc>&foo;</doc>};
  XML::Twig->new( keep_encoding => 1)->parse( $doc);
}

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
    { skip( 3 => 'need  HTML::TreeBuilder to test parse_html'); }
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

if( _use 'HTML::TreeBuilder')
  {
      $doc=q{<html><head><title>foo</title></head><body><p>toto</p></body></html>}; 
      is( XML::Twig->nparse( $doc)->sprint, $doc, 'nparse well formed html string');
      $doc_file="doc.html";
      spit( $doc_file => $doc);
      is( XML::Twig->nparse( $doc_file)->sprint, $doc, 'nparse well formed html file');
      #is( XML::Twig->nparse( "file://$doc_file")->sprint, $doc, 'nparse well formed url');
      unlink $doc_file;

      XML::Twig::_disallow_use( 'HTML::TreeBuilder');
      eval{ XML::Twig->new->parse_html( '<html/>'); };
      matches( $@, "^cannot parse HTML: missing HTML::TreeBuilder", "parse_html without HTML::TreeBuilder");
      XML::Twig::_allow_use( 'HTML::TreeBuilder');
  }
else
  { skip( 3); }

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

{ 
  my $file= "$Bin/test_new_features_3.22.html";
  if( -f $file) 
    { XML::Twig::_disallow_use( 'LWP::Simple');
      eval { XML::Twig->nparse( "file://$file"); };
      matches( $@, "^missing LWP::Simple", "nparse html url without LWP::Simple");
      XML::Twig::_allow_use( 'LWP::Simple');
      if( XML::Twig::_use( 'LWP::Simple') && XML::Twig::_use( 'HTML::TreeBuilder'))
        { my $content= XML::Twig->nparse( "file://$file")->sprint;
          (my $expected= slurp( $file))=~ s{(<(meta|br)[^>]*>)}{$1</$2>}g;
          $expected=~s{<p>t3}{<p>t3</p>};
          is( $content, $expected, "nparse url");
        }
      else
        { skip( 1 => "cannot test html url parsing without LWP::Simple and HTML::TreeBuilder"); }
      
    }
  else
    { skip( 2 => "cannot find $file"); }
}

{ 
  my $file= "$Bin/test_new_features_3.22.xml";
  if( -f $file) 
    { XML::Twig::_disallow_use( 'LWP');
      eval { XML::Twig->nparse( "file://$file"); };
      matches( $@, "^LWP not available", "nparse url without LWP");
      XML::Twig::_allow_use( 'LWP');
      if( XML::Twig::_use( 'LWP'))
        { my $content= XML::Twig->nparse( "file://$file")->sprint;
          is( $content, "<doc></doc>", "nparse url");
        }
      else
        { skip( 1 => "cannot test url parsing without LWP"); }
    }
  else
    { skip( 2 => "cannot find $file"); }
}
 

{ my $file= "t/test_new_features_3.22.xml";
  open( FH, "<$file") or die "cannot find test file '$file': $!";
  my $content= XML::Twig->nparse( \*FH)->sprint;
  is( $content, "<doc></doc>", "nparse glob");
}
