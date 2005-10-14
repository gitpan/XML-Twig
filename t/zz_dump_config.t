#!/bin/perl

# $Id: zz_dump_config.t,v 1.8 2005/10/14 16:14:48 mrodrigu Exp $

my $ok; # global, true if the last call to version found the module, false otherwise
use Config;

warn "\n\nConfiguration:\n\n";

# required
warn "perl: $]\n";
warn "OS: $Config{'osname'} - $Config{'myarchname'}\n";
warn version( XML::Parser, 'required');

# try getting this info
my $xmlwf_v= `xmlwf -v`;
if( $xmlwf_v=~ m{xmlwf using expat_(.*)$}m)
  { warn format_warn( 'expat', $1, '(required)'); }
else
  { warn format_warn( 'expat', '<no version information found>'); }

# must-have
warn version( Scalar::Util, 'for improved memory management');
if( $ok)
  { unless( defined( &Scalar::Util::weaken))
      { warn format_warn( '', 'NOT USED, weaken not available in this version');
        warn version( WeakRef); 
      }
  }
else
  { warn version( WeakRef, 'for improved memory management'); }

# encoding
warn version( Encode, 'for encoding conversions');
unless( $ok) { warn version( Text::Iconv, 'for encoding conversions'); }
unless( $ok) { warn version( Unicode::Map8, 'for encoding conversions'); }

# optional
warn version( LWP, 'for the parseurl method');
warn version( HTML::Entities, 'for the html_encode filter');
warn version( Tie::IxHash, 'for the keep_atts_order option');
warn version( XML::XPath, 'to use XML::Twig::XPath');
warn version( HTML::TreeBuilder, 'to use parse_html and parsefile_html');

# used in tests
warn version( Test, 'for testing purposes');
warn version( Test::Pod, 'for testing purposes');
warn version( XML::Simple, 'for testing purposes');
warn version( XML::Handler::YAWriter, 'for testing purposes');
warn version( XML::SAX::Writer, 'for testing purposes');
warn version( XML::Filter::BufferText, 'for testing purposes');
warn version( IO::Scalar, 'for testing purposes');

warn "\n\nPlease add this information to bug reports (you can run t/zz_dump_config.t to get it)\n\n";

print "1..1\nok 1\n";
exit 0;

sub version
  { my $module= shift;
    my $info= shift || '';
    $info &&= "($info)";
    my $version;
    if( eval "require $module")
      { $ok=1;
        import $module;
        $version= ${"$module\::VERSION"};
      }
    else
      { $ok=0;
        $version= '<not available>';
      }
    return format_warn( $module, $version, $info);
  }

sub format_warn
  { return  sprintf( "%-25s: %16s %s\n", @_); }
