#!/bin/perl -w

use strict;


$|=1;

use XML::Twig;

my $i=0;
my $failed=0;

my $TMAX=18; # don't forget to update!

print "1..$TMAX\n";

my $s='
<doc>
  <section id="s1">
    <title id="t1">Title <b>bold</b></title>
    <p id="p1">para1</p>
    <p id="p2">para2</p>
  </section>

  <section id="s2">
    <title id="t2">Title</title>
    <p id="p3">para2</p>
    <p id="p3">para3</p>
  </section>
</doc>';

my @toc;
my $t= new XML::Twig( TwigHandlers => { title => sub { push @toc, $_[1]->text; } });
$t->parse( $s);
my $toc= join ':', @toc;
stest( $toc, "Title bold:Title", "text method");

undef @toc;
$t= new XML::Twig( TwigHandlers => { title => sub { push @toc, $_[1]->sprint( 1); } });
$t->parse( $s);
$toc= join ':', @toc;
stest( $toc, "Title <b>bold</b>:Title", "sprint method");

undef @toc;
$t= new XML::Twig( TwigHandlers => { title => sub { push @toc, $_[1]->sprint( 1); 
                                                    $_[0]->purge; } });
$t->parse( $s);
$toc= join ':', @toc;
stest( $toc, "Title <b>bold</b>:Title", "sprint method with purge");

my $purged_doc= $t->sprint;
stest( $purged_doc, '<doc><section id="s2"><p id="p3">para2</p><p id="p3">para3</p></section></doc>', "sprint purged doc");


$t= new XML::Twig( TwigRoots => { title => 1});
$t->parse( $s);
my $doc= $t->sprint;
stest( $doc, '<doc><title id="t1">Title <b>bold</b></title><title id="t2">Title</title></doc>', "using title as TwigRoots");

$t= new XML::Twig( TwigHandlers => { doc => sub { $_[1]->set_att( mod => "yes"); } },
                   TwigRoots => { title => 1});
$t->parse( $s);
$doc= $t->sprint;
stest( $doc, '<doc mod="yes"><title id="t1">Title <b>bold</b></title><title id="t2">Title</title></doc>', "using title as TwigRoots (with doc handler)");

$s='
<doc>
  <section id="s1">
    <title id="t1">t1 <b>b1</b></title>
    <p id="p5">para1</p>
    <section id="ss1">
      <title id="ts1">ts1 <b>b2</b></title>
      <p2 id="p1">para1</p2>
      <p id="p2">para2</p>
    </section>
  </section>

  <section id="s2">
    <title id="t2">t2</title>
    <p id="p3">para3</p>
    <p2 id="p4">para4</p2>
    <section id="ss2">
      <title id="ts2">ts2</title>
      <p id="p6">para6</p>
      <p id="p7">para7</p>
    </section>
  </section>
</doc>';
$t= new XML::Twig( TwigHandlers => { doc => sub { $_[1]->set_att( mod => "yes"); } },
                   TwigRoots => { title => 1});
$t->parse( $s);
$doc= $t->sprint;
stest( $doc, '<doc mod="yes"><title id="t1">t1 <b>b1</b></title><title id="ts1">ts1 <b>b2</b></title><title id="t2">t2</title><title id="ts2">ts2</title></doc>', "using title as TwigRoots (with doc handler)");

$t= new XML::Twig( TwigHandlers => { doc => sub { $_[1]->set_att( mod => "yes"); } },
                   TwigRoots => { title => 1, p2 => 1});
$t->parse( $s);
$doc= $t->sprint;
stest( $doc, '<doc mod="yes"><title id="t1">t1 <b>b1</b></title><title id="ts1">ts1 <b>b2</b></title><p2 id="p1">para1</p2><title id="t2">t2</title><p2 id="p4">para4</p2><title id="ts2">ts2</title></doc>', "using title, p2 as TwigRoots (with doc handler)");

$s="<doc>string with ' here</doc>";
$t= new XML::Twig();
$t->parse( $s);
$doc= $t->sprint;
stest( $doc, "<doc>string with ' here</doc>", "apos without KeepEncoding");

$t= new XML::Twig( KeepEncoding => 1);
$t->parse( $s);
$doc= $t->sprint;
stest( $doc, "<doc>string with ' here</doc>", "apos WITH KeepEncoding");


$s="<doc>string with &quot; here</doc>";
$t= new XML::Twig();
$t->parse( $s);
$doc= $t->sprint;
stest( $doc, "<doc>string with &quot; here</doc>", "quote without KeepEncoding");

$t= new XML::Twig( KeepEncoding => 1);
$t->parse( $s);
$doc= $t->sprint;
stest( $doc, '<doc>string with &quot; here</doc>', "quote WITH KeepEncoding");

$s="<doc>string with &amp; here</doc>";
$t= new XML::Twig();
$t->parse( $s);
$doc= $t->sprint;
stest( $doc, $s, "&amp; in text");

$s='<doc att="val &amp; tut">string</doc>';
$t= new XML::Twig();
$t->parse( $s);
$doc= $t->sprint;
stest( $doc, $s, "&amp; in attribute");

$s="<doc>string with &lt; here</doc>";
$t= new XML::Twig();
$t->parse( $s);
$doc= $t->sprint;
stest( $doc, $s, "&lt; in text");

$s='<doc att="val &lt; tut">string</doc>';
$t= new XML::Twig();
$t->parse( $s);
$doc= $t->sprint;
stest( $doc, $s, "&lt; in attribute");

$s="<doc>string with &quot; here</doc>";
$t= new XML::Twig();
$t->parse( $s);
$doc= $t->sprint;
stest( $doc, $s, "&quot; in text");

$s='<doc att="val &lt; tut">string</doc>';
$t= new XML::Twig();
$t->parse( $s);
$doc= $t->sprint;
stest( $doc, $s, "&quot; in attribute");

#$s='<doc att="val &#130; tut">string</doc>';
#$t= new XML::Twig();
#$t->parse( $s);
#$doc= $t->sprint;
#stest( $doc, $s, "&#130; in attribute");

#$s="<doc>string with � here</doc>";
#$t= new XML::Twig();
#$t->parse( $s);
#$doc= $t->sprint;
#stest( $doc, "<doc>string with &#130; here</doc>", "eacute without KeepEncoding");

#$t= new XML::Twig( KeepEncoding => 1);
#$t->parse( $s);
#$doc= $t->sprint;
#stest( $doc, '<doc>string with � here</doc>', "eacute WITH KeepEncoding");

#$s='<doc>string with &#130; here</doc>';
#$t= new XML::Twig();
#$t->parse( $s);
#$doc= $t->sprint;
#stest( $doc, "<doc>string with &#130; here</doc>", "&#130; without KeepEncoding");

#$t= new XML::Twig( KeepEncoding => 1);
#$t->parse( $s);
#$doc= $t->sprint;
#stest( $doc, '<doc>string with &#130; here</doc>', "&#130; WITH KeepEncoding");

#$s='<doc><?PI text?><elt>text</elt></doc>';
#$t= new XML::Twig();
#$t->parse( $s);
#$doc= $t->sprint;
#stest( $doc, $s, "PI");


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

# element string test
sub sttest
  { my ($elt, $text, $message)= @_;
    $i++;
    unless( $elt)
      { print "not ok $i\n    -- $message\n";
        warn "         -- no element returned ";
        return;
      }
    if( $elt->sprint eq $text)
      { print "ok $i\n"; 
        return $elt;
      }
    print "not ok $i\n    -- $message\n";
    warn "          expecting ", $text, "\n";
    warn "          found     ", $elt->sprint, "\n";
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
        warn "not ok $i\n    -- $message\n";  
        warn "          expecting ", $expected, "\n";
        warn "          found     ", $result, "\n";
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


sub stringify
  { return join ":", @_; }