#!/bin/perl -w

use strict;


# This tests the doctype and DTD access functions

$|=1;

use XML::Twig;
use Cwd;

$0 =~ s!\\!/!g;
my ($DIR,$PROG) = $0 =~ m=^(.*/)?([^/]+)$=;
$DIR =~ s=/$== || chop($DIR = cwd());

chdir $DIR;

my $i=0;
my $failed=0;

my $TMAX=15; # don't forget to update!

print "1..$TMAX\n";

# test twig creation
my $t= new XML::Twig();
test( $t, 'twig creation');

# first test an internal DTD

my $in_file=  "test2_1.xml";

my $res_file= "test2_1.res";
my $exp_file= "test2_1.exp";

# test parse no dtd info required
$t->parsefile( $in_file, ErrorContext=>2);
test( $t, 'parse');

open( RES, ">$res_file") or die "cannot open $res_file:$!";
$t->print( \*RES);
close RES;
test( $res_file, $exp_file, "flush");

$res_file= 'test2_2.res';
$exp_file= 'test2_2.exp';
open( RES, ">$res_file") or die "cannot open $res_file:$!";
$t->print( \*RES, Update_DTD => 1);
close RES;
test( $res_file, $exp_file, "flush");

$t= new XML::Twig();
test( $t, 'twig creation');

$in_file=  "test2_2.xml";
$res_file= "test2_3.res";
$exp_file= "test2_3.exp";

$t->parsefile( $in_file, ErrorContext=>2);
test( $t, 'parse');
open( RES, ">$res_file") or die "cannot open $res_file:$!";

my $e2=new XML::Twig::Entity( 'e2', 'entity2');
my $entity_list= $t->entity_list;
$entity_list->add( $e2);

my $e3=new XML::Twig::Entity( 'e3', undef, 'pic.jpeg', 'JPEG');
$entity_list= $t->entity_list;
$entity_list->add( $e3);

$t->print( \*RES, Update_DTD => 1);
close RES;

test( $res_file, $exp_file, "flush");

my $dtd= $t->dtd;
test( !$dtd, 'dtd exits');

$t= new XML::Twig(LoadDTD=>1);
test( $t, 'twig creation');
$t->parsefile( $in_file, ErrorContext=>2, );

$dtd= $t->dtd;
test( $dtd, 'dtd not found');

my @model= sort keys %{$dtd->{model}};
stest( stringify( @model), 'doc:intro:note:para:section:title', 'element list');

stest( $t->model( 'title'), '(#PCDATA)', 'title model');
mtest( $t->model( 'section'), '\(intro\?,\s*title,\s*\(para|note\)+\)', 'section model');
stest( $t->dtd->{att}->{section}->{id}->{type}, 'ID', 'section id type');
stest( $t->dtd->{att}->{section}->{id}->{default}, '#IMPLIED', 'section id default');
exit 0;




##################################################################################
# test functions
##################################################################################

# element test
sub etest 
  { my ($elt, $gi, $id, $message)= @_;
    $i++;
    unless( $elt)
      { print "not ok $i\n    -- $message\n";
        warn "         -- no element returned";
        return;
      }
    if( ($elt->gi eq $gi) && ($elt->att( 'id') eq $id))
      { print "ok $i\n"; 
        return $elt;
      }
    print "not ok $i\n    -- $message\n";
    warn "         -- expecting ", $gi, " ", $id, "\n";
    warn "         -- found     ", $elt->gi, " ", $elt->id, "\n";
    return $elt;
  }

# element text test
sub ttest
  { my ($elt, $text, $message)= @_;
    $i++;
    unless( $elt)
      { print "not ok $i\n    -- $message\n";
        warn "         -- no element returned ";
        return;
      }
    if( $elt->text eq $text)
      { print "ok $i\n"; 
        return $elt;
      }
    print "not ok $i\n    -- $message\n";
    warn "          expecting ", $text, "\n";
    warn "          found     ", $elt->text, "\n";
    return $elt;
  }

# testing if the result is a  strings
sub stest
  { my ($result, $expected, $message)= @_;
    $i++;
    if( $result eq $expected)
      { print "ok $i\n"; }
    else
      { print "not ok $i\n    -- $message\n";  
        warn "          expecting ", $expected, "\n";
         warn"          found     ", $result, "\n";
      }
  }

# testing if the result matches a pattern
sub mtest
  { my ($result, $expected, $message)= @_;
    $i++;
    if( $result=~ /$expected/)
      { print "ok $i\n"; }
    else
      { print "not ok $i\n    -- $message\n";  
        warn "          expecting ", $expected, "\n";
         warn"          found     ", $result, "\n";
      }
  }

sub test
  { my ($result, $message)= @_;
    $i++;
    if( $result)
      { print "ok $i\n"; }
    else
      { print "not ok $i\n";
        warn "  $message\n"; }
  }


# test 2 files
sub ftest
  { my ($result_file, $expected_file, $message)= @_;
    my $result_string= load_file( $result_file);
    my $expected_string= load_file( $expected_file);
    $i++;
    if( $result_string eq $expected_string)
      { print "ok $i\n"; }
    else
      { print "not ok $i\n    -- $message\n";  
        warn "          expecting ", $expected_string, "\n";
        warn "          found     ", $result_string, "\n";
      }
    
  }

sub load_file
  { my $file= shift;
    my $string='';
    open( TMP, "<$file") or die "cannot open $file: $!";
    while( <TMP>)
      { $string.= chomp; }
    close TMP;
    return $string;
  }        

sub stringify
  { return join ":", @_; }

sub hstringify
  { my %hash= %{shift()};
    return join ":", map { "$_:%hash{$_}"}  sort keys %hash; 
  }
