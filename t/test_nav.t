#!/bin/perl -w
use strict;
use Carp;

# test for the various conditions in navigation methods

use XML::Twig;


my $i=1;

my $t= XML::Twig->new;
$t->parse( 
'<doc id="doc">
    <elt id="elt-1">
      <subelt id="subelt-1">text1</subelt>
    </elt>
    <elt id="elt-2"/>
    <elt2 id="elt2-1"/>
    <elt2 id="elt2-2">text</elt2>
    <elt2 id="elt2-3">
      <subelt id="subelt-2">text</subelt>
      <subelt id="subelt-3">text}</subelt>
      <subelt id="subelt-3">text"</subelt>
      <subelt id="subelt-3">text\'</subelt>
      <subelt id="subelt-4">text 2</subelt>
    </elt2>
    text level1
  </doc>');

my $root= $t->root;

my @data= grep { !/^##/  && m{\S} } <DATA>;
my %result= map { chomp; split /\s*=>\s*/} @data;

my $nb_tests= keys %result;
print "1..$nb_tests\n";

#push @data,  qr/^el/, qr/^.*2$/, qr/^2$/;
#push @data, sub { return $_[0] if( $_[0]->text eq "text"); };

foreach my $cond ( keys %result)
  { my $expected_result= $result{$cond};
    my $result;
    my $res= $root->first_child( $cond);
    if( $res) 
      { if( $res->id) { $result= $res->id;   }
        else          { $result= $res->text;
	                $result=~ s/^\s+//;
	                $result=~ s/\s+$//;
	              }
      }
    else              { $result= 'none';  }
    if( $result eq $expected_result)
      { print "ok $i\n"; }
    else
      { print "nok $i\n";
        print STDERR "$cond: expected $expected_result - real $result\n";
      }
    $i++;
  }

__DATA__
                           => elt-1
elt                        => elt-1
#ELT                       => elt-1
#TEXT                      => text level1
elt2                       => elt2-1
foo                        => none
elt[@id]                   => elt-1
/2$/                       => elt2-1
elt[@id="elt-1"]           => elt-1
elt2[@id=~/elt2/]          => elt2-1
elt[@id="elt2-1"]          => none
elt2[@id="elt2-1"]         => elt2-1
elt[@id=~/elt2/]           => none
[@id="elt1-1"]             => none
[@foo]                     => none
[@id]                      => elt-1
[@id=~/elt2$/]             => none
[@id=~/2-2$/]              => elt2-2
[@id=~/^elt2/]             => elt2-1
#PCDATA                    => text level1
elt[text(subelt)="text}" ] => none
elt2[text(subelt)="text}"] => elt2-3
elt2[text()="text}"]       => none
elt2[text(subelt)='text"'] => elt2-3
elt2[text(subelt)="text'"] => elt2-3
[text(subelt)="text}"]     => elt2-3
[text(subelt)="text1"]     => elt-1
[text(subelt)="text 2"]    => elt2-3
elt2[text(subelt)="text 2"]=> elt2-3
elt[text(subelt)="text 2"] => none
[text(subelt)="foo"]       => none
[text(subelt)=~/text/]     => elt-1
[text(subelt)=~/^ext/]     => none
elt2[text(subelt)="text"]  => elt2-2 
elt[text(subelt)="text"]   => none
elt[text(subelt)="foo"]    => none
elt[text(subelt)=~/text/]  => elt-1
elt[text(subelt)=~/^ext/]  => none
elt2[text(subelt)="text"]  => elt2-3
elt2[text(subelt)="foo"]   => none
elt2[text(subelt)=~/tex/]  => elt2-3
elt2[text(subelt)=~/^et/]  => none
elt2[text(subelt)=~/^et}/]  => none
/ELT/i                     => elt-1
##elt2[text(subelt)="text\""] => elt2-3
