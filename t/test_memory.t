#!/usr/bin/perl -w
use strict;

# $Id: test_3_24.t,v 1.1 2006/05/17 11:20:27 mrodrigu Exp $

use strict;
use Carp;
use File::Spec;
use lib File::Spec->catdir(File::Spec->curdir,"t");
use tools;

$|=1;
my $DEBUG=0;
 
use XML::Twig;

my $mem_size= mem_size();

unless( $mem_size)
  { print "1..1\nok 1\n";
    warn "skipping: memory size not available\n";;
    exit;
  }

if( !XML::Twig::_weakrefs())
  {  print "1..1\nok 1\n";
    warn "skipping: weaken not available\n";;
    exit;
  }


my $TMAX=2;
print "1..$TMAX\n";


{ my $xml= qq{<doc>} . qq{<p>lorem ipsus whatever (clever latin stuff)</p>} x 100 .qq{</doc>};
  XML::Twig->new->parse( $xml);
  my $before= mem_size();
  for (1..5) { XML::Twig->new->parse( $xml); mem_size(); }
  my $after= mem_size();
  is( $after, $before, "memory leak parsing xml"); 
}

{ if( XML::Twig::_use( 'HTML::TreeBuilder', 3.13))
    { my $html= qq{<html><body>} . qq{<p>lorem ipsus whatever (clever latin stuff)</p>} x 500 .qq{</body></html>};
      XML::Twig->new->parse_html( $html);
      my $before= mem_size();
      for (1..5) { XML::Twig->new->parse_html( $html); mem_size(); }
      my $after= mem_size();
      is( $after, $before, "memory leak parsing xml"); 
    }
  else
    { skip( 1, "need HTML::TreeBuilder 3.13+"); }
}


sub mem_size
  { open( STATUS, "/proc/$$/status") or return;
    my( $size)= map { m{^VmSize:\s+(\d+\s+\w+)} } <STATUS>;
    $size=~ s{ kB}{};
    #warn "data size found: $size\n";
    return $size;
  }


