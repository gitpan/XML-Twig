#!/bin/perl

# $Id: zz_dump_config.t,v 1.3 2004/03/15 16:37:10 mrodrigu Exp $

my $ok; # global, true if the last call to version found the module, false otherwise
use Config;

warn "\n\nConfiguration:\n\n";

# required
warn "perl: $]\n";
warn "OS: $Config{'osname'} - $Config{'myarchname'}\n";
warn version( XML::Parser);

# try getting this info
my $xmlwf_v= `xmlwf -v`;
if( $xmlwf_v=~ m{xmlwf using expat_(.*)$}m)
  { warn format_warn( 'expat', $1); }
else
  { warn format_warn( 'expat', '<no version information found>'); }

# must-have
warn version( Scalar::Util);
unless( $ok) { warn version( WeakRef); }

# encoding
warn version( Encode);
unless( $ok) { warn version( Text::Iconv); }
unless( $ok) { warn version( Unicode::Map8); }

# optional
warn version( LWP);
warn version( HTML::Entities);
warn version( Tie::IxHash);
warn version( XML::XPath);

# used in tests
warn version( Test);
warn version( Test::Pod);
warn version( XML::Simple);
warn version( XML::Handler::YAWriter);
warn version( XML::SAX::Writer);
warn version( IO::Scalar);

warn "\n\nPlease add this information to bug reports (you can run t/zz_dump_config.t to get it)\n\n";

print "1..1\nok 1\n";
exit;

sub version
  { my $module= shift;
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
    return format_warn( $module, $version);
  }

sub format_warn
  { return  sprintf( "%-25s: %s\n", @_); }
