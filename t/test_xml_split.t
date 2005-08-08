#!/usr/bin/perl -w
use strict;

# $Id: test_xml_split.t,v 1.6 2005/08/05 13:15:59 mrodrigu Exp $
use Carp;

my $DEBUG=0;

# be cautious: run this only on systems I have tested it on
my %os_ok=( linux => 1, solaris => 1);
if( !$os_ok{$^O}) { print "1..1\nok 1\n"; warn "skipping, test runs only on some OSs\n"; exit; }

print "1..18\n";

my $perl      = $^X;
my $xml_split = "tools/xml_split/xml_split";
my $xml_merge = "tools/xml_merge/xml_merge";

sys_ok( "$perl -c $xml_split", "xml_split compilation");
sys_ok( "$perl -c $xml_merge", "xml_merge compilation");

my $test_dir="t/test_xml_split";
my $test_file= "t/test_xml_split.xml";

my $base_nb; # global, managed by test_split_merge
test_split_merge( $test_file, "",             ""   );
test_split_merge( $test_file, "-i",           "-i" );
test_split_merge( $test_file, "-c elt1",      ""   );
test_split_merge( $test_file, "-i -c elt1",   "-i" );
test_split_merge( $test_file, "-c elt2",      ""   );
test_split_merge( $test_file, "-i -c elt2",   "-i" );

$test_file="t/test_xml_split_entities.xml";
test_split_merge( $test_file, "",         ""   );
test_split_merge( $test_file, "-c elt",   "" );


sub test_split_merge
  { my( $file, $split_opts, $merge_opts)= @_;
    $split_opts ||= '';
    $merge_opts ||= '';
    $base_nb++;
    my $expected_base= "$test_dir/test_xml_split_expected-$base_nb"; 
    my $base= "$test_dir/test_xml_split-$base_nb"; 

    systemq( "$perl $xml_split -b $base $split_opts $file");
    ok( same_files( $expected_base, $base), "xml_split $split_opts $test_file");

    system "$perl $xml_merge -o $base.xml $merge_opts $base-00.xml";
    ok( same_file( "$base.xml", $file), "xml_merge $merge_opts $test_file");
    
    unlink( glob( "$base*")) unless( $DEBUG);
  }

sub same_files
  { my( $expected_base, $base)= @_;
    my $nb="00";
    while( -f "$base-$nb.xml")
      { unless( same_file( "$expected_base-$nb.xml", "$base-$nb.xml"))
          { warn "  $expected_base-$nb.xml and $base-$nb.xml are different";
            return 0;
          }
        $nb++;
      }
    return 1;
  }

sub same_file
  { my( $file1, $file2)= @_;
    return slurp_mod( $file1) eq slurp_mod( $file2);
  }

# slurp and remove spaces and _expected from the file 
sub slurp_mod
  { my( $file)= @_;
    local undef $/;
    open( my $fh, "<$file") or return "$file not found:$!";
    my $content=<$fh>;
    $content=~ s{\s}{}g;
    $content=~ s{_expected}{}g;
    return $content;
  }

sub systemq 
  { if( !$DEBUG)
      { system "$_[0] 1>/dev/null 2>/dev/null"; }
    else
      { warn "$_[0]\n";
        system $_[0];
      }
  }


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
    
  sub sys_ok
    { my $message=pop;
      $test_nb++; 
      my $status= system join " ", @_, "2>/dev/null";
      if( !$status)
        { print "ok $test_nb\n"; 
          warn "ok $test_nb $message\n" if( $DEBUG); 
        }
      else { print "not ok $test_nb\n"; warn "$message: $!\n"; }

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

