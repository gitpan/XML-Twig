#!/usr/bin/perl -w
use strict; 

use XML::Twig;

foreach my $module ( qw( XML::Simple Test::More Data::Dumper YAML) )
  { if( eval "require $module")
      { import $module; }
    else
      { print "1..1\nok 1\n";
        warn "skipping: $module is not installed\n";
        exit;
      }
  }

if( $XML::Simple::VERSION < 2.09) 
  { print "1..1\nok 1\n";
    warn "skipping: need XML::Simple 2.09 or above\n";
    exit;
  }

$XML::Simple::PREFERRED_PARSER= 'XML::Parser';  

$/="\n\n";
my @doc= <DATA>;

my @options= ( { },
               { content_key => 'foo' },
               { group_tags => { templates => 'template'} },
               { group_tags => { dirs => 'dir', templates => 'template'} },
               { forcearray => 1 },
               { forcearray => [ qw(server) ] },
               { noattr => 1, },
               { content_key => 'mycontent' },
               { content_key => '-mycontent' },
               { var_attr => 'var' },
               { var_attr => 'var', var_regexp => qr/\$\{?(\w+)\}?/ },
               { variables => { var => 'foo' } },
               { keyattr => [ qw(name)] },
               { keyattr => [ 'name' ] },
               { keyattr => [ qw(foo bar)] },
               { keyattr => {server => 'name' } },
               { keyattr => {server => '+name' } },
               { keyattr => {server => '-name' } },
             );

plan( tests => @options * @doc);

foreach my $doc (@doc)
  { foreach my $options (@options)
      { (my $options_text= Dumper( $options))=~ s{\s*\n\s*}{ }g;
        $options_text=~ s{^\$VAR1 = }{};
        my $t        = XML::Twig->new->parse( $doc);
        my $twig     = $t->root->simplify( %$options);
        my $doc_name = $t->root->att( 'doc');
        my %simple_options= %$options;
        delete $simple_options{var_regexp};
        my $simple   = XMLin( $doc, %simple_options); 
        my $res=is_deeply( $twig, $simple, "doc: $doc_name - options: $options_text" . Dump( {twig => $twig, simple => $simple}));
        exit unless( $res);
      }
  } 

__DATA__
<config doc="XML::Simple example" logdir="/var/log/foo/" debugfile="/tmp/foo.debug">
  <server name="sahara" osname="solaris" osversion="2.6">
    <address>10.0.0.101</address>
    <address>10.0.1.101</address>
  </server>
  <server name="gobi" osname="irix" osversion="6.5">
    <address>10.0.0.102</address>
  </server>
  <server name="kalahari" osname="linux" osversion="2.0.34">
    <address>10.0.0.103</address>
    <address>10.0.1.103</address>
  </server>
</config>

<config doc="example from XML::Twig" host="laptop.xmltwig.com">
  <server>localhost</server>
  <dirs>
    <dir name="base">/home/mrodrigu/standards</dir>
    <dir name="tools">${base}/tools</dir>
  </dirs>
  <templates>
    <template name="std_def">std_def.templ</template>
    <template name="dummy">dummy</template>
  </templates>
</config>

<doc doc="simple example with variables"><var var="var">foo</var><string>var is ${var}</string></doc>

