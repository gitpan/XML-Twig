# XML::Twig 3.00.37 Twig.pm.slow - 2002-01-09
#
# Copyright (c) 1999-2002 Michel Rodriguez
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#

# This is created in the caller's space
BEGIN
  {sub ::PCDATA { '#PCDATA' } 
   sub ::CDATA  { '#CDATA'  } 
  }

######################################################################
package XML::Twig;
######################################################################

require 5.004;

use strict; 
use vars qw($VERSION @ISA);
use Carp;


# constants: element types
use constant (PCDATA  => '#PCDATA');
use constant (CDATA   => '#CDATA');
use constant (PI      => '#PI');
use constant (COMMENT => '#COMMENT');
use constant (ENT     => '#ENT');

# element classes
use constant (ELT     => '#ELT');
use constant (TEXT    => '#TEXT');

# element properties
use constant (ASIS    => '#ASIS');
use constant (EMPTY   => '#EMPTY');

# used in parseurl to set the buffer size to the same size as in XML::Parser::Expat
use constant (BUFSIZE => 32768);

# used to store the gi's
my %gi2index;   # gi => index
my @index2gi;   # list of gi's
my $SPECIAL_GI; # first non-special gi;
my %base_ent;   # base entity character => replacement

# flag, set to true if the WeakRef module is available
use vars qw( $weakrefs);

my $REG_NAME       = q{(?:[#a-zA-Z][#\w:.-]*)};         # xml name
my $REG_NAME_W     = q{(?:[#a-zA-Z][#\w:.-]*|\*)};      # name or wildcard (* or '')
my $REG_REGEXP     = q{(?:/(?:[^\\/]|\\.)*/[eimsox]*)}; # regexp
my $REG_REGEXP_EXP = q{(?:(?:[^\\/]|\\.)*)};            # content of a regexp
my $REG_REGEXP_MOD = q{(?:[eimso]*)};                   # regexp modifiers
my $REG_STRING     = q{(?:"(?:[^\\"]|\\.)*"|'(?:[^\\']|\\.)*')};  # string (simple or double quoted)

my $parser_version;

BEGIN
{ 
  $VERSION = '3.00.37';

  use XML::Parser;
  my $needVersion = '2.23';
  $parser_version= $XML::Parser::VERSION;
  croak "need at least XML::Parser version $needVersion"
    unless $parser_version >= $needVersion;


  # test whether we can use weak references
  if( eval 'require WeakRef')
    { import WeakRef;
      $weakrefs= 1;
    } 
  # warn "weak references used\n" if( $weakrefs);

  import XML::Twig::Elt;
  import XML::Twig::Entity;
  import XML::Twig::Entity_list;

  # used to store the gi's
  # should be set for each twig really, at least when there are several
  # the init ensures that special gi's are always the same

  # gi => index
  # do NOT use => or the constants become quoted!
  %XML::Twig::gi2index=( PCDATA, 0, CDATA, 1, PI, 2, COMMENT, 3, ENT, 4); 
  # list of gi's
  @XML::Twig::index2gi=( PCDATA, CDATA, PI, COMMENT, ENT);

  # gi's under this value are special 
  $XML::Twig::SPECIAL_GI= @XML::Twig::index2gi;
  
  %XML::Twig::base_ent= ( '>' => '&gt;',
               '<' => '&lt;',
               '&' => '&amp;',
               "'" => '&apos;',
               '"' => '&quot;',
             );

  # now set some aliases
  *find_nodes = *get_xpath;
  *getElementsByTagName= *descendants;
  *descendants_or_self= *descendants;
}

@ISA = qw(XML::Parser);

# fake gi's used in twig_handlers and start_tag_handlers
my $ALL    = '_all_';     # the associated function is always called
my $DEFAULT= '_default_'; # the function is called if no other handler has been

# some defaults
my $COMMENTS_DEFAULT= 'keep';
my $PI_DEFAULT      = 'keep';


# handlers used in regular mode
my %twig_handlers=( Start      => \&twig_start, 
                    End        => \&twig_end, 
                    Char       => \&twig_char, 
                    Entity     => \&twig_entity, 
                    XMLDecl    => \&twig_xmldecl, 
                    Doctype    => \&twig_doctype, 
                    Element    => \&twig_element, 
                    Attlist    => \&twig_attlist, 
                    CdataStart => \&twig_cdatastart, 
                    CdataEnd   => \&twig_cdataend, 
                    Proc       => \&twig_pi,
                    Comment    => \&twig_comment,
                  );

# handlers used when twig_roots is used and we are outside of the roots
my %twig_handlers_roots=
      ( Start      => \&twig_start_check_roots, 
        End        => \&twig_end_check_roots, 
        Doctype    => \&twig_doctype, 
        Char       => undef, Entity     => undef, XMLDecl    => undef, 
        Element    => undef, Attlist    => undef, CdataStart => undef, 
        CdataEnd   => undef, Proc       => undef, Comment    => undef, 
	Default    => undef,
      );

# handlers used when twig_roots and print_outside_roots are used and we are
# outside of the roots
my %twig_handlers_roots_print_2_30=
      ( Start      => \&twig_start_check_roots_print, 
        End        => \&twig_end_check_roots_print, 
        Char       => \&twig_print, 
        # I have no idea why I should not be using this handler!
        #Entity     => \&twig_print_entity, 
        XMLDecl    => \&twig_print,
        # Element    => \&twig_print, Attlist    => \&twig_print, 
        CdataStart => \&twig_print, CdataEnd   => \&twig_print, 
        Proc       => \&twig_print, Comment    => \&twig_print, 
        Default    => \&twig_print, 
      );

# handlers used when twig_rootsi, print_outside_roots and keep_encoding are used
# and we are outside of the roots
my %twig_handlers_roots_print_original_2_30=
      ( Start      => \&twig_start_check_roots_print_original, 
        End        => \&twig_end_check_roots_print_original, 
        Char       => \&twig_print_original, 
        # I have no idea why I should not be using this handler!
        Entity    => \&twig_print_original, 
        XMLDecl    => \&twig_print_original, 
        Element    => \&twig_print_original, Attlist   => \&twig_print_original,
        CdataStart => \&twig_print_original, CdataEnd  => \&twig_print_original,
        Proc       => \&twig_print_original, Comment   => \&twig_print_original,
        Default    => \&twig_print_original, 
      );

# handlers used when twig_roots and print_outside_roots are used and we are
# outside of the roots
my %twig_handlers_roots_print_2_27=
      ( Start      => \&twig_start_check_roots_print, 
        End        => \&twig_end_check_roots_print, 
        Char       => \&twig_print, 
        # I have no idea why I should not be using this handler!
        Entity     => \&twig_print, 
        XMLDecl    => \&twig_print, Doctype    => \&twig_print, 
        CdataStart => \&twig_print, CdataEnd   => \&twig_print, 
        Proc       => \&twig_print, Comment    => \&twig_print, 
        Default    => \&twig_print, 
      );

# handlers used when twig_roots, print_outside_roots and keep_encoding are used
# and we are outside of the roots
my %twig_handlers_roots_print_original_2_27=
      ( Start      => \&twig_start_check_roots_print_original, 
        End        => \&twig_end_check_roots_print_original, 
        Char       => \&twig_print_original, 
        # for some reason original_string is wrong here 
        # this can be a problem if the doctype includes non ascii characters
        XMLDecl    => \&twig_print, Doctype    => \&twig_print,
        # I have no idea why I should not be using this handler!
        # Entity     => \&twig_print, 
        CdataStart => \&twig_print_original, CdataEnd  => \&twig_print_original,
        Proc       => \&twig_print_original, Comment   => \&twig_print_original,
        Default    => \&twig_print_default, #  twig_print_original does not work
      );


my %twig_handlers_roots_print= $parser_version > 2.27 
                               ? %twig_handlers_roots_print_2_30 
                               : %twig_handlers_roots_print_2_27; 
my %twig_handlers_roots_print_original= $parser_version > 2.27 
                                    ? %twig_handlers_roots_print_original_2_30 
                                    : %twig_handlers_roots_print_original_2_27; 


# handlers used when the finish_print method has been called
my %twig_handlers_finish_print=
      ( Start      => \&twig_print, 
        End        => \&twig_print_end, Char       => \&twig_print, 
        Entity     => \&twig_print, XMLDecl    => \&twig_print, 
        Doctype    => \&twig_print, Element    => \&twig_print, 
        Attlist    => \&twig_print, CdataStart => \&twig_print, 
        CdataEnd   => \&twig_print, Proc       => \&twig_print, 
        Comment    => \&twig_print, Default    => \&twig_print, 
      );

# handlers used when the finish_print method has been called and the keep_encoding
# option is used
my %twig_handlers_finish_print_original=
      ( Start      => \&twig_print_original, End      => \&twig_print_end_original, 
        Char       => \&twig_print_original, Entity   => \&twig_print_original, 
        XMLDecl    => \&twig_print_original, Doctype  => \&twig_print_original, 
        Element    => \&twig_print_original, Attlist  => \&twig_print_original, 
        CdataStart => \&twig_print_original, CdataEnd => \&twig_print_original, 
        Proc       => \&twig_print_original, Comment  => \&twig_print_original, 
        Default    => \&twig_print_original, 
      );

# handlers used whithin ignored elements
my %twig_handlers_ignore=
      ( Start      => \&twig_ignore_start, 
        End        => \&twig_ignore_end, 
        Char       => undef, Entity     => undef, XMLDecl    => undef, 
        Doctype    => undef, Element    => undef, Attlist    => undef, 
        CdataStart => undef, CdataEnd   => undef, Proc       => undef, 
        Comment    => undef, Default    => undef,
      );


# those handlers are only used if the entities are NOT to be expanded
my %twig_noexpand_handlers= ( Default => \&twig_default );

my @saved_default_handler;

my $ID= 'id'; # default value, set by the Id argument

# all allowed options
my %valid_option=
    ( # XML::Twig options
      TwigHandlers          => 1, Id                    => 1,
      TwigRoots             => 1, TwigPrintOutsideRoots => 1,
      StartTagHandlers      => 1, EndTagHandlers        => 1,
      IgnoreTags            => 1,
      CharHandler           => 1, KeepEncoding          => 1,
      ParseStartTag         => 1, 
      LoadDTD               => 1, DTDHandler            => 1,
      DoNotOutputDTD        => 1, ExpandExternalEnts    => 1,
      DiscardSpaces         => 1, KeepSpaces            => 1, 
      DiscardSpacesIn       => 1, KeepSpacesIn          => 1, 
      PrettyPrint           => 1, EmptyTags             => 1, 
      Comments              => 1, Pi                    => 1, 
      OutputFilter          => 1, InputFilter           => 1,
      # XML::Parser options
      ErrorContext          => 1, ProtocolEncoding      => 1,
      Namespaces            => 1, NoExpand              => 1,
      Stream_Delimiter      => 1, ParseParamEnt         => 1,
      NoLWP                 => 1, Non_Expat_Options     => 1,
    );

# predefined iinput and output filters
use vars qw( %filter);
%filter= ( html   => \&html_encode,
           safe   => \&safe_encode,
         );

1;


sub new
  { my ($class, %args) = @_;
    my $handlers;

    # cahnge all nice_perlish_names into nicePerlishNames
    %args= normalize_args( %args);

    # check options
    unless( $args{MoreOptions})
      { foreach my $arg (keys %args)
        { carp "illegal option $arg" unless $valid_option{$arg}; }
      }
     
    # a twig is really an XML::Parser
    # my $self= XML::Parser->new(%args);
    my $self;
    $self= XML::Parser->new(%args);   
    
    bless $self, $class;

    if( exists $args{TwigHandlers})
      { $handlers= $args{TwigHandlers};
        $self->setTwigHandlers( $handlers);
        delete $args{TwigHandlers};
      }

    # take care of twig-specific arguments
    if( exists $args{StartTagHandlers})
      { $self->setStartTagHandlers( $args{StartTagHandlers});
        delete $args{StartTagHandlers};
      }

    if(  exists $args{IgnoreTags})
      { $self->setIgnoreTagsHandlers( $args{IgnoreTags});
        delete $args{IgnoreTags};
      }


    $self->{twig_dtd_handler}= $args{DTDHandler};
    delete $args{DTDHandler};
    $self->{twig_char_handler}= $args{CharHandler};
    delete $args{CharHandler};

    if( $args{LoadDTD})
      { $self->{twig_read_external_dtd}= 1;
        delete $args{LoadDTD};
      }
      
    if( $args{ExpandExternalEnts})
      { $self->set_expand_external_entities( 1);
        $self->{twig_read_external_dtd}= 1; # implied by ExpandExternalEnts
        delete $args{LoadDTD};
        delete $args{ExpandExternalEnts};
      }

    # deal with TwigRoots argument, a hash of elements for which
    # subtrees will be built (and associated handlers)
     
    if( $args{TwigRoots})
      { $self->setTwigRoots( $args{TwigRoots});
        delete $args{TwigRoots}; 
      }
    
    if( exists $args{EndTagHandlers})
      { croak "cannot use EndTagHandlers without TwigRoots"
          unless ($self->{twig_roots});
        $self->setEndTagHandlers( $args{EndTagHandlers});
        delete $args{EndTagHandlers};
      }
      
    if( $args{TwigPrintOutsideRoots})
      { croak "cannot use TwigPrintOutsideRoots without TwigRoots"
          unless( $self->{twig_roots});
        $self->{twig_default_print}= $args{TwigPrintOutsideRoots};
      }

    if( $args{PrettyPrint})
      { $self->set_pretty_print( $args{PrettyPrint}); }

    if( $args{EmptyTags})
      { $self->set_empty_tag_style( $args{EmptyTags}); }

    # space policy
    if( $args{KeepSpaces})
      { croak "cannot use both keep_spaces and discard_spaces"
          if( $args{DiscardSpaces});
        croak "cannot use both keep_spaces and keep_spaces_in"
          if( $args{KeepSpacesIn});
        $self->{twig_keep_spaces}=1;
        delete $args{KeepSpaces}; 
      }
    if( $args{DiscardSpaces})
      { croak "cannot use both discard_spaces and keep_spaces_in"
          if( $args{KeepSpacesIn});
        $self->{twig_discard_spaces}=1; 
        delete $args{DiscardSpaces}; 
      }
    if( $args{KeepSpacesIn})
      { croak "cannot use both keep_spaces_in and discard_spaces_in"
          if( $args{DiscardSpacesIn});
        $self->{twig_discard_spaces}=1; 
        $self->{twig_keep_spaces_in}={}; 
        my @tags= @{$args{KeepSpacesIn}}; 
        foreach my $tag (@tags)
          { $self->{twig_keep_spaces_in}->{$tag}=1; } 
        delete $args{KeepSpacesIn}; 
      }
    if( $args{DiscardSpacesIn})
      { $self->{twig_keep_spaces}=1; 
        $self->{twig_discard_spaces_in}={}; 
        my @tags= @{$args{DiscardSpacesIn}};
        foreach my $tag (@tags)
          { $self->{twig_discard_spaces_in}->{$tag}=1; } 
        delete $args{DiscardSpacesIn}; 
      }
    # discard spaces by default 
    $self->{twig_discard_spaces}= 1 unless(  $self->{twig_keep_spaces});

    $args{Comments}||= $COMMENTS_DEFAULT;
    if( $args{Comments} eq 'drop')
      { delete $twig_handlers{Comment}; }
    elsif( $args{Comments} eq 'keep')
      { $self->{twig_keep_comments}= 1; }
    elsif( $args{Comments} ne 'process')
      { croak "wrong value for comments argument: $args{Comments}"; }
    delete $args{Comments};

    $args{Pi}||= $PI_DEFAULT;
    if( $args{Pi} eq 'drop')
      { delete $twig_handlers{Pi}; }
    elsif( $args{Pi} eq 'keep')
      { $self->{twig_keep_pi}= 1; }
    elsif( $args{Pi} ne 'process')
      { croak "wrong value for Pi argument: $args{Pi}"; }
    delete $args{Pi};

    if( $args{KeepEncoding})
      { $self->{twig_keep_encoding}= $args{KeepEncoding};
	# set it in XML::Twig::Elt so print functions know what to do
        $self->set_keep_encoding( 1); 
        $self->{parse_start_tag}= $args{ParseStartTag} || \&parse_start_tag; 
        delete $args{ParseStartTag} if defined( $args{ParseStartTag}) ;
        delete $args{KeepEncoding};
	$self->{NoExpand}= 1;
      }
    else
      { $self->set_keep_encoding( 0); }

    if( $args{OutputFilter})
      { $self->set_output_filter( $args{OutputFilter}); 
        delete $args{OutputFilter};
      }
    else
      { $self->set_output_filter( 0); }

    if( $args{InputFilter})
      { $self->set_input_filter(  $args{InputFilter}); delete  $args{InputFilter}; }

    if( exists $args{Id}) { $ID= $args{Id}; delete $args{ID}; }

    if( $args{NoExpand})
      { $self->setHandlers( %twig_noexpand_handlers);
        $self->{twig_no_expand}=1;
      }

    if( $args{DoNotOutputDTD})
      { $self->{no_dtd_output}= 1; 
        delete $args{DoNotOutputDTD}; 
      }
     
    # set handlers
    if( $self->{twig_roots})
      { if( $self->{twig_default_print})
          { if( $self->{twig_keep_encoding})
              { $self->setHandlers( %twig_handlers_roots_print_original); }
            else
              { $self->setHandlers( %twig_handlers_roots_print);  }
          }
        else
          { $self->setHandlers( %twig_handlers_roots); }
      }
    else
      { $self->setHandlers( %twig_handlers); }

    # XML::Parser::Expat does not like these handler to be set. So in order to 
    # use the various sets of handlers on XML::Parser or XML::Parser::Expat
    # objects when needed, these ones have to be set only once, here, at 
    # XML::Parser level
    $self->setHandlers( Init => \&twig_init, Final => \&twig_final);

    $self->{twig_entity_list}= XML::Twig::Entity_list->new; 

    $self->{twig_id}= $ID; 
    $self->{twig_stored_spaces}='';

    $self->{twig}= $self;
    weaken( $self->{twig}) if( $weakrefs);

    return $self;
  }


# I should really add extra options to allow better configuration of the 
# LWP::UserAgent object
# this method forks: 
#   - the child gets the data and copies it to the pipe,
#   - the parent reads the stream and sends it to XML::Parser
# the data is cut it chunks the size of the XML::Parser::Expat buffer
sub parseurl
  { my( $t, $url, $agent)= @_;
    pipe( README, WRITEME) or croak  "cannot create connected pipes: $!";
    if( my $pid= fork)
      { # parent code: parse the incoming file
        close WRITEME; # no need to write
        $t->parse( \*README);
        close README;
      }
    else
     { # child
	close README; # no need to read
	require LWP;  # so we can get LWP::UserAgent and HTTP::Request
	$|=1;
        $agent    ||= LWP::UserAgent->new;
	my $request  = HTTP::Request->new( GET => $url);
        # pass_url_content is called with chunks of data the same size as
        # the XML::Parser buffer
        my $response = $agent->request( $request, 
	                 sub { pass_url_content( \*WRITEME, @_); }, BUFSIZE);
        $response->is_success or croak "$url ", $response->message, "\n";
	close WRITEME;
      }
  }

# get the (hopefully!) XML data from the URL and 
sub pass_url_content
  { my( $fh, $data, $response, $protocol)= @_;
    print $fh $data;
  }

sub add_options
  { my %args= map { $_, 1 } @_;
    %args= normalize_args( %args);
    $valid_option{$_}++ foreach (keys %args);
  }

sub twig_store_internal_dtd
  { my( $p, $string)= @_;
    my $t= $p->{twig};
    $string= $p->original_string() if( $t->{twig_keep_encoding});
    # print STDERR "internal: $string\n";
    $t->{twig_doctype}->{internal} .= $string;
  }

sub twig_stop_storing_internal_dtd
  { my $p= shift;
    # print STDERR "\ntwig_stop_storing_internal_dtd called\n";
     if( @saved_default_handler && defined $saved_default_handler[1])
       { # print STDERR "restoring saved handlers for";
         while( @saved_default_handler) 
	   { # print STDERR shift( @saved_default_handler) . " "; 
	     shift @saved_default_handler;
	   }
         $p->setHandlers( @saved_default_handler); }
     else
       {  # print STDERR "resetting Default handler\n";
         my $t= $p->{twig};
	 $t->setHandlers( Default => undef);
	 $p->setHandlers( Default => undef);
       }
  }


sub normalize_args
  { my %normalized_args;
    while( my $key= shift )
      { $key= join '', map { ucfirst } split /_/, $key;
        #$key= "Twig".$key unless( substr( $key, 0, 4) eq 'Twig');
        $normalized_args{$key}= shift ;
      }
    return %normalized_args;
  }    


sub set_handler
  { my( $handlers, $path, $handler)= @_;

    $handlers ||= {}; # create the handlers struct if necessary

    my $prev_handler= $handlers->{handlers}->{$path} || undef;

       set_gi_handler              ( $handlers, $path, $handler, $prev_handler)
    || set_path_handler            ( $handlers, $path, $handler, $prev_handler)
    || set_subpath_handler         ( $handlers, $path, $handler, $prev_handler)
    || set_special_handler         ( $handlers, $path, $handler, $prev_handler)
    || set_attribute_handler       ( $handlers, $path, $handler, $prev_handler)
    || set_star_att_handler        ( $handlers, $path, $handler, $prev_handler)
    || set_string_handler          ( $handlers, $path, $handler, $prev_handler)
    || set_attribute_regexp_handler( $handlers, $path, $handler, $prev_handler)
    || set_string_regexp_handler   ( $handlers, $path, $handler, $prev_handler)
    || set_pi_handler              ( $handlers, $path, $handler, $prev_handler)
    || croak "unrecognized expression in handler: $path";


    # this both takes care of the simple (gi) handlers and store
    # the handler code reference for other handlers
    $handlers->{handlers}->{$path}= $handler;

    return $prev_handler;
  }


sub set_gi_handler
  { my( $handlers, $path, $handler, $prev_handler)= @_;
    if( $path =~ m{^\s*($REG_NAME)\s*$}o )
      { my $gi= $1;
        # print STDERR "gi handler found: $gi\n";
        $handlers->{handlers}->{gi}->{$gi}= $handler; 
        return 1;
      }
    else 
      { return 0; 
      }
  }

sub set_special_handler
  { my( $handlers, $path, $handler, $prev_handler)= @_;
    if( $path =~ m{^\s*($ALL|$DEFAULT)\s*$}o )
      { $handlers->{handlers}->{$1}= $handler; 
        return 1;
      }
    else 
      { return 0; 
      }
  }
	
sub set_path_handler
  { my( $handlers, $path, $handler, $prev_handler)= @_;
    if( $path=~ m{^\s*(?:/$REG_NAME)*/($REG_NAME)\s*$}o)
      { # a full path has been defined
        # update the path_handlers count, knowing that
        # either the previous or the new handler can be undef
        $handlers->{path_handlers}->{$1}-- if( $prev_handler);
        $handlers->{path_handlers}->{$1}++ if( $handler);
        return 1;
      }
    else 
      { return 0; 
      }
  }


sub set_subpath_handler
  { my( $handlers, $path, $handler, $prev_handler)= @_;
    if( $path=~ m{^\s*(?:$REG_NAME/)+($REG_NAME)\s*$}o)
      { # a partial path has been defined
        $handlers->{subpath_handlers}->{$1}-- if( $prev_handler);
        $handlers->{subpath_handlers}->{$1}++ if( $handler);
        return 1;
      }
    else 
      { return 0; 
      }
  }

sub set_attribute_handler
  { my( $handlers, $path, $handler, $prev_handler)= @_;
    # check for attribute conditions
    if( $path=~ m{^\s*($REG_NAME)          # elt
                 \s*\[\s*\@                #    [@
                 ($REG_NAME)\s*            #      att
                 (?:=\s*($REG_STRING)\s*)? #           = value (optional)         
                 \]\s*$}xo)                #                             ]  
      { my( $gi, $att, $val)= ($1, $2, $3);
        $val= substr( $val, 1, -1) if( defined $val); # remove the quotes
        if( $prev_handler)
          { # replace or remove the previous handler
            my $i=0; # so we can splice the array if need be
            foreach my $exp ( @{$handlers->{attcond_handlers_exp}->{$gi}})
             { if( ($exp->{att} eq $att) && ($exp->{val} eq $val) )
                 { if( $handler) # just replace the handler
                     { $exp->{handler}= $handler; }
                   else          # remove the handler
                     { $handlers->{attcond_handlers}->{$gi}--;
                       splice( @{$handlers->{attcond_handlers_exp}->{$gi}}, $i, 1);
                       last;
                     }
                 }
               $i++;
             }
          }
        elsif( $handler)
          { # new handler only
	    $handlers->{attcond_handlers}->{$gi}++;
            my $exp={att => $att, val => $val, handler => $handler};
            $handlers->{attcond_handlers_exp}->{$gi} ||= [];
            push @{$handlers->{attcond_handlers_exp}->{$gi}}, $exp;
	  }
        return 1;
      }
    else 
      { return 0; 
      }
  }


sub set_attribute_regexp_handler
  { my( $handlers, $path, $handler, $prev_handler)= @_;
    # check for attribute regexp conditions
    if( $path=~ m{^\s*($REG_NAME)     # elt
                 \s*\[\s*\@           #    [@
                 ($REG_NAME)          #      att
                 \s*=~\s*             #          =~
		 /($REG_REGEXP_EXP)/  #             /regexp/
		 ($REG_REGEXP_MOD)    #                     mods
                 \s*]\s*$}gxo)        #                         ] 
      { my( $gi, $att, $regexp, $mods)= ($1, $2, $3, $4);
        $regexp= qr/(?$mods:$regexp)/;
        # print STDERR "\ngi: $gi - att: $att - regexp: $regexp\n";
        if( $prev_handler)
          { # replace or remove the previous handler
            my $i=0; # so we can splice the array if need be
            foreach my $exp ( @{$handlers->{attregexp_handlers_exp}->{$gi}})
             { if( ($exp->{att} eq $att) && ($exp->{regexp} eq $regexp) )
                 { if( $handler) # just replace the handler
                     { $exp->{handler}= $handler; }
                   else          # remove the handler
                     { $handlers->{attregexp_handlers}->{$gi}--;
                       splice( @{$handlers->{attregexp_handlers_exp}->{$gi}}, $i, 1);
                       last;
                     }
                 }
               $i++;
             }
          }
        elsif( $handler)
          { # new handler only
	    $handlers->{attregexp_handlers}->{$gi}++;
            my $exp={att => $att, regexp => $regexp, handler => $handler};
            $handlers->{attregexp_handlers_exp}->{$gi} ||= [];
            push @{$handlers->{attregexp_handlers_exp}->{$gi}}, $exp;
          }
        return 1;
      }
    else 
      { return 0; 
      }
  }

sub set_string_handler
  { my( $handlers, $path, $handler, $prev_handler)= @_;
    # check for string conditions
    if( $path=~/^\s*($REG_NAME)           # elt
                 \s*\[\s*string           #    [string
		 \s*\(\s*($REG_NAME)?\s*\)#           (sub_elt)
                 \s*=\s*                  #                     =
                 ($REG_STRING)            #                       "text" (or 'text')
                 \s*\]\s*$/ox)           #                              ] 
      { my( $gi, $sub_elt, $text)= ($1, $2, $3);
        $text= substr( $text, 1, -1) if( defined $text); # remove the quotes
        if( $prev_handler)
          { # replace or remove the previous handler
            my $i=0; # so we can splice the array if need be
            foreach my $exp ( @{$handlers->{text_handlers_exp}->{$gi}})
             { if( ($exp->{text} eq $text) &&
                   ( !$exp->{sub_elt} || ($exp->{sub_elt} eq $sub_elt) )
                 )
                 { if( $handler) # just replace the handler
                     { $exp->{handler}= $handler; }
                   else          # remove the handler
                     { $handlers->{text_handlers}->{$gi}--;
                       splice( @{$handlers->{text_handlers_exp}->{$gi}}, $i, 1);
                       last;
                     }
                 }
               $i++;
             }
          }
        elsif( $handler)
          { # new handler only
	    $handlers->{text_handlers}->{$gi}++;
            my $exp={sub_elt => $sub_elt, text => $text, handler => $handler};
            $handlers->{text_handlers_exp}->{$gi} ||= [];
            push @{$handlers->{text_handlers_exp}->{$gi}}, $exp;
          }
        return 1;
      }
    else 
      { return 0; 
      }
  }


sub set_string_regexp_handler
  { my( $handlers, $path, $handler, $prev_handler)= @_;
    # check for string regexp conditions
    if( $path=~m{^\s*($REG_NAME)        # elt
                 \s*\[\s*string         #    [string
		 \s*\(\s*($REG_NAME?)\) #           (sub_elt)
                 \s*=~\s*               #              =~ 
                 /$REG_REGEXP_EXP/      #                 /regexp/
                 \s*($REG_REGEXP_MOD)?  #                         mods
                 \s*\]\s*$}ox)         #                             ]   (or ')
      { my( $gi, $sub_elt, $regexp, $mods)= ($1, $2, $3, $4);
        $mods||="";
        $regexp= qr/(?$mods:$regexp)/;
        if( $prev_handler)
          { # replace or remove the previous handler
            my $i=0; # so we can splice the array if need be
            foreach my $exp ( @{$handlers->{regexp_handlers_exp}->{$gi}})
             { if( ($exp->{regexp} eq $regexp) &&
                   ( !$exp->{sub_elt} || ($exp->{sub_elt} eq $sub_elt) )
                 )
                 { if( $handler) # just replace the handler
                     { $exp->{handler}= $handler;  
                     }
                   else          # remove the handler
                     { $handlers->{regexp_handlers}->{$gi}--;
                       splice( @{$handlers->{regexp_handlers_exp}->{$gi}}, $i, 1);
                       last;
                     }
                 }
               $i++;
             }
          }
        elsif( $handler)
          { # new handler only
	    $handlers->{regexp_handlers}->{$gi}++;
            my $exp= {sub_elt => $sub_elt, regexp => $regexp, handler => $handler};
            $handlers->{regexp_handlers_exp}->{$gi} ||= [];
            push @{$handlers->{regexp_handlers_exp}->{$gi}}, $exp;
          }
        return 1;
      }
    else 
      { return 0; 
      }
  }


sub set_star_att_handler
  { my( $handlers, $path, $handler, $prev_handler)= @_;
    # check for *[@att="val"] or *[@att] conditions
    if( $path=~/^(?:\s*\*)?         # * (optionnal)
                 \s*\[\s*\@         #    [@
                 ($REG_NAME)        #      att
                 (?:\s*=\s*         #         = 
                 ($REG_STRING))?      #           string
                     \s*\]\s*$/ox)  #                 ]  
      { my( $att, $val)= ($1, $2);
        $val= substr( $val, 1, -1) if( defined $val); # remove the quotes from the string
        # print STDERR "star att handler: $path -> $att - ",$val || '', "\n";
        if( $prev_handler)
          { # replace or remove the previous handler
            my $i=0; # so we can splice the array if need be
            foreach my $exp ( @{$handlers->{att_handlers_exp}->{$att}})
             { if( ($exp->{att} eq $att) && ( !defined( $val) || ($exp->{val} eq $val) ) )
                 { if( $handler) # just replace the handler
                     { $exp->{handler}= $handler; }
                   else          # remove the handler
                     { splice( @{$handlers->{att_handlers_exp}->{$att}}, $i, 1);
                       last;
                     }
                 }
               $i++;
             }
          }
        elsif( $handler)
          { # new handler only
	    $handlers->{att_handlers}->{$att}++;
            my $exp={att => $att, val => $val, handler => $handler};
            $handlers->{att_handlers_exp}->{$att} ||= [];
            push @{$handlers->{att_handlers_exp}->{$att}}, $exp;
          }
        return 1;
      }
    else 
      { return 0; 
      }
  }


sub set_pi_handler
  { my( $handlers, $path, $handler, $prev_handler)= @_;
    # PI conditions ( '?target' => \&handler or '?' => \&handler
    if( $path=~ /^\s*\?\s*([^\s]*\s*)$/)
      { my $target= $1 || '';
        # update the path_handlers count, knowing that
        # either the previous or the new handler can be undef
        $handlers->{pi_handlers}->{$1}= $handler;
        return 1;
      }
    else 
      { return 0; 
      }
  }


sub reset_handlers
  { my $handlers= shift;
    delete $handlers->{handlers};
    delete $handlers->{path_handlers};
    delete $handlers->{subpath_handlers};
    $handlers->{attcond_handlers_exp}=[] if( $handlers->{attcond_handlers});
    delete $handlers->{attcond_handlers};
  }
  
sub set_handlers
  { my $handlers= shift || return;
    my $set_handlers= {};
    foreach my $path (keys %{$handlers})
      { set_handler( $set_handlers, $path, $handlers->{$path}); }
    return $set_handlers;
  }
    

sub setTwigHandler
  { my( $t, $path, $handler)= @_;
    return set_handler( $t->{twig_handlers}, $path, $handler);
  }

sub setTwigHandlers
  { my( $t, $handlers)= @_;
    my $previous_handlers= $t->{twig_handlers} || undef;
    reset_handlers( $t->{twig_handlers});
    $t->{twig_handlers}= set_handlers( $handlers);
    return $previous_handlers;
  }

sub setStartTagHandler
  { my( $t, $path, $handler)= @_;
    return set_handler( $t->{twig_starttag_handlers}, $path,$handler);
  }

sub setStartTagHandlers
  { my( $t, $handlers)= @_;
    my $previous_handlers= $t->{twig_starttag_handlers} || undef;
    reset_handlers( $t->{twig_starttag_handlers});
    $t->{twig_starttag_handlers}= set_handlers( $handlers);
    return $previous_handlers;
   }

sub setIgnoreTagsHandler
  { my( $t, $path)= @_;
    return set_handler( $t->{twig_ignore_tags_handlers}, $path, sub { $_->ignore} );
  }

sub setIgnoreTagsHandlers
  { my( $t, $handlers)= @_;
    my %handlers= map { $_, sub { $_->ignore(); } } @$handlers;
    my $previous_handlers= $t->{twig_ignore_tags_handlers} || undef;
    reset_handlers( $t->{twig_ignore_tags_handlers});
    $t->{twig_ignore_tags_handlers}= set_handlers( \%handlers);
    return $previous_handlers;
   }

sub setEndTagHandler
  { my( $t, $path, $handler)= @_;
    return set_handler( $t->{twig_endtag_handlers}, $path,$handler);
  }

sub setEndTagHandlers
  { my( $t, $handlers)= @_;
    my $previous_handlers= $t->{twig_endtag_handlers} || undef;
    reset_handlers( $t->{twig_endtag_handlers});
    $t->{twig_endtag_handlers}= set_handlers( $handlers);
    return $previous_handlers;
   }

# a little more complex: set the twig_handlers only if a code ref is given
sub setTwigRoots
  { my( $t, $handlers)= @_;
    my $previous_roots= $t->{twig_roots} || undef;
    reset_handlers($t->{twig_roots});
    $t->{twig_roots}= set_handlers( $handlers);
    foreach my $path (keys %{$handlers})
      { $t->{twig_handlers}||= {};
        set_handler( $t->{twig_handlers}, $path, $handlers->{$path})
          if( UNIVERSAL::isa( $handlers->{$path}, 'CODE')); 
      }
    return $previous_roots;
  }

# just store the reference to the expat object in the twig
sub twig_init
  { my $p= shift;
    my $t=$p->{twig};
    $t->{twig_parser}= $p; 
    weaken( $t->{twig_parser}) if( $weakrefs);
    $t->{twig_parsing}=1;
  }

# uses eval to catch the parser's death
sub safe_parse
  { my( $t, $str)= @_;
    eval { $t->parse( $str); } ;
    return $@ ? 0 : $t;
  }

sub safe_parsefile
  { my( $t, $file)= @_;
    eval { $t->parsefile( $file); } ;
    return $@ ? 0 : $t;
  }

sub safe_parseurl
  { my( $t, $url)= @_;
    eval { $t->parseurl( $url); } ;
    return $@ ? 0 : $t;
  }

# the default twig handlers, which build the tree
sub twig_start($$%)
  { my ($p, $gi, %att)  = @_;
    my $t=$p->{twig};
    # print STDERR "[start tag " . $p->original_string() ."]";
    # empty the stored pcdata (space stored in case they are really part of 
    # a pcdata element) or stored it if the space policy dictades so
    # create a pcdata element with the spaces if need be

    if( $t->{twig_stored_spaces})
      { if( $t->{twig_current}->is_pcdata)
          { $t->{twig_current}->append_pcdata($t->{twig_stored_spaces}); }
        else
	  { my $current_gi= $t->{twig_current}->gi;
            $t->{twig_space_policy}->{$current_gi}= space_policy( $t, $current_gi)
              unless defined( $t->{twig_space_policy}->{$current_gi});
            if( $t->{twig_space_policy}->{$current_gi})
              {     insert_pcdata( $t, $t->{twig_stored_spaces} ); }
            $t->{twig_stored_spaces}='';
	  }
      }

    my $parent= $t->{twig_current};

    # if we were parsing PCDATA then we exit the pcdata
    if( $t->{twig_in_pcdata})
      { $t->{twig_in_pcdata}= 0;
        delete $parent->{'twig_current'};
        $parent= $parent->{parent};
      }

    # if we choose to keep the encoding then we need to parse the tag
    if( $t->{twig_keep_encoding})
      { my $func = $t->{parse_start_tag};
        ($gi, %att)= &$func($p->original_string);
      }
    
    # filter the input data if need be  
    if( my $filter= $t->{twig_input_filter})
      { $gi= $filter->( $gi);
        %att= map { $filter->($_), $filter->($att{$_})} keys %att; 
      }

    my $elt= XML::Twig::Elt->new( $gi);
    $elt->{'att'}=  \%att;
 
    delete $parent->{'twig_current'} if( $parent);
    $t->{twig_current}= $elt;
    $elt->{'twig_current'}=1;


    if( $parent)
      { my $prev_sibling= $parent->{last_child};
        if( $prev_sibling) 
          { $prev_sibling->{next_sibling}=  $elt; 
            $elt->set_prev_sibling( $prev_sibling);
          }

        $elt->set_parent( $parent);
        $parent->{first_child}=  $elt unless( $parent->{first_child}); 
        $parent->set_last_child( $elt);
      }
    else 
      { # processing root
        $t->{twig_root}= $elt;
        $elt->{twig}= $t;
        weaken(  $elt->{twig}) if( $weakrefs);
        # call dtd handlerif need be
        $t->{twig_dtd_handler}->($t, $t->{twig_dtd})
          if( defined $t->{twig_dtd_handler});
	  
	# set this so we can catch external entities
        $twig_handlers{Default} = \&twig_default; 
        $t->setHandlers( Default => \&twig_default);
        $p->setHandlers( Default => \&twig_default);
        #$t->setHandlers( %twig_handlers);
          
      }
    
    if( $p->recognized_string=~ m{/>$}s) { $elt->{empty}=1; }

    $elt->{extra_data}= $t->{extra_data} if( $t->{extra_data});
    $t->{extra_data}='';

    # if the element is ID-ed then store that info
    my $id= $elt->{'att'}->{$ID};
    if( $id) { $t->{twig_id_list}->{$id}= $elt; }


    # call user handler if need be
    if( $t->{twig_starttag_handlers})
      { # call all appropriate handlers
        my @handlers= handler( $t, $t->{twig_starttag_handlers}, $gi, $elt);
	
	local $_= $elt;
	
        foreach my $handler ( @handlers)
          { $handler->($t, $elt) || last; }
	# call _all_ handler if needed
        if( my $all= $t->{twig_starttag_handlers}->{handlers}->{$ALL})
          { $all->($t, $elt); }
      }
  }

# the default function to parse a start tag (in keep_encoding mode)
# can be overridden with the parse_start_tag (or parse_start_tag) method
# only works for 1-byte character sets
sub parse_start_tag
  { my $string= shift;
    my( $gi, %atts);

    # get the gi (between < and the first space, / or > character)
    if( $string=~ s{^<\s*([^\s>/]*)[\s>/]*}{}s)
      { $gi= $1; }
    else
      { croak "internal error when parsing start tag $string"; }
    while( $string=~ s{^([^\s=]*)\s*=\s*(["'])(.*?)\2\s*}{}s)
      { $atts{$1}= $3; }
    return $gi, %atts;
  }


sub twig_end($$;@)
  { my ($p, $gi)  = @_;
    my $t=$p->{twig};
   
    if( $t->{twig_stored_spaces})
      { $t->{twig_space_policy}->{$gi}= space_policy( $t, $gi)
          unless defined( $t->{twig_space_policy}->{$gi});
        if( $t->{twig_space_policy}->{$gi})
          { insert_pcdata( $t, $t->{twig_stored_spaces}) };
        $t->{twig_stored_spaces}='';
      }

    # the new twig_current is the parent
    my $elt= $t->{twig_current};
    delete $elt->{'twig_current'};

    # if we were parsing PCDATA then we exit the pcdata too
    if( $t->{twig_in_pcdata})
      { $t->{twig_in_pcdata}= 0;
        $elt= $elt->{parent} if($elt->{parent});
        delete $elt->{'twig_current'};
      }

    # parent is the new current element
    my $parent= $elt->{parent};
    $parent->{'twig_current'}=1 if( $parent);
    $t->{twig_current}= $parent;

    $elt->{extra_data_before_end_tag}= $t->{extra_data} if( $t->{extra_data}); 
    $t->{extra_data}='';

    if( $t->{twig_handlers})
      { # look for handlers
        my @handlers= handler( $t, $t->{twig_handlers}, $gi, $elt);

        local $_= $elt; # so we can use $_ in the handlers
	
        foreach my $handler ( @handlers)
          { $handler->($t, $elt) || last; }
	# call _all_ handler if needed
        if( my $all= $t->{twig_handlers}->{handlers}->{$ALL})
          { $all->($t, $elt); }
      }

    # if twig_roots is set for the element then set appropriate handler
    if( handler( $t, $t->{twig_roots}, $gi, $elt))
      { if( $t->{twig_default_print})
          { if( $t->{twig_keep_encoding})
              { $p->setHandlers( %twig_handlers_roots_print_original); }
            else
              { $p->setHandlers( %twig_handlers_roots_print); }
          }
        else
          { $p->setHandlers( %twig_handlers_roots); }
      }

  }

# return of handler that can be activated for an element 
# (either of CODE ref's or 1's for twig_roots)

sub handler
  { my( $t, $handlers, $gi, $elt)= @_;

    my @found_handlers=();

    # warning: $elt can be either a regular element or a ref to the
    #          attribute hash (when called for an element for which
    #          the XML::Twig::Elt has not been built, outside of
    #          the twig_roots)

    # check for an attribute expression with no gi
    if( $handlers->{att_handlers})
      { my %att_handlers= %{$handlers->{att_handlers_exp}};
        foreach my $att ( keys %att_handlers)
          { my $att_val;
            # get the attribute value
	    if( ref $elt eq 'HASH')
	      { $att_val= $elt->{$att}; }     # $elt is the atts hash
	    else
	      { $att_val= $elt->{'att'}->{$att}; }  # $elt is an element
            if( defined $att_val)
              { my @cond= @{$handlers->{att_handlers_exp}->{$att}};
                foreach my $cond (@cond)
                  {  # 2 cases: either there is a val and the att value should be equal to it
                     #          or there is no val (condition was gi[@att]), just for the att to be defined 
	            if( !defined $cond->{val} || ($att_val eq $cond->{val}) )  
                      { push @found_handlers, $cond->{handler};}
                  }
              }
          }
      }

    # check for a text expression
    if( $handlers->{text_handlers}->{$gi})
      { my @text_handlers= @{$handlers->{text_handlers_exp}->{$gi}};
        foreach my $exp ( @text_handlers)
          { if( (!$exp->{sub_elt} && $elt->text eq $exp->{text})
                || ($elt->field( $exp->{sub_elt}) eq $exp->{text})
              )
              { push @found_handlers, $exp->{handler}; }
          }
      }

    # check for a text regexp expression
    if( $handlers->{regexp_handlers}->{$gi})
      { my @regexp_handlers= @{$handlers->{regexp_handlers_exp}->{$gi}};
        foreach my $exp ( @regexp_handlers)
          { if( (!$exp->{sub_elt} && $elt->text=~ $exp->{regexp})
                || ($elt->field( $exp->{sub_elt})=~ $exp->{regexp})
              )
              { push @found_handlers, $exp->{handler}; }
          }
      }

    # check for an attribute expression
    if( $handlers->{attcond_handlers}->{$gi})
      { my @attcond_handlers= @{$handlers->{attcond_handlers_exp}->{$gi}};
        foreach my $exp ( @attcond_handlers)
          { my $att_val;
	    # get the attribute value
	    if( ref $elt eq 'HASH')
	      { $att_val= $elt->{$exp->{att}}; }    # $elt is the atts hash
	    else
	      { $att_val= $elt->{'att'}->{$exp->{att}}; }# $elt is an element

	    # 2 cases: either there is a val and the att value should be equal to it
            #          or there is no val (condition was gi[@att]), just for the att to be defined 
	    if( defined $att_val && ( !defined $exp->{val} || ($att_val eq $exp->{val}) ) ) 
              { push @found_handlers, $exp->{handler}; }
          }
      }

    # check for an attribute regexp
    if( $handlers->{attregexp_handlers}->{$gi})
      { my @attregexp_handlers= @{$handlers->{attregexp_handlers_exp}->{$gi}};
        foreach my $exp ( @attregexp_handlers)
          { my $att_val;
	    # get the attribute value
	    if( ref $elt eq 'HASH')
	      { $att_val= $elt->{$exp->{att}}; }    # $elt is the atts hash
	    else
	      { $att_val= $elt->{'att'}->{$exp->{att}}; }# $elt is an element

	    if( defined $att_val && ( ($att_val=~  $exp->{regexp}) ) ) 
              { push @found_handlers, $exp->{handler}; }
          }
      }

    # check for a full path
    if( defined $handlers->{path_handlers}->{$gi})
      { my $path= $t->path( $gi); 
        if( defined $handlers->{handlers}->{$path})
          { push @found_handlers, $handlers->{handlers}->{$path}; }
      }

    # check for a partial path
    if( $handlers->{subpath_handlers}->{$gi})
      { my $path= $t->path( $gi);
        while( $path)
          { # test each sub path
            if( defined $handlers->{handlers}->{$path})
              { push @found_handlers, $handlers->{handlers}->{$path}; }
             $path=~ s{^[^/]*/?}{}; # remove initial gi and /
          }
      }

    # check for a gi (simple gi's are stored directly in the handlers field)
    if( defined $handlers->{handlers}->{gi}->{$gi})
      { push @found_handlers, $handlers->{handlers}->{gi}->{$gi}; }

    # if no handler found call default handler if defined
    if( !@found_handlers && defined $handlers->{handlers}->{$DEFAULT})
      { push @found_handlers, $handlers->{handlers}->{$DEFAULT}; }

    return @found_handlers; # empty if no handler found

  }

sub twig_char
  { my ($p, $string)= @_;
    # print STDERR "[char: $string (" . $p->original_string(). ")]";
    my $t=$p->{twig}; 

    # if keep_encoding was set then use the original string instead of
    # the parsed (UTF-8 converted) one
    if( $t->{twig_keep_encoding})
      { $string= $p->original_string(); }

    if( $t->{twig_input_filter})
      { $string= $t->{twig_input_filter}->( $string); }

    if( $t->{twig_char_handler})
      { $string= $t->{twig_char_handler}->( $string); }

    my $elt= $t->{twig_current};

    if(    $t->{twig_in_cdata})
      { # text is the continuation of a previously created pcdata
        $elt->{cdata}.=  $t->{twig_stored_spaces}.$string; } 
    elsif( $t->{twig_in_pcdata})
      { # text is the continuation of a previously created cdata
        $elt->{pcdata}.=  $string; 
      } 
    else
      { # text is just space, which might be discarded later
        if( $string=~/\A\s*\Z/s)
          { if( $t->{extra_data})
	      { # we got extra data (comment, pi), lets add the spaces to it
	        $t->{extra_data} .= $string; 
	      }
	    else
	      { # no extra data, just store the spaces
	        $t->{twig_stored_spaces}.= $string;
	      }
          } 
        else
          { my $new_elt= insert_pcdata( $t, $t->{twig_stored_spaces}.$string);
	    delete $elt->{'twig_current'};
	    $new_elt->{'twig_current'}=1;
	    $t->{twig_current}= $new_elt;
	    $t->{twig_in_pcdata}=1;
            $new_elt->{extra_data}= $t->{extra_data} if( $t->{extra_data});
            $t->{extra_data}='';
	  }
      }
  }

sub twig_cdatastart
  { my $p= shift;
    my $t=$p->{twig};

    $t->{twig_in_cdata}=1;
    my $twig_current= $t->{twig_current};
    my $cdata=  XML::Twig::Elt->new( '#CDATA');
    if( $t->{twig_in_pcdata})
      { # create the node as a sibling of the #PCDATA
        $cdata->set_prev_sibling( $twig_current);
        $twig_current->{next_sibling}=  $cdata;
	my $parent= $twig_current->{parent};
        $cdata->set_parent( $parent);
        $parent->set_last_child( $cdata);
        $t->{twig_in_pcdata}=0;
      }
    else
      { # create the node as a child of the current element
        $cdata->set_parent( $twig_current);
        $twig_current->set_last_child( $cdata);
        if( my $prev_sibling= $twig_current->{first_child})
          { $cdata->set_prev_sibling( $prev_sibling);
            $prev_sibling->{next_sibling}=  $cdata;
          }
        else
          { $twig_current->{first_child}=  $cdata; }
      }

    delete $twig_current->{'twig_current'};
    $t->{twig_current}= $cdata;
    $cdata->{'twig_current'}=1;
  }

sub twig_cdataend
  { my $p= shift;
    my $t=$p->{twig};

    $t->{twig_in_cdata}=0;

    my $elt= $t->{twig_current};
    delete $elt->{'twig_current'};
    my $cdata= $elt->{cdata};
    $elt->{cdata}=  $cdata;

    $elt= $elt->{parent};
    $t->{twig_current}= $elt;
    $elt->{'twig_current'}=1;
  }

sub twig_pi
  { my( $p, $target, $data)= @_;
    my $t=$p->{twig};

    if( $t->{twig_input_filter})
      { $target = $t->{twig_input_filter}->( $target) ;
        $data   = $t->{twig_input_filter}->( $data)   ;
      }

    my $twig_current= $t->{twig_current};    # always defined

    # if pi's are to be kept then we piggiback them to the current element
    if( $t->{twig_keep_pi})
      {  
        if( my $handler= $t->{twig_handlers}->{pi_handlers}->{$target})
          { $t->{extra_data}.= $handler->( $t, $target, $data); }
        elsif( $handler= $t->{twig_handlers}->{pi_handlers}->{''})
          { $t->{extra_data}.= $handler->( $t, $target, $data); }
        else
          { if( $t->{twig_stored_spaces})
	      { $t->{extra_data}.= $t->{twig_stored_spaces};
	        $t->{twig_stored_spaces}= '';
              }
	    $t->{extra_data}.= $p->recognized_string();
	  }

      }
    else
      {
        my $pi=  XML::Twig::Elt->new( PI);
        $pi->set_pi( $target, $data);

        return add_prolog_data( $t, $pi) unless( $t->root);
    
        if( $t->{twig_in_pcdata})
          { # create the node as a sibling of the #PCDATA
	    $pi->paste_after( $twig_current);
            $t->{twig_in_pcdata}=0;
          }
        else
          { # create the node as a child of the current element
            $pi->paste_last_child( $twig_current);
          }
    
        delete $twig_current->{'twig_current'};
        my $parent= $pi->{parent};
        $t->{twig_current}= $parent;
        $parent->{'twig_current'}=1;

        if( my $handler= $t->{twig_handlers}->{pi_handlers}->{$target})
          { $handler->( $t, $pi); }
        elsif( $handler= $t->{twig_handlers}->{pi_handlers}->{''})
          { $handler->( $t, $pi); }
      }

  }


sub twig_comment
  { my( $p, $data)= @_;
    my $t=$p->{twig};
    $data= $t->{twig_input_filter}->( $data) if( $t->{twig_input_filter});

    my $twig_current= $t->{twig_current};    # always defined

    # if comments are to be kept then we piggiback them to the current element
    if( $t->{twig_keep_comments})
      { $t->{extra_data}.= $XML::Twig::Elt::keep_encoding ?
                             $p->recognized_string()
                           : $p->original_string();
        return;
      }

    my $comment=  XML::Twig::Elt->new( COMMENT);
    $comment->{comment}=  $data;

    return add_prolog_data( $t, $comment) unless( $t->root);

    if( $t->{twig_in_pcdata})
      { # create the node as a sibling of the #PCDATA
        $comment->paste_after( $twig_current);
        $t->{twig_in_pcdata}=0;
      }
    else
      { # create the node as a child of the current element
	$comment->paste_last_child( $twig_current);
      }

    delete $twig_current->{'twig_current'};

    my $parent= $comment->{parent};
    $t->{twig_current}= $parent;
    $parent->{'twig_current'}=1;

  }

sub add_prolog_data
  { my($t, $prolog_data)= @_;
    # comment before the first element
    $t->{prolog_data} ||= XML::Twig::Elt->new( '#PROLOG_DATA');
    # create the node as a child of the current element
    $prolog_data->paste_last_child( $t->{prolog_data});
  }
  
sub twig_final
  { my $p= shift;
    my $t=$p->{twig};

    # tries to clean-up (probably not very well at the moment)
    undef $p->{twig};
    undef $t->{twig_parser};

    undef $t->{twig_parsing};

    return $t;
  }

sub insert_pcdata
  { my( $t, $string)= @_;
    # create a new #PCDATA element
    my $parent= $t->{twig_current};    # always defined
    my $elt=  XML::Twig::Elt->new( PCDATA);
    $elt->{pcdata}=  $string;
    my $prev_sibling= $parent->{last_child};
    if( $prev_sibling) 
      { $prev_sibling->{next_sibling}=  $elt; 
        $elt->set_prev_sibling( $prev_sibling);
      }
    else
      { $parent->{first_child}=  $elt; }

    $elt->set_parent( $parent);
    $parent->set_last_child( $elt);
    $t->{twig_stored_spaces}='';
    return $elt;
  }


sub space_policy
  { my( $t, $gi)= @_;
    my $policy;
    $policy=0 if( $t->{twig_discard_spaces});
    $policy=1 if( $t->{twig_keep_spaces});
    $policy=1 if( $t->{twig_keep_spaces_in}
               && $t->{twig_keep_spaces_in}->{$gi});
    $policy=0 if( $t->{twig_discard_spaces_in} 
               && $t->{twig_discard_spaces_in}->{$gi});
    return $policy;
  }


sub twig_entity($$$$$$)
  { my( $p, $name, $val, $sysid, $pubid, $ndata)= @_;
    my $t=$p->{twig};
    my $ent=XML::Twig::Entity->new( $name, $val, $sysid, $pubid, $ndata);
    $t->{twig_entity_list}->add( $ent);
  }

sub twig_xmldecl
  { my $p= shift;
    my $t=$p->{twig};
    $t->{twig_xmldecl}={};
    $t->{twig_xmldecl}->{version}= shift;
    $t->{twig_xmldecl}->{encoding}= shift; 
    $t->{twig_xmldecl}->{standalone}= shift;
  }

sub twig_doctype
  { my( $p, $name, $sysid, $pub, $internal)= @_;
    my $t=$p->{twig};
    $t->{twig_doctype}||= {};                   # create 
    $t->{twig_doctype}->{name}= $name;          # always there
    $t->{twig_doctype}->{sysid}= $sysid;        #  
    $t->{twig_doctype}->{pub}= $pub;            #  


    # now let's try to cope with XML::Parser 2.28 and above
    if( $parser_version > 2.27)
      { @saved_default_handler= $p->setHandlers( 
                           Default     => \&twig_store_internal_dtd,
                                           );
      $p->setHandlers( DoctypeFin  => \&twig_stop_storing_internal_dtd);
      $t->{twig_doctype}->{internal}='';
      }
    else			
      # for XML::Parser before 2.28
      { $t->{twig_doctype}->{internal}=$internal; }

    # now check if we want to get the DTD info
    if( $t->{twig_read_external_dtd} && $sysid)
      { # let's build a fake document with an internal DTD
        # is this portable?
	# print STDERR "loading external DTD\n";
        my $tmpfile= "twig_tmp$$";
        open( TMP, ">$tmpfile") 
          or croak "cannot create temp file $tmpfile: $!";
        print TMP "<!DOCTYPE $name [\n";   # print the doctype
        # slurp the DTD
          { open( DTD, "<$sysid") 
              or croak "cannot open dtd file $sysid: $!";
            local undef $/;
            my $dtd= <DTD>;
            close DTD;
            print TMP $dtd;                 # add the dtd
          }
        print TMP "]>";                     # close the dtd
        print TMP "<dummy></dummy>\n";      # XML::Parser needs an element

        close TMP;
        
        my $t_dtd= XML::Twig->new;           # create a temp twig
        $t_dtd->parsefile( $tmpfile);       # parse it
        $t->{twig_dtd}= $t_dtd->{twig_dtd}; # grab the dtd info
        $t->{twig_entity_list}= $t_dtd->{twig_entity_list}; # grab the entity info

        unlink $tmpfile;
      }

  }

sub twig_element
  { my( $p, $name, $model)= @_;
    my $t=$p->{twig};
    $t->{twig_dtd}||= {};                     # may create the dtd 
    $t->{twig_dtd}->{model}||= {};            # may create the model hash 
    $t->{twig_dtd}->{elt_list}||= [];         # ordered list of elements 
    push @{$t->{twig_dtd}->{elt_list}}, $name; # store the elt
    $t->{twig_dtd}->{model}->{$name}= $model; # store the model
    if( $parser_version > 2.27) 
      { $t->{twig_doctype}->{internal} .= 
          $XML::Twig::Elt::keep_encoding ? $p->original_string 
                                         : $p->recognized_string; 
      }
  }

sub twig_attlist
  { my( $p, $el, $att, $type, $default, $fixed)= @_;
    my $t=$p->{twig};
    $t->{twig_dtd}||= {};                      # create dtd if need be 
    $t->{twig_dtd}->{$el}||= {};               # create elt if need be 
    $t->{twig_dtd}->{$el}->{att}||= {};        # create att if need be 
    $t->{twig_dtd}->{att}->{$el}->{$att}= {} ;
    $t->{twig_dtd}->{att}->{$el}->{$att}->{type}= $type; 
    $t->{twig_dtd}->{att}->{$el}->{$att}->{default}= $default; 
    $t->{twig_dtd}->{att}->{$el}->{$att}->{fixed}= $fixed; 
    if( $parser_version > 2.27) 
      { $t->{twig_doctype}->{internal} .= 
          $XML::Twig::Elt::keep_encoding ? $p->original_string 
                                         : $p->recognized_string; 
      }
  }

# called only when the NoExpand option is set
sub twig_default
  { my( $p, $string)= @_;
    
    my $t= $p->{twig};
    
    # print STDERR "[default: $string (". $p->original_string(). ")]";
    # process only if we have an entity
    return unless( $string=~ m{^&[^;]*;$});
    # print STDERR "entity $string found\n";
    # the entity has to be pure pcdata, or we have a problem
    if( $t->{twig_keep_encoding}) { twig_char( $p, $string);        }
    else                          { twig_insert_ent( $t, $string);  }
  }
    
sub twig_insert_ent
  { my( $t, $string)=@_;

    # print STDERR "[set_ent $string]";

    my $twig_current= $t->{twig_current};

    my $ent=  XML::Twig::Elt->new( '#ENT');
    $ent->{ent}=  $string;
    
    if( $t->{twig_in_pcdata})
      { # create the node as a sibling of the #PCDATA
        $ent->set_prev_sibling( $twig_current);
        $twig_current->{next_sibling}=  $ent;
	my $parent= $twig_current->{parent};
        $ent->set_parent( $parent);
        $parent->set_last_child( $ent);
	# the twig_current is now the parent
        delete $twig_current->{'twig_current'};
        $t->{twig_current}= $parent;
	# we left pcdata
	$t->{twig_in_pcdata}=0;
      }
    else
      { # create the node as a child of the current element
        $ent->set_parent( $twig_current);
        if( my $prev_sibling= $twig_current->{last_child})
          { $ent->set_prev_sibling( $prev_sibling);
            $prev_sibling->{next_sibling}=  $ent;
          }
	else
	  { $twig_current->{first_child}=  $ent; }
        $twig_current->set_last_child( $ent);
      }

  }

sub parser
  { return $_[0]->{twig_parser}; }

# returns the declaration text (or a default one)
sub xmldecl
  { my $t= shift;
    my $decl= $t->{'twig_xmldecl'} or return '';
    my $string= "<?xml";
    $string .= " version=\"$decl->{version}\""       if( $decl->{version});
    $string .= " encoding=\"$decl->{encoding}\""     if( $decl->{encoding});
    if( defined( $decl->{standalone}))
      { $string .= " standalone=\"";  
        $string .= $decl->{standalone} ? "yes" : "no";  
        $string .= "\""; 
      } 
    $string .= "?>\n";
    return $string;
  }

# returns the doctype text (or none)
# that's the doctype just has it was in the original document
sub doctype
  { my $t= shift;
    my $doctype= $t->{'twig_doctype'} or return '';
    my $string= "<!DOCTYPE " . $doctype->{name};
    $string  .= qq{ SYSTEM "$doctype->{sysid}"} if( $doctype->{sysid});
    $string  .= qq{ PUBLIC  "$doctype->{pub}" } if( $doctype->{pub});
    $string  .= "\n" . $doctype->{internal} . "\n";
    return $string;
  }

# return the dtd object
sub dtd
  { my $t= shift;
    return $t->{twig_dtd};
  }

# return an element model, or the list of element models
sub model
  { my $t= shift;
    my $elt= shift;
    return $t->dtd->{'model'}->{$elt} if( $elt);
    return sort keys %{$t->{'dtd'}->{'model'}};
  }

        
# return the entity_list object 
sub entity_list($)
  { my $t= shift;
    return $t->{twig_entity_list};
  }

# return the list of entity names 
sub entity_names($)
  { my $t= shift;
    return sort keys %{$t->{twig_entity_list}} ;
  }

# return the entity object 
sub entity($$)
  { my $t= shift;
    my $entity_name= shift;
    return $t->{twig_entity_list}->{$entity_name};
  }


sub print_prolog
  { my $t= shift;
    my $fh=  shift if( defined( $_[0]) && UNIVERSAL::isa($_[0], 'GLOB' ) );
    if( $fh) { print $fh $t->prolog( @_); }
    else     { print $t->prolog( @_);     }
  }

sub prolog
  { my $t= shift;
    my %args= @_;
    my $prolog='';

    my $update_dtd = $args{Update_DTD} || '';

    $prolog .= $t->xmldecl;
    return $prolog unless( defined $t->{'twig_doctype'} || defined $t->{no_dtd_output});
    my $doctype= $t->{'twig_doctype'};
    if( $update_dtd)
      { 
        if( defined $doctype->{sysid}  )  
          { $prolog .= "<!DOCTYPE ".$doctype->{name};
            $prolog .= " SYSTEM \"$doctype->{sysid}\"";
            $prolog .= " PUBLIC  \"$doctype->{pub}\""  if( $doctype->{pub});
            $prolog .= "[\n";
            $prolog .= $t->{twig_entity_list}->text;
            $prolog .= "]>\n";
          }
        else
          { my $dtd= $t->{'twig_dtd'};
            $prolog .= $t->dtd_text;
          }            
      }
    else
      { $prolog .= "<!DOCTYPE ". $doctype->{name}  if( $doctype->{name});
        $prolog .= " PUBLIC  \"$doctype->{pub}\""  if( $doctype->{pub});
        $prolog .= " SYSTEM" if( $doctype->{sysid} && !$doctype->{pub});
        $prolog .= ' "' . $doctype->{sysid} . '"'  if( $doctype->{sysid}); 
        if( $doctype->{internal})
          { $prolog .= "\n" if( $doctype->{internal}=~ /^\s*[[<]/s);
            $prolog .=  $doctype->{internal}; 
          }
        unless( $parser_version > 2.27)
          { $prolog .= ">\n" unless( $t->{twig_no_expand}); } 
      }

    # terrible hack, as I can't figure out in which case the darn prolog
    # should get an extra >
    $prolog=~ s/>*$/>/;

    return $prolog;
  }

sub print_prolog_data
  { my $t= shift;
    my $fh=  shift if( defined( $_[0]) && UNIVERSAL::isa($_[0], 'GLOB' ) );
    if( $fh) { print $fh $t->prolog_data( @_); }
    else     { print $t->prolog_data( @_);     }
  }

sub prolog_data
  { my $t= shift;
    return''  unless( $t->{prolog_data});
    my $prolog_data_text='';
    foreach ( $t->{prolog_data}->children)
      { $prolog_data_text .= $_->sprint . "\n"; }
    return$ prolog_data_text;
  }


sub print
  { my $t= shift;
    my $fh=  shift if( defined( $_[0]) && UNIVERSAL::isa($_[0], 'GLOB') );
    my %args= @_;

    my $old_pretty;
    if( defined $args{PrettyPrint})
      { $old_pretty= $t->set_pretty_print( $args{PrettyPrint}); 
        delete $args{PrettyPrint};
      }

     my $old_empty_tag_style;
     if( defined $args{EmptyTags})
      { $old_empty_tag_style= $t->set_empty_tag_style( $args{EmptyTags}); 
        delete $args{EmptyTags};
      }

    if( $fh) 
      { $t->print_prolog( $fh, %args); 
        $t->print_prolog_data( $fh, %args);
      }
    else 
      { $t->print_prolog( %args);
        $t->print_prolog_data( %args);
      }

    $t->{twig_root}->print( $fh) if( $t->{twig_root});
    $t->set_pretty_print( $old_pretty) if( defined $old_pretty); 
    $t->set_empty_tag_style( $old_empty_tag_style) if( defined $old_empty_tag_style); 
  }


sub flush
  { my $t= shift;
    my $fh=  shift if( defined( $_[0]) && UNIVERSAL::isa($_[0], 'GLOB') );
    my $old_select= select $fh if( defined $fh);
    my $up_to= shift if( ref $_[0]);
    my %args= @_;

    my $old_pretty;
    if( defined $args{PrettyPrint})
      { $old_pretty= $t->set_pretty_print( $args{PrettyPrint}); 
        delete $args{PrettyPrint};
      }

     my $old_empty_tag_style;
     if( $args{EmptyTags})
      { $old_empty_tag_style= $t->set_empty_tag_style( $args{EmptyTags}); 
        delete $args{EmptyTags};
      }


    # the "real" last element processed, as twig_end has closed it
    my $last_elt;
    if( $up_to)
      { $last_elt= $up_to; }
    elsif( $t->{twig_current})
      { $last_elt= $t->{twig_current}->_last_child; }
    else
      { $last_elt= $t->{twig_root}; }

    # flush the DTD unless it has ready flushed (id root has been flushed)
    my $elt= $t->{twig_root};
    $t->print_prolog( %args) unless( $elt->{flushed});

    while( $elt)
      { my $next_elt; 
        if( $last_elt && $last_elt->in( $elt))
          { 
            unless( $elt->{flushed}) 
              { # just output the front tag
                print $elt->start_tag();
                $elt->{'flushed'}=1;
              }
            $next_elt= $elt->{first_child};
          }
        else
          { # an element before the last one or the last one,
            $next_elt= $elt->{next_sibling};  
            $elt->_flush();
            $elt->delete; 
            last if( $last_elt && ($elt == $last_elt));
          }
        $elt= $next_elt;
      }
    select $old_select if( defined $old_select);
    $t->set_pretty_print( $old_pretty) if( defined $old_pretty); 
    $t->set_empty_tag_style( $old_empty_tag_style) if( defined $old_empty_tag_style); 
  }

# flushes up to an element
# this method just reorders the arguments and calls flush
sub flush_up_to
  { my $t= shift;
    my $up_to= shift;
    if( defined( $_[0]) && UNIVERSAL::isa($_[0], 'GLOB') )
      { my $fh=  shift;
        $t->flush( $fh, $up_to, @_);
      }
    else
      { $t->flush( $up_to, @_); }
  }

    
# same as print except the entire document text is returned as a string
sub sprint
  { my $t= shift;
    my %args= @_;

    my $old_pretty;
    if( $args{PrettyPrint})
      { $old_pretty= $t->set_pretty_print( $args{PrettyPrint}); 
        delete $args{PrettyPrint};
      }

     my $old_empty_tag_style;
     if( $args{EmptyTags})
      { $old_empty_tag_style= $t->set_empty_tag_style( $args{EmptyTags}); 
        delete $args{EmptyTags};
      }
      
    my $prolog= $t->prolog( %args) || '';
    my $prolog_data= $t->prolog_data( %args) || '';
    
    my $string=  $prolog . $prolog_data . $t->{twig_root}->sprint;

    $t->set_pretty_print( $old_pretty) if( $old_pretty); 
    $t->set_empty_tag_style( $old_empty_tag_style) if( $old_empty_tag_style); 

    return $string;
  }
    

# this method discards useless elements in a tree
# it does the same thing as a purge except it does not print it
# the second argument is an element, the last purged element
# (this argument is usually set through the purge_up_to method)
sub purge
  { my $t= shift;
    my $up_to= shift;

    # the "real" last element processed, as twig_end has closed it
    my $last_elt;
    if( $up_to)
      { $last_elt= $up_to; }
    elsif( $t->{twig_current})
      { $last_elt= $t->{twig_current}->_last_child; }
    else
      { $last_elt= $t->{twig_root}; }
    
    my $elt= $t->{twig_root};

    while( $elt)
      { my $next_elt; 
        if( $last_elt && $last_elt->in( $elt))
          { $elt->{'flushed'}=1;
            $next_elt= $elt->{first_child};
          }
        else
          { # an element before the last one or the last one,
            $next_elt= $elt->{next_sibling};  
            $elt->delete; 
            last if( $elt == $last_elt);
          }
        $elt= $next_elt;
      }
  }
    
# flushes up to an element. This method just calls purge
sub purge_up_to
  { my $t= shift;
    my $up_to= shift;
    $t->purge( $up_to);
  }

sub root
  { return $_[0]->{twig_root}; }

#start-extract twig_document (used to generate XML::(DOM|GDOME)::Twig)
sub first_elt
  { my( $t, $cond)= @_;
    my $root= $_[0]->{twig_root};
    return $root if( $root->passes( $cond));
    return $root->next_elt( $cond); 
  }

sub get_xpath
  { my $twig= shift;
    $twig->root->get_xpath( @_);
  }

# return a list with just the root
# if a condition is given then return an empty list unless the root matches
sub children
  { my( $t, $cond)= @_;
    my $root= $t->root;
    unless( $cond && !($root->passes( $cond)) )
      { return ($root); }
    else
      { return (); }
  }

sub descendants
  { my( $t, $cond)= @_;
    my $root= $t->root;
    if( $root->passes( $cond) )
      { return ($root, $root->descendants( $cond)); }
    else
      { return ( $root->descendants( $cond)); }
  }

#end-extract twig_document

sub set_keep_encoding
  { return XML::Twig::Elt::set_keep_encoding( @_); }

sub set_expand_external_entities
  { return XML::Twig::Elt::set_expand_external_entities( @_); }

# WARNING: at the moment the id list is not updated reliably
sub elt_id
  { return $_[0]->{twig_id_list}->{$_[1]}; }

# change it in ALL twigs at the moment
sub change_gi 
  { my( $twig, $old_gi, $new_gi)= @_;
    my $index;
    return unless($index= $gi2index{$old_gi});
    $index2gi[$index]= $new_gi;
    delete $gi2index{$old_gi};
    $gi2index{$new_gi}= $index;
  }


# builds the DTD from the stored (possibly updated) data
sub dtd_text
  { my $t= shift;
    my $dtd= $t->{twig_dtd};
    my $doctype= $t->{'twig_doctype'} or return '';
    my $string= "<!DOCTYPE ".$doctype->{name};

    unless( $parser_version > 2.27) { $string .= "[\n"; }

    foreach my $gi (@{$dtd->{elt_list}})
      { $string.= "<!ELEMENT $gi ".$dtd->{'model'}->{$gi}.">\n" ;
        if( $dtd->{att}->{$gi})
          { my $attlist= $dtd->{att}->{$gi};
            $string.= "<!ATTLIST $gi\n";
            foreach my $att ( sort keys %{$attlist})
              { $string.= "   $att $attlist->{$att}->{type} ".
                            "$attlist->{$att}->{default}"; 
                if( $attlist->{$att}->{fixed})
                  { $string .= " #FIXED"};
                $string.= "\n";
              }
            $string.= ">\n";
          }
      }
    $string.= $t->entity_list->text if( $t->entity_list);
    $string.= "\n]>\n";
    return $string;
  }
        
# prints the DTD from the stored (possibly updated) data
sub dtd_print
  { my $t= shift;
    my $fh=  shift if( defined( $_[0]) && UNIVERSAL::isa($_[0], 'GLOB') );
    if( $fh) { print $fh $t->dtd_text; }
    else     { print $t->dtd_text; }
  }

# build the subs that call directly expat
BEGIN
  { my @expat_methods= qw( depth in_element within_element context
                           current_line current_column current_byte
			   namespace eq_name generate_ns_name new_ns_prefixes
                           expand_ns_prefix current_ns_prefixes
			   recognized_string original_string 
			   xpcroak xpcarp 
			   base current_element element_index 
                           position_in_context);
    foreach my $method (@expat_methods)
      { no strict 'refs';
        *{$method}= sub { my $t= shift;
                          warn "calling $method after parsing is finished" 
                                 unless( $t->{twig_parsing}); 
                          return $t->{twig_parser}->$method(\@_); 
                        };
      }
  }

sub path
  { my( $t, $gi)= @_;
    return "/" . join( "/", ($t->{twig_parser}->context, $gi));
  }

sub finish
  { my $t= shift;
    return $t->{twig_parser}->finish;
  }

# just finish the parse by printing the rest of the document
sub finish_print
  { my( $t, $fh)= @_;
    select $fh if( defined $fh);
    $t->flush;
    my $p=$t->{twig_parser};
    if( $t->{twig_keep_encoding})
      { $p->setHandlers( %twig_handlers_finish_print); }
    else
      { $p->setHandlers( %twig_handlers_finish_print_original); }

  }

sub set_output_filter
  { return XML::Twig::Elt::set_output_filter( @_); }

sub set_input_filter
  { my( $t, $input_filter)= @_;
    my $old_filter= $t->{twig_input_filter};
      if( !$input_filter || UNIVERSAL::isa( $input_filter, 'CODE') )
        { $t->{twig_input_filter}= $input_filter; }
      elsif( $input_filter eq 'latin1')
        {  $t->{twig_input_filter}= latin1(); }
      elsif( $filter{$input_filter})
        {  $t->{twig_input_filter}= $filter{$input_filter}; }
      else
        { croak "invalid input filter: $input_filter"; }
      
      return $old_filter;
    }

sub set_empty_tag_style
  { return XML::Twig::Elt::set_empty_tag_style( @_); }

sub set_pretty_print
  { return XML::Twig::Elt::set_pretty_print( @_); }

sub set_quote
  { return XML::Twig::Elt::set_quote( @_); }

sub set_indent
  { return XML::Twig::Elt::set_indent( @_); }


sub dispose
  { my $t= shift;
    $t->DESTROY;
  }
  
sub DESTROY
  { my $t= shift;
    if( $t->{twig_root} &&UNIVERSAL::isa(  $t->{twig_root}, 'XML::Twig')) 
      { $t->{twig_root}->delete } 

# added to break circular references
    undef $t->{twig};
    undef $t->{twig_root}->{twig} if( $t->{twig_root});
    undef $t->{twig_parser};
    
    $t={}; # prevents memory leaks (especially when using mod_perl)
    undef $t;
  }        


#
#  non standard handlers
#

sub twig_print
  { my $p= shift;
    print $p->recognized_string();
    #print STDERR "twig_print: /",  $p->recognized_string(), "/\n";
  }

sub twig_print_default
  { my( $p, $string)= @_;
    print $string;
    # print STDERR "twig_print_default: /",  $string, "/\n";
  }

# recognized_string does not seem to work for entities, go figure!
# so this handler is not used 
sub twig_print_entity
  { my $p= shift;
    print STDERR "\n entity: \n  recognized /",
                 $p->recognized_string(), "/\n  original /",
                 $p->original_string(), "/\n";
  }

# account for the case where the element is empty
sub twig_print_end
  { my $p= shift; 
    print $p->recognized_string(); 
    # print $p->recognized_string() unless( $p->recognized_string()=~ /\/>\Z/); 
  }


sub twig_print_original
  { my $p= shift;
    print $p->original_string();
  }

sub twig_print_original_default
  { my $p= shift;
    print $p->original_string();
    # print STDERR "DEFAULT[", $p->original_string(), "]";
  }

# account for the case where the element is empty
sub twig_print_end_original
  { my $p= shift;
    print $p->original_string(); 
    # print $p->original_string() unless( $p->original_string()=~ /\/>\Z/); 
  }

sub twig_start_check_roots
  { my( $p, $gi, %att)= @_;
    my $t= $p->{twig};
    if( $p->depth == 0)
      { twig_start( $p, $gi, %att); }
    elsif( handler( $t, $t->{twig_roots}, $gi, \%att))
      { $p->setHandlers( %twig_handlers); # restore regular handlers
        twig_start( $p, $gi, %att);
      }
    elsif( $t->{twig_starttag_handlers})
      { # look for start tag handlers
        my @handlers= handler( $t, $t->{twig_starttag_handlers}, $gi, \%att);
        foreach my $handler ( @handlers)
          { $handler->($t, $gi, %att) || last; }
      }
  }

sub twig_start_check_roots_print
  { my( $p, $gi, %att)= @_;
    my $t= $p->{twig};
    if( $p->depth == 0)
      { print $p->recognized_string();
        twig_start( $p, $gi, %att);
      }
    elsif( handler( $t, $t->{twig_roots}, $gi, \%att))
      { $p->setHandlers( %twig_handlers); # restore regular handlers
        twig_start( $p, $gi, %att);
      }
    elsif( $t->{twig_starttag_handlers})
      { # look for start tag handlers
        my @handlers= handler( $t, $t->{twig_starttag_handlers}, $gi, \%att);
        my $last_handler_res;
        foreach my $handler ( @handlers)
          { $last_handler_res= $handler->($t, $gi, %att);
            last unless $last_handler_res;
          }
        print $p->recognized_string() if( $last_handler_res);   
      }
    else
      { print $p->recognized_string(); }  
  }

sub twig_start_check_roots_print_original
  { my( $p, $gi, %att)= @_;
    my $t= $p->{twig};
    if( $p->depth == 0)
      { print $p->original_string();     
        twig_start( $p, $gi, %att);
      }
    elsif( handler( $t, $t->{twig_roots}, $gi, \%att))
      { $p->setHandlers( %twig_handlers); # restore regular handlers
        twig_start( $p, $gi, %att);
      }
    elsif( $t->{twig_starttag_handlers})
      { # look for start tag handlers
        my @handlers= handler( $t, $t->{twig_starttag_handlers}, $gi, \%att);
        my $last_handler_res;
        foreach my $handler ( @handlers)
          { $last_handler_res= $handler->($t, $gi, %att);
            last unless( $last_handler_res);
          }
        print $p->original_string() if( $last_handler_res);   
      }
    else
      { print $p->original_string(); }
  }

sub twig_end_check_roots
  { my( $p, $gi)= @_;
    my $t= $p->{twig};
    if( $p->depth == 0)
      { twig_end( $p, $gi); }
    elsif( $t->{twig_endtag_handlers})
      { # look for start tag handlers
        my @handlers= handler( $t, $t->{twig_endtag_handlers}, $gi, {});
        my $last_handler_res=1;
        foreach my $handler ( @handlers)
          { $last_handler_res= $handler->($t, $gi) || last; }
        return unless $last_handler_res;
      }
  }

sub twig_end_check_roots_print
  { my( $p, $gi, %att)= @_;
    my $t= $p->{twig};
    if( $p->depth == 0)
      { twig_end( $p, $gi); }
    elsif( $t->{twig_endtag_handlers})
      { # look for start tag handlers
        my @handlers= handler( $t, $t->{twig_endtag_handlers}, $gi, {});
        my $last_handler_res=1;
        foreach my $handler ( @handlers)
          { $last_handler_res= $handler->($t, $gi) || last; }
        return unless $last_handler_res;
      }
    print $p->recognized_string();  
  }

sub twig_end_check_roots_print_original
  { my( $p, $gi, %att)= @_;
    my $t= $p->{twig};
    if( $p->depth == 0)
      { twig_end( $p, $gi); }
    elsif( $t->{twig_endtag_handlers})
      { # look for start tag handlers
        my @handlers= handler( $t, $t->{twig_endtag_handlers}, $gi, {});
        my $last_handler_res=1;
        foreach my $handler ( @handlers)
          { $last_handler_res= $handler->($t, $gi) || last; }
        return unless $last_handler_res;
      }
    print $p->original_string();
  }

sub twig_ignore_start
  { my( $p, $gi)= @_;
    my $t= $p->{twig};
    return unless( $gi eq $t->{twig_ignore_gi});
    $t->{twig_ignore_level}++;
  }

sub twig_ignore_end
  { my( $p, $gi)= @_;
    my $t= $p->{twig};
    return unless( $gi eq $t->{twig_ignore_gi});
    $t->{twig_ignore_level}--;
    unless( $t->{twig_ignore_level})
      { $t->{twig_ignore_elt}->delete; 
        $p->setHandlers( @{$t->{twig_saved_handlers}})
      };
  }
    
sub ignore
  { my( $t, $elt)= @_;
    $elt ||= $t->{twig_current};     # get the element (default: current elt)
    $t->{twig_ignore_elt}= $elt;     # save it
    $t->{twig_ignore_gi }= $XML::Twig::index2gi[$elt->{'gi'}]; # save its gi
    $t->{twig_ignore_level}++;
    my $p= $t->{twig_parser};
    my @saved_handlers= $p->setHandlers( %twig_handlers_ignore); # set handlers
    $t->{twig_saved_handlers}= \@saved_handlers;        # save current handlers
  }
      

# input/output filters

sub latin1 
  { if( eval 'require Text::Iconv;')
      { #warn "using iconv";
        return iconv_convert( 'latin1');
      }
    elsif( eval 'require Unicode::Map8 && require Unicode::String;')
      { #warn "using unicode convert";
        return unicode_convert( 'latin1'); 
      }
    else
      { return \&regexp2latin1; }
  }

# shamelessly lifted from XML::TyePYX
sub regexp2latin1
  { my $text=shift;
    $text=~s{([\xc0-\xc3])(.)}{ my $hi = ord($1);
                                my $lo = ord($2);
                                chr((($hi & 0x03) <<6) | ($lo & 0x3F))
                              }ge;
    return $text;
  }


sub html_encode
  { require HTML::Entities;
    return HTML::Entities::encode(latin1($_[0]));
  }

sub safe_encode
  {   my $str= shift;
       $str =~ s{([\xC0-\xDF].|[\xE0-\xEF]..|[\xF0-\xFF]...)}
	        {XmlUtf8Decode ($1)}egs; 
      return $str;
  }

# this one shamelessly lifted from XML::DOM
sub XmlUtf8Decode
  { my ($str, $hex) = @_;
    my $len = length ($str);
    my $n;

    if ($len == 2)
      { my @n = unpack "C2", $str;
	$n = (($n[0] & 0x3f) << 6) + ($n[1] & 0x3f);
      }
    elsif ($len == 3)
    { my @n = unpack "C3", $str;
      $n = (($n[0] & 0x1f) << 12) + (($n[1] & 0x3f) << 6) + ($n[2] & 0x3f);
    }
    elsif ($len == 4)
    { my @n = unpack "C4", $str;
      $n = (($n[0] & 0x0f) << 18) + (($n[1] & 0x3f) << 12) 
         + (($n[2] & 0x3f) << 6) + ($n[3] & 0x3f);
    }
    elsif ($len == 1)	# just to be complete...
    { $n = ord ($str); }
    else
    { croak "bad value [$str] for XmlUtf8Decode"; }

    $hex ? sprintf ("&#x%x;", $n) : "&#$n;";
}



sub unicode_convert
  { my $enc= $_[1] ? $_[1] : $_[0]; # so the method can be called on the twig or directly
    require Unicode::Map8;
    require Unicode::String;
    import Unicode::String qw(utf8);
    my $sub= eval q{
            { my $cnv;
	      sub { $cnv ||= Unicode::Map8->new($enc) 
	              or croak "Can't create converter to $enc";
		    return  $cnv->to8 (utf8($_[0])->ucs2); 
	          } 
	    } };
    return $sub;
  }

sub iconv_convert
  { my $enc= $_[1] ? $_[1] : $_[0]; # so the method can be called on the twig or directly
    require Text::Iconv;
    my $sub= eval q{
            { my $cnv;
	      sub { $cnv ||= Text::Iconv->new( 'utf8', $enc) 
	              or croak "Can't create converter to $enc";
		    return  $cnv->convert( $_[0]); 
	          } 
	    } };
    return $sub;
  }

######################################################################
package XML::Twig::Entity_list;
######################################################################
sub new
  { my $class = shift;
    my $self={};

    bless $self, $class;
    return $self;

  }

sub add
  { my( $list, $ent)= @_;
    $list->{$ent->{name}}= $ent;
  }

# can be called with an entity or with an entity name
sub delete
  { my $list= shift;
    if( ref $_[0] eq 'XML::Twig::Entity_list')
      { # the second arg was an entity
        my $ent= shift;
        delete $list->{$ent->{name}};
      }
    else
      { # the second arg was not entity, must be a string then
        my $name= shift;
        delete $list->{$name};
      }
  }

sub print
  { my ($ent_list, $fh)= @_;
    my $old_select= select $fh if( defined $fh);

    foreach my $ent_name ( sort keys %{$ent_list})
      { my $ent= $ent_list->{$ent_name};
        # we have to test what the entity is or un-defined entities can creep in
        $ent->print() if( UNIVERSAL::isa( $ent, 'XML::Twig::Entity'));
      }
    select $old_select if( defined $old_select);
  }

sub text
  { my ($ent_list)= @_;
    return join "\n", map { $ent_list->{$_}->text} sort keys %{$ent_list};
  }

sub list
  { my ($ent_list)= @_;
    return @{[$ent_list]};
  }

######################################################################
package XML::Twig::Entity;
######################################################################

sub new
  { my( $ent, $name, $val, $sysid, $pubid, $ndata)= @_;

    my $self={};

    $self->{name}= $name;
    if( $val)
      { $self->{val}= $val; }
    else
      { $self->{sysid}= $sysid;
        $self->{pubid}= $pubid;
        $self->{ndata}= $ndata;
      }
    bless $self;
    return $self;
  }

sub name  { return $_[0]->{name}; }
sub val   { return $_[0]->{val}; }
sub sysid { return $_[0]->{sysid}; }
sub pubid { return $_[0]->{pubid}; }
sub ndata { return $_[0]->{ndata}; }

sub print
  { my ($ent, $fh)= @_;
    if( $fh) { print $fh $ent->text . "\n"; }
    else     { print $ent->text . "\n"; }
  }

sub text
  { my ($ent)= @_;
    if( $ent->{'val'})
      { if( $ent->{'val'}=~ /"/)
          { return "<!ENTITY $ent->{'name'} '$ent->{'val'}'>"; }
        return "<!ENTITY $ent->{'name'} \"$ent->{'val'}\">";
      }
    elsif( $ent->{'sysid'})
      { my $text= "<!ENTITY $ent->{'name'} ";
        $text .= "SYSTEM \"$ent->{'sysid'}\" " if( $ent->{'sysid'});
        $text .= "PUBLIC \"$ent->{'pubid'}\" " if( $ent->{'pubid'});
        $text .= "NDATA $ent->{'ndata'}"        if( $ent->{'ndata'});
        $text .= ">";
        return $text;
      }
  }

                

######################################################################
package XML::Twig::Elt;
######################################################################
use Carp;


use constant  PCDATA  => '#PCDATA'; 
use constant  CDATA   => '#CDATA'; 
use constant  PI      => '#PI'; 
use constant  COMMENT => '#COMMENT'; 
use constant  ENT     => '#ENT'; 

use constant  ASIS    => '#ASIS';    # pcdata elements not to be XML-escaped

use constant  ELT     => '#ELT'; 
use constant  TEXT    => '#TEXT'; 
use constant  EMPTY   => '#EMPTY'; 

use constant CDATA_START    => "<![CDATA[";
use constant CDATA_END      => "]]>";
use constant PI_START       => "<?";
use constant PI_END         => "?>";
use constant COMMENT_START  => "<!--";
use constant COMMENT_END    => "-->";


BEGIN
  { # set some aliases for methods
    *tag        = *gi; 
    *set_tag    = *set_gi; 
    *find_nodes = *get_xpath;
    *field      = *first_child_text;
    *is_field   = *contains_only_text;
    *is         = *passes;
    *matches    = *passes;
    *has_child  = *first_child;
    *all_children_pass = *all_children_are;
    *all_children_match= *all_children_are;
    *getElementsByTagName= *descendants;

  # try using weak references
  import WeakRef if( eval 'require WeakRef');
  }

 
# can be called as XML::Twig::Elt->new( [[$gi, $atts, [@content]])
# - gi is an optional gi given to the element
# - $atts is a hashref to attributes for the element
# - @content is an optional list of text and elements that will
#   be inserted under the element 
sub new 
  { my $class= shift;
    my $self  = {};
    bless ($self, $class);

    return $self unless @_;

    # if a gi is passed then use it
    my $gi= shift;
    $self->set_gi( $gi);

    if( ref $_[0] eq 'HASH')
      { my $atts= shift;
        # the attribute hash can be used to pass the asis status 
        if( defined $atts->{ASIS})
	  { $self->set_asis;
	    delete $atts->{ASIS};
	  }
        $self->{'att'}=  $atts;
      }

    if( $gi eq PCDATA)
      { $self->{pcdata}=  shift; }
    elsif( $gi eq ENT)
      { $self->{ent}=  shift; }
    elsif( $gi eq CDATA)
      { $self->{cdata}=  shift; }
    elsif( $gi eq COMMENT)
      { $self->{comment}=  shift; }
    elsif( $gi eq PI)
      { $self->set_pi( shift, shift); }
    else
      { # the rest of the arguments are the content of the element
        $self->set_content( @_) if @_; 
      }

    return $self;
  }

# this function creates an XM:::Twig::Elt from a string
# it is quite clumsy at the moment, as it just creates a
# new twig then returns its root
# there might also be memory leaks there
# additional arguments are passed to new XML::Twig
sub parse
  { my $class= shift;
    my $string= shift;
    my %args= @_;
    my $t= XML::Twig->new(%args);
    $t->parse( $string);
    my $self= $t->root;
    # clean-up the node 
    delete $self->{twig};         # get rid of the twig data
    delete $self->{twig_current}; # better get rid of this too
    return $self;
  }
    

sub set_gi 
  { my ($elt, $gi)= @_;
    unless( defined $XML::Twig::gi2index{$gi})
      { # new gi, create entries in %gi2index and @index2gi
        push  @XML::Twig::index2gi, $gi;
        $XML::Twig::gi2index{$gi}= $#XML::Twig::index2gi;
      }
    $elt->{gi}= $XML::Twig::gi2index{$gi}; 
  }

sub gi  { return $XML::Twig::index2gi[$_[0]->{gi}]; }

# return #ELT for an element and #PCDATA... for others
sub get_type
  { my $gi_nb= $_[0]->{gi}; # the number, not the string
    return ELT if( $gi_nb > $XML::Twig::SPECIAL_GI);
    return $_[0]->gi;
  }

# return the gi if it's a "real" element, 0 otherwise
sub is_elt
  { return $_[0]->gi if(  $_[0]->{gi} >  $XML::Twig::SPECIAL_GI);
    return 0;
  }


sub is_pcdata
  { my $elt= shift;
    return (exists $elt->{'pcdata'});
  }

sub is_cdata
  { my $elt= shift;
    return (exists $elt->{'cdata'});
  }

sub is_pi
  { my $elt= shift;
    return (exists $elt->{'target'});
  }

sub is_comment
  { my $elt= shift;
    return (exists $elt->{'comment'});
  }

sub is_ent
  { my $elt= shift;
    return (exists $elt->{'ent_name'});
  }


sub is_text
  { my $elt= shift;
    return (exists( $elt->{'pcdata'}) || (exists $elt->{'cdata'}));
  }

sub is_empty
  { return $_[0]->{empty} || 0; }

sub set_empty
  { $_[0]->{empty}= 1 unless( ($_[0]->{'empty'} || 0)); }

sub set_not_empty
  { delete $_[0]->{empty} if( ($_[0]->{'empty'} || 0)); }


sub set_asis
  { my $elt=shift;
    $elt->{asis}= 1 if( (exists $elt->{'pcdata'}));
    foreach my $pcdata ($elt->descendants( PCDATA))
      { $pcdata->{asis}= 1;}
  }

sub set_not_asis
  { my $elt=shift;
    $elt->{asis}= 0 if $elt->{asis};
    foreach my $pcdata ($elt->descendants())
      { delete $pcdata->{asis} if $elt->{asis};}
  }

sub is_asis
  { return $_[0]->{asis}; }

sub closed 
  { my $elt= shift;
    my $t= $elt->twig || return;
    my $curr_elt= $t->{twig_current};
    return unless( $curr_elt);
    return $curr_elt->in( $elt);
  }

sub set_pcdata 
  { delete $_[0]->{empty} if( $_[0]->is_empty);
    return( $_[0]->{'pcdata'}= $_[1]); 
  }
sub append_pcdata
  { return( $_[0]->{'pcdata'}.= $_[1]); 
  }
sub pcdata        { return $_[0]->{pcdata}; }

sub set_data 

  { return( $_[0]->{'data'}= $_[1]); 
  }

sub data { return $_[0]->{data}; }


sub append_extra_data 
  {  return( $_[0]->{extra_data}.= $_[1]); 
  }
sub set_extra_data 
  { return( $_[0]->{extra_data}= $_[1]); 
  }
sub extra_data { return $_[0]->{extra_data}; }

sub set_target 
  { return( $_[0]->{'target'}= $_[1]); 
  }
sub target { return $_[0]->{target}; }

sub set_pi
  { $_[0]->{target}=  $_[1];
    $_[0]->{data}=  $_[2];
  }
sub pi_string { return PI_START . $_[0]->{target} . " " . $_[0]->{data} . PI_END; }

sub set_comment { return( $_[0]->{'data'}= $_[1]); }
sub comment { return $_[0]->{data}; }
sub comment_string { return COMMENT_START . $_[0]->{comment} . COMMENT_END; }


sub set_ent { return( $_[0]->{ent}= $_[1]); }
sub ent { return $_[0]->{ent}; }
sub ent_name { return substr( $_[0]->{ent}, 1, -1);}

sub set_cdata 
  { delete $_[0]->{empty} if( $_[0]->is_empty);
   return( $_[0]->{'cdata'}= $_[1]); 
  }
sub append_cdata
  { return( $_[0]->{'cdata'}.= $_[1]); 
  }
sub cdata { return $_[0]->{'cdata'}; }
sub cdata_string { return CDATA_START . $_[0]->{cdata} . CDATA_END; }


#start-extract twig_node
sub contains_only_text
  { my $elt= shift;
    return 0 unless $elt->is_elt;
    foreach my $child ($elt->children)
      { return 0 if $child->is_elt; }
    return 1;
  } 

sub root 
  { my $elt= shift;
    while( $elt->{parent}) { $elt= $elt->{parent}; }
    return $elt;
  }
#end-extract twig_node

sub twig 
  { my $elt= shift;
    my $root= $elt->root;
    return $root->{twig};
  }


#start-extract twig_node

# returns undef or the element, depending on whether $elt passes $cond
# $cond can be
# - empty: the element passes the condition
# - ELT ('#ELT'): the element passes the condition if it is a "real" element
# - TEXT ('#TEXT'): the element passes if it is a CDATA or PCDATA element
# - a string: the element passes if its gi is equal to the string
# - a regexp: the element passes if its gi matches the regexp
# - a code ref: the element passes if the code, applied on the element,
#   returns true

  my %cond_cache; # expression => coderef
{ # my %cond_cache; # expression => coderef
 
  sub install_cond
    { my $cond= shift;
      my $sub;


      if( ref $cond eq 'CODE') { return $cond; }
    
      if( ref $cond eq 'Regexp')
        { $sub = qq{return \$_[0] if \$_[0]->gi=~ /$cond/;}; }
      else
      { # the condition is a string
        if( $cond eq ELT)     
          { $sub = qq{return \$_[0] if \$_[0]->is_elt;}; }
        elsif( $cond eq TEXT) 
          { $sub = qq{return \$_[0] if \$_[0]->is_text;}; }
	elsif( $cond=~ m{^\s*($REG_NAME_W)\s*$}o)                  
          { # gi
	    if( $1 ne '*')
	      { # 2 options, depending on whether the gi exists in gi2index
	        # start optimization
	        my $gi= $XML::Twig::gi2index{$1};
	        if( $gi)
	          { # the gi exists, use its index as a faster shortcut
		    $sub = qq{return \$_[0] if \$_[0]->{gi} eq "$XML::Twig::gi2index{$1}";};
		  }
		else
	        # end optimization
                  { # it does not exist (but might be created later), compare the strings
		    $sub = qq{return \$_[0] if \$_[0]->gi eq "$1";}; 
                  }
              }
	    else
	      { $sub = qq{ return \$_[0]; } }
	  }
	elsif( $cond=~ m{^\s*($REG_REGEXP)\s*$}o)
	  { # /regexp/
	    $sub = qq{return \$_[0] if \$_[0]->gi=~ $1;}; 
	  }
	elsif( $cond=~ m{^\s*($REG_NAME_W)?\s*\[\s*\@($REG_NAME)\s*\]\s*$}o)
          { # gi[@att]
	    if( $1 && ($1 ne '*'))
	      { $sub = qq{return \$_[0] if((\$_[0]->gi eq "$1") && (defined \$_[0]->{'att'}->{"$2"}));}; }
	    else
	      { $sub = qq{return \$_[0] if(defined \$_[0]->{'att'}->{"$2"});}; }
	   }
	elsif( $cond=~ m{^\s*($REG_NAME_W)?\s*  # $1
	                 \[\@($REG_NAME)        #   [@$2
			 \s*=\s*                #        =
			 ($REG_STRING)          #          "$3" or '$3'
			 \s*\]\s*$}xo)          #                       ]
          { # gi[@att="val"]
	    if( $1 && ($1 ne '*'))
	      { $sub = qq{return \$_[0] if((\$_[0]->gi eq "$1") && (defined \$_[0]->{'att'}->{"$2"}) && ( \$_[0]->{'att'}->{"$2"} eq $3) );}; }
	    else
	      { $sub = qq{return \$_[0] if((defined \$_[0]->{'att'}->{"$2"}) && ( \$_[0]->{'att'}->{"$2"} eq $3) );}; }
	   }
	elsif( $cond=~ m{^\s*($REG_NAME_W)?\s*  # $1
	                 \[\@($REG_NAME)        #   [@$2
			 \s*=~\s*               #        =~
			 ($REG_REGEXP)          #           /$3/
			 \s*\]\s*$}xo)          #                ]
          { # gi[@att=~ /regexp/]
	    if( $1 && ($1 ne '*'))
	      { $sub = qq{return \$_[0] if((\$_[0]->gi eq "$1") && (defined \$_[0]->{'att'}->{"$2"}) && ( \$_[0]->{'att'}->{"$2"}=~ $3) );}; }
	    else
	      { $sub = qq{return \$_[0] if((defined \$_[0]->{'att'}->{"$2"}) && ( \$_[0]->{'att'}->{"$2"} =~ $3) );}; }
	   }
	elsif( $cond=~ m{^\s*($REG_NAME_W)?\s*      # $1
	                 \[\s*text(?:\(\s*\))?      #   [text()
			 \s*=\s*                    #          =
			 ($REG_STRING)              #           "$2" or '$2'
			 \s*\]\s*$}xo)              #                       ]
          { # gi[text()= "val"]
	    my ($gi, $text)= ($1, $2);
	    if( $gi && ($gi ne '*'))
	      { $sub = qq{return \$_[0] if((\$_[0]->gi eq "$gi") && ( \$_[0]->text eq $text) );}; }
	    else
	      { $sub = qq{return \$_[0] if( \$_[0]->text eq $text) );} ; }
	  }
	elsif( $cond=~ m{^\s*($REG_NAME_W)?\s*       # $1
	                 \[\s*text(?:\(\s*\))?       #   [text()
			 \s*=~\s*                    #          =~
			 ($REG_REGEXP)               #           /$2/
			 \s*\]\s*$}xo)               #                ]
          { # gi[text()=~ /regexp/]
	    if( $1 && ($1 ne '*'))
	      { $sub = qq{return \$_[0] if((\$_[0]->gi eq "$1") && ( \$_[0]->text=~ $2) );}; }
	    else
	      { $sub = qq{return \$_[0] if( \$_[0]->text=~ $2) );}; }
          }
	elsif( $cond=~ m{^\s*($REG_NAME_W)?\s*  # $1
	                 \[\s*text\s*\(\s*      # [text(
			 ($REG_NAME)\s*\)       #       $2)
			 \s*=\s*                #          =
			 ($REG_STRING)          #           "$3" or '$3'
			 \s*\]\s*$}xo)          #                       ]
          { # gi[text(gi2)= "text"]
	    my ($gi, $gi2, $text)= ($1, $2, $3);
	    $text=~ s/([{}])/\\$1/g;
	    #warn "gi: $gi - gi2: $gi2 - text: $text";
	    if( $gi && ($gi ne '*'))
	      { $sub = qq{ return \$_[0] if(    (\$_[0]->gi eq "$gi") 
	                                    && ( \$_[0]->first_child( qq{$gi2\[text()= $text]}))
					   );}; }
	    else
	      { $sub = qq{return \$_[0] if( \$_[0]->first_child(qq{$gi2\[text()= $text]})) ;} ; }
	    #warn "$cond: $sub\n";
	  }
	elsif( $cond=~ m{^\s*($REG_NAME_W)?\s*  # $1
	                 \[\s*text\(\s*         #   [text(
			 ($REG_NAME)\s*\)       #         $2)
			 \s*=~\s*               #            =~
			 ($REG_REGEXP)          #              /$3/
			 \s*\]\s*$}xo)          #                   ]
          { # gi[text(gi2)=~ /regexp/]
	    if( $1 && ($1 ne '*'))
	      { $sub = qq{return \$_[0] if((\$_[0]->gi eq "$1") && ( \$_[0]->field( "$2") =~ $3) );}; }
	    else
	      { $sub = qq{return \$_[0] if( \$_[0]->field( "$2") =~ $3);}; }
          }
	else
	  { croak "wrong condition $cond"; }
      }

      # warn "\n$cond: $sub";
      my $s= eval "sub { $sub }";
      if( $@) { warn "sub: $sub"; croak "wrong navigation condition $cond ($@);" }
      return $s;
    }
 
  sub passes
  
    { my( $elt, $cond)= @_;
      return $elt unless $cond;
      my $sub= ($cond_cache{$cond} ||= install_cond( $cond));
      return $sub->( $elt);
    }
}
# end-extract twig_nodes

sub my_passes
  { my( $elt, $cond)= @_;
    return $elt unless $cond;
    unless( ref $cond)
      { # the condition is a string
        if( $cond eq ELT)     { return $elt if $elt->is_elt;      }
        elsif( $cond eq TEXT) { return $elt if $elt->is_text;     }
	else                  { return $elt if $XML::Twig::index2gi[$elt->{'gi'}] eq $cond; }
      }
    elsif( ref $cond eq 'Regexp')
      { return $elt if $XML::Twig::index2gi[$elt->{'gi'}]=~ $cond; }
    elsif( ref $cond eq 'CODE')
      { return $elt if $cond->($elt); }
    return undef;
  }

sub set_parent 
  { $_[0]->{parent}= $_[1];
    weaken( $_[0]->{parent}) if( $XML::Twig::weakrefs);
    # warn "weakening parent\n" if( $XML::Twig::weakrefs);
  }

#start-extract twig_node
sub parent
  { my $elt= shift;
    my $cond= shift || return $elt->{parent};
    do { $elt= $elt->{parent} || return; } until (!$elt || $elt->passes( $cond));
    return $elt;
  }
#end-extract twig_node

sub set_first_child 
  { delete $_[0]->{empty} if( $_[0]->is_empty);
    $_[0]->{'first_child'}= $_[1]; 
  }

#start-extract twig_node
sub first_child
  { my $elt= shift;
    my $cond= shift || return $elt->{first_child};
    my $child= $elt->{first_child};
    my $test_cond= ($cond_cache{$cond} ||= install_cond( $cond));
    while( $child && !$test_cond->( $child)) 
       { $child= $child->{next_sibling}; }
    return $child;
  }
#end-extract twig_node
  
sub _first_child  { return $_[0]->{first_child};  }
sub _last_child   { return $_[0]->{last_child};   }
sub _next_sibling { return $_[0]->{next_sibling}; }
sub _prev_sibling { return $_[0]->{prev_sibling}; }
sub _parent       { return $_[0]->{parent};       }

# sets a field
# arguments $record, $cond, @content
sub set_field
  { my $record = shift;
    my $cond = shift;
    my $child= $record->first_child( $cond);
    my $new_field= XML::Twig::Elt->new( @_);
    if( $child)
      { $new_field->replace( $child); }
    else
      { $new_field->paste( last_elt => $record); } 
    return $new_field;
  }

sub set_last_child 
  { delete $_[0]->{empty} if( $_[0]->is_empty);
    $_[0]->{'last_child'}= $_[1];
    weaken( $_[0]->{'last_child'}) if( $XML::Twig::weakrefs);
  }

#start-extract twig_node
sub last_child
  { my $elt= shift;
    my $cond= shift || return $elt->{last_child};
    my $test_cond= ($cond_cache{$cond} ||= install_cond( $cond));
    my $child= $elt->{last_child};
    while( $child && !$test_cond->( $child) )
      { $child= $child->{prev_sibling}; }
    return $child
  }
#end-extract twig_node


sub set_prev_sibling 
  { $_[0]->{'prev_sibling'}= $_[1]; 
    weaken( $_[0]->{'prev_sibling'}) if( $XML::Twig::weakrefs); 
  }

#start-extract twig_node
sub prev_sibling
  { my $elt= shift;
    my $cond= shift || return $elt->{prev_sibling};
    my $test_cond= ($cond_cache{$cond} ||= install_cond( $cond));
    my $sibling= $elt->{prev_sibling};
    while( $sibling && !$test_cond->( $sibling) )
          { $sibling= $sibling->{prev_sibling}; }
    return $sibling;
  }
#end-extract twig_node

sub set_next_sibling { $_[0]->{'next_sibling'}= $_[1]; }

#start-extract twig_node
sub next_sibling
  { my $elt= shift;
    my $cond= shift || return $elt->{next_sibling};
    my $test_cond= ($cond_cache{$cond} ||= install_cond( $cond));
    my $sibling= $elt->{next_sibling};
    while( $sibling && !$test_cond->( $sibling) )
          { $sibling= $sibling->{next_sibling}; }
    return $sibling;
  }
#end-extract twig_node

# get or set all attributes
sub set_atts { $_[0]->{'att'}= $_[1]; }
sub atts { return $_[0]->{att}; }
sub att_names { return keys %{$_[0]->{att}}; }
sub del_atts { $_[0]->{att}={}; }

# get or set a single attributes
sub set_att 
  { my $elt= shift;
    while(@_) { my( $att, $val)= (shift, shift);
                $elt->{att}->{$att}= $val;
	      }
  }
sub att { return $_[0]->{att}->{$_[1]}; }
sub del_att 
  { my $elt= shift;
    while( @_) { delete $elt->{'att'}->{shift()}; }
  }

sub set_twig_current { $_[0]->{twig_current}=1; }
sub del_twig_current { delete $_[0]->{twig_current}; }


# get or set the id attribute
sub set_id 
  { my( $elt, $id)= @_;
    $elt->set_att($ID, $_[1]); 
    my $t= $elt->twig || return;
    $elt->twig->{twig_id_list}->{$id}= $elt;
    weaken(  $elt->twig->{twig_id_list}->{$id}) if( $XML::Twig::weakrefs);
  }

sub id { return $_[0]->{'att'}->{$ID}; }

# delete the id attribute and remove the element from the id list
sub del_id 
  { my $elt= shift;
    my $id= $elt->{'att'}->{$ID} or return;
    my $t= $elt->twig && delete $elt->twig->{twig_id_list}->{$id};
    delete $elt->{'att'}->{$ID}; 
  }

# return the list of children
#start-extract twig_node
sub children
  { my $elt= shift;
    my @children;
    my $child= $elt->first_child( @_);
    while( $child) 
      { push @children, $child;
        $child= $child->next_sibling( @_);
      } 
    return @children;
  }

sub children_count
  { my $elt= shift;
    my $cond= shift;
    my $count=0;
    my $child= $elt->{first_child};
    while( $child)
      { $count++ if( $child->passes( $cond)); 
        $child= $child->{next_sibling};
      }
    return $count;
  }


sub all_children_are
  { my( $parent, $cond)= @_;
    foreach my $child ($parent->children)
      { return 0 unless( $child->passes( $cond)); }
    return 1;
  }


sub ancestors
  { my( $elt, $cond)= @_;
    my @ancestors;
    while( $elt->{parent})
      { $elt= $elt->{parent};
        push @ancestors, $elt
          if( $elt->passes( $cond));
      }
    return @ancestors;
  }


sub inherit_att
  { my $elt= shift;
    my $att= shift;
    my %tags= map { ($_, 1) } @_;

    do 
      { if(   (defined $elt->{'att'}->{$att})
           && ( !%tags || $tags{$XML::Twig::index2gi[$elt->{'gi'}]})
          )
          { return $elt->{'att'}->{$att}; }
      } while( $elt= $elt->{parent});
    return undef;
  }


# kinda counter-intuitive actually:
# the next element is found by looking for the next open tag after from the
# current one, which is the first child, if it exists, or the next sibling
# or the first next sibling of an ancestor
# optional arguments are: 
#   - $subtree_root: a reference to an element, when the next element is not 
#                    within $subtree_root anymore then next_elt returns undef
#   - $gi: a gi, next_elt returns the next element of this gi
                 
sub next_elt
  { my $elt= shift;
    my $subtree_root= 0;
    $subtree_root= shift if( UNIVERSAL::isa( $_[0], 'XML::Twig::Elt'));
    my $cond= shift;
    my $next_elt;

    my $ind;                                                             # optimization
    my $test_cond;
    if( $cond)                                                           # optimization
      { unless( defined( $ind= $XML::Twig::gi2index{$cond}) )            # optimization
          { $test_cond= ($cond_cache{$cond} ||= install_cond( $cond)); } # optimization
      }                                                                  # optimization
    
    do
      { if( $next_elt= $elt->{first_child})
          { # simplest case: the elt has a child
          }
         elsif( $next_elt= $elt->{next_sibling}) 
          { # no child but a next sibling (just check we stay within the subtree)
          
            # case where elt is subtree_root, is empty and has a sibling
            return undef if( $subtree_root && ($elt == $subtree_root));
            
          }
        else
          { # case where the element has no child and no next sibling:
            # get the first next sibling of an ancestor, checking subtree_root 
          
            # case where elt is subtree_root, is empty and has no sibling
            return undef if( $subtree_root && ($elt == $subtree_root));
             
            # backtrack until we find a parent with a next sibling
            $next_elt= $elt->{parent} || return undef;
            until( $next_elt->{next_sibling})
              { return undef if( $subtree_root && ($subtree_root == $next_elt));
                $next_elt= $next_elt->{parent} || return undef;
              }
            return undef if( $subtree_root && ($subtree_root == $next_elt)); 
            $next_elt= $next_elt->{next_sibling};   
          }  
	  $elt= $next_elt;                   # just in case we need to loop
	} until(    ! defined $elt 
	         || ! defined $cond 
		 || (defined $ind       && ($elt->{gi} eq $ind))   # optimization
		 || (defined $test_cond && ($test_cond->( $elt)))
               );
	
      return $elt;
      }

# counter-intuitive too:
# the previous element is found by looking
# for the first open tag backwards from the current one
# it's the last descendant of the previous sibling 
# if it exists, otherwise it's simply the parent
sub prev_elt
  { my $elt= shift;
    my $cond= shift;
    # get prev elt
    my $prev_elt;
    do
      { if( $prev_elt= $elt->{prev_sibling})
          { while( $prev_elt->{last_child})
              { $prev_elt= $prev_elt->{last_child}; }
          }
        else
          { $prev_elt= $elt->{parent} || return; }
        $elt= $prev_elt;     # in case we need to loop 
      } until( $elt->passes( $cond));

    return $prev_elt;
  }


# checks whether $elt is included in $ancestor, returns 1 in that case
sub in($$)
  { my ($elt, $ancestor)= @_;
    while( $elt= $elt->{parent}) { return 1 if( $elt ==  $ancestor); }
    return 0;           
  }

# create the _text and _matches methods
BEGIN
  { foreach my $nav ( 'first_child', 'last_child', 
                      'prev_sibling', 'next_sibling',
                      'prev_elt', 'next_elt', 'parent')
      { no strict 'refs';
        my $text_method= $nav . "_text";
        *{$text_method}= sub { my $elt= shift;
                               my $dest=$elt->$nav(@_) or return '';
                               return $dest->text;
                             };
        my $matches_method= $nav . "_matches";
        *{$matches_method}= sub { my $elt= shift;
                                  my $dest= $elt->$nav or return undef;
                                  return $dest->passes( @_);
                                };
        $matches_method= $nav . "_is";
        *{$matches_method}= sub { my $elt= shift;
                                  my $dest= $elt->$nav or return undef;
                                  return $dest->passes( @_);
                                };
      }
  }

# returns the depth level of the element
# if 2 parameter are used then counts the 2cd element name in the
# ancestors list
sub level
  { my $elt= shift;
    my $level=0;
    my $name=shift || '';
    while( $elt= $elt->{parent}) { $level++ if( !$name || ($name eq $XML::Twig::index2gi[$elt->{'gi'}])); }
    return $level;           
  }

# checks whether $elt has an ancestor type $gi, returns the ancestor
sub in_context
  { my ($elt, $gi, $level)= @_;
    $level= -1 unless( $level) ;  # $level-- will never hit 0

    while( $level && $elt->{parent})
      { if( $XML::Twig::index2gi[$elt->{'gi'}] eq $gi) { return $elt; }
        $elt= $elt->{parent};
        $level--;
      }
    return ;           
  }

sub descendants
  { my( $subtree_root, $cond)= @_;
    my @descendants=(); 
    my $elt= $subtree_root;
    
    # this branch is pure optimisation for speed: if $cond is a gi replace it
    # by the index of the gi and loop here 
    # start optimization
    my $ind;
    if( !$cond || ( defined ( $ind= $XML::Twig::gi2index{$cond})) )
      {
        my $next_elt;

        while( 1)  
          { if( $next_elt= $elt->{first_child})
                { # simplest case: the elt has a child
                }
             elsif( $next_elt= $elt->{next_sibling}) 
              { # no child but a next sibling (just check we stay within the subtree)
           
                # case where elt is subtree_root, is empty and has a sibling
                last if( $subtree_root && ($elt == $subtree_root));
              }
            else
              { # case where the element has no child and no next sibling:
                # get the first next sibling of an ancestor, checking subtree_root 
                
                # case where elt is subtree_root, is empty and has no sibling
                last if( $subtree_root && ($elt == $subtree_root));
               
                # backtrack until we find a parent with a next sibling
                $next_elt= $elt->{parent} || last undef;
                until( $next_elt->{next_sibling})
                  { last if( $subtree_root && ($subtree_root == $next_elt));
                    $next_elt= $next_elt->{parent} || last;
                  }
                last if( $subtree_root && ($subtree_root == $next_elt)); 
                $next_elt= $next_elt->{next_sibling};   
              }  
	    $elt= $next_elt || last;
            push @descendants, $elt if( !$cond || ($elt->{gi} eq $ind));
	  }
      }
    else
    # end optimization
      { # branch for a complex condition: use the regular (slow but simple) way
        while( $elt= $elt->next_elt( $subtree_root, $cond))
          { push @descendants, $elt; }
      }
    return @descendants;
  }
  
sub descendants_or_self
  { my( $elt, $cond)= @_;
    my @descendants= $elt->passes( $cond) ? ($elt) : (); 
    push @descendants, $elt->descendants( $cond);
    return @descendants;
  }
  
sub sibling
  { my $elt= shift;
    my $nb= shift;
    if( $nb > 0)
      { foreach( 1..$nb)
          { $elt= $elt->next_sibling( @_) or return undef; }
      }
    elsif( $nb < 0)
      { foreach( 1..(-$nb))
          { $elt= $elt->prev_sibling( @_) or return undef; }
      }
    else # $nb == 0
      { return $elt->passes( $_[0]); }
    return $elt;
  }

sub sibling_text
  { my $elt= sibling( @_);
    return $elt ? $elt->text : undef;
  }


sub child
  { my $elt= shift;
    my $nb= shift;
    if( $nb >= 0)
      { $elt= $elt->first_child( @_) or return undef;
        foreach( 1..$nb)
          { $elt= $elt->next_sibling( @_) or return undef; }
      }
    else
      { $elt= $elt->last_child( @_) or return undef;
        foreach( 2..(-$nb))
          { $elt= $elt->prev_sibling( @_) or return undef; }
      }
    return $elt;
  }

sub child_text
  { my $elt= child( @_);
    return $elt ? $elt->text : undef;
  }

sub prev_siblings
  { my $elt= shift;
    my @siblings=();
    while( $elt= $elt->prev_sibling( @_))
      { unshift @siblings, $elt; }
    return @siblings;
  }

sub next_siblings
  { my $elt= shift;
    my @siblings=();
    while( $elt= $elt->next_sibling( @_))
      { push @siblings, $elt; }
    return @siblings;
  }

# used by get_xpath: parses the xpath expression and generates a sub that performs the
# search
# used by get_xpath: parses the xpath expression and generates a sub that performs the
# search
sub install_xpath
  { my( $xpath_exp, $type)= @_;
    my $original_exp= $xpath_exp;
    my $sub= 'my $elt= shift; my @results=();';
    
    # grab the root if expression starts with a /
    if( $xpath_exp=~ s{^/}{})
      { $sub .= '@results= ($elt->twig);'; }
    elsif( $xpath_exp=~ s{^\./}{})
      { $sub .= '@results= ($elt);'; }
    else
      { $sub .= '@results= ($elt);'; }

    while( $xpath_exp &&
           $xpath_exp=~s{^\s*(/?)                            
                          # the xxx=~/regexp/ is a pain as it includes /  
                          (\s*([\w:-_]+\s*)?\[\s*(string\(\s*\)|@[\w:_-]+)\s*=~  
                            \s*/([^\\/]|\\.)*/\s*\]\s* 
                          # or a regular condition, with no / excepts \/
                          |([^\\/]|\\.)*
                          )
                          (/|$)}{}x)

      { my $wildcard= $1;
        my $sub_exp= $2;
        
        # grab a parent
        if( $sub_exp eq '..')
          { croak "error in xpath expression $original_exp" if( $wildcard);
            $sub .= '@results= map { $_->{parent}} @results;';
          }
        # grab children
        elsif( $sub_exp=~ m{([^\[]+)\s*               # * or a gi    ($1)
                       (?:\[([^\]]*))?\s*}xs)         # optional condition ($2)
          { my $gi= $1 unless( $1 eq '*');
            my $cond= $2; 
            if( $cond) { $cond=~ s{^\s*}{}; $cond=~ s{\s*$}{}; }
            my $function;
            

            # "special" conditions, that return just one element
            if( $cond && ($cond =~ m{^((-\s*)?\d+)$}) )
              { my $offset= $1;
	        $offset-- if( $offset > 0);
                $function=  $wildcard ? "next_n_elt( $offset, '$gi')" 
                                      : "child( $offset, '$gi')";
                $sub .= "\@results= map { \$_->$function } \@results;"
              }
            elsif( $cond && ($cond =~ m{^last\s*\(\s*\)$}) )
              { croak "error in xpath expression $original_exp, cant use // and last()"
                  if( $wildcard);
                 $sub .= "\@results= map { \$_->last_sibling( '$gi') } \@results;";
              }
            else
              { # go down and get the children or descendants
                unless ( defined $gi)
                  { if( $wildcard)
                      { $sub .= '@results= map { $_->descendants  } @results;' }
                    else
                      { $sub .= '@results= map { $_->children } @results;'; }
                  }
                else
                  { if( $wildcard)
                      { $sub .= "\@results= map { \$_->descendants( '$gi')  } \@results;";  }            
                    else
                      { $sub .= "\@results= map { \$_->children( '$gi')  } \@results;"; }
                  } 
                # now filter using the condition
                if( $cond)
                  { my $op='';
                    my $test="";
                    do
                      { if( $op)
                          { $cond=~ s{^\s*$op\s*}{};
                            $op= lc( $op);
                            $test .= $op;
                          }
                      
                       if( $cond =~ s{^string\(\s*\)\s*=\s*($REG_STRING)\s*}{}o)  # string()="string" cond
                          { $test .= "\$_->text eq $1"; 
                          }
                       elsif( $cond =~ s{^string\(\s*\)\s*=~\s*/(([^/\\]|\\.)*)/\s*}{})  # string()=~/regex/ cond
                          { $test .= "\$_->text=~/$1/"; 
                          }
                       elsif( $cond=~ s{^@([^=\s]+)\s*=\s*($REG_STRING)}{}o)  # @att="val" cond
                          { $test .= qq{((defined \$_->{'att'}->{"$1"})  && (\$_->{'att'}->{"$1" } eq $2))};
                          }
                       elsif( $cond =~ s{^@([^=\s]+)\s*=~\s*/(([^/\\]|\\.)*)/\s*}{})  # @att=~/regex/ cond
                          { $test .= qq{((defined \$_->{'att'}->{"$1"})  && (\$_->{'att'}->{"$1" }=~ /$3/))};; 
                          }
                       elsif( $cond=~ s{^@([\w:-]+)\s*}{})                      # @att cond
                          { $test .= qq{(defined \$_->{'att'}->{"$1"})};
                          }
                       } while( ($op)=($cond=~ m{^\s*(and|or)\s*}i));
                     croak "error in xpath expression $original_exp at $cond" if( $cond);
                     $sub .= "\@results= grep { $test } \@results;";
                   }
              }
          }
        else
          { croak "error in xpath expression $original_exp around $sub_exp"; }
      }

    if( $xpath_exp)
      { croak "error in xpath expression $original_exp around $xpath_exp"; }
      
    $sub .= "return \@results; ";
    # warn "installing $_[0] => $sub\n\n";
    my $s= eval "sub { $sub }";
    if( $@) { croak "error in xpath expression $original_exp ($@);" }
    return( $s); 
   }
        
{ # extremely elaborate caching mechanism
  my %xpath; # xpath_expression => subroutine_code;  
  sub get_xpath
    { my( $elt, $xpath_exp, $offset)= @_;
      my $sub= ($xpath{$xpath_exp} ||= XML::Twig::Elt::install_xpath( $xpath_exp));
      return $sub->( $elt) unless( defined $offset); 
      my @res= $sub->( $elt);
      return $res[$offset];
    }
    1; # so the module returns 1 as this is the last BEGIN block in the file
}


#end-extract twig_node

sub flushed { return $_[0]->{'flushed'}; }
sub set_flushed { $_[0]->{'flushed'}=1; }
sub del_flushed { delete $_[0]->{'flushed'}; }


sub cut
  { my $elt= shift;
    my( $parent, $prev_sibling, $next_sibling, $last_elt);

    # you can't cut the root, sorry
    unless( $parent= $elt->{parent}) 
      { return; }
    # it we cut the current element then its parent becomes the current elt
    if( $elt->{twig_current})
      { my $twig_current= $elt->{parent};
        my $t= $elt->twig;
        $t->{twig_current}= $twig_current;
        $twig_current->{'twig_current'}=1;
        delete $elt->{'twig_current'};
      }

    $parent->{first_child}=  $elt->{next_sibling} 
      if( $parent->{first_child} == $elt);
    $parent->set_last_child( $elt->{prev_sibling}) 
      if( $parent->{last_child} == $elt);

    if( $prev_sibling= $elt->{prev_sibling})
      { $prev_sibling->{next_sibling}=  $elt->{next_sibling}; }
    if( $next_sibling= $elt->{next_sibling})
      { $next_sibling->set_prev_sibling( $elt->{prev_sibling}); }


    $elt->set_parent( undef);
    $elt->set_prev_sibling( undef);
    $elt->{next_sibling}=  undef;

    return $elt;
  }


sub erase
  { my $elt= shift;
    #you cannot erase the current element
    if( $elt->{twig_current})
      { croak "trying to erase an element before it has been completely parsed"; }
    unless( $elt->{parent})
      { croak "cannot erase an element with no parent"; }

    my @children= $elt->children;
    if( @children)
      { # elt has children, move them up
        if( $elt->{prev_sibling})
          { # connect first child to previous sibling
            $elt->{first_child}->set_prev_sibling( $elt->{prev_sibling});      
            $elt->{prev_sibling}->set_next_sibling( $elt->{first_child}); 
          }
        else
          { # elt was the first child
            $elt->{parent}->set_first_child( $elt->{first_child});
          }
        if( $elt->{next_sibling})
          { # connect last child to next sibling
            $elt->{last_child}->set_next_sibling( $elt->{next_sibling});      
            $elt->{next_sibling}->set_prev_sibling( $elt->{last_child}); 
          }
        else
          { # elt was the last child
            $elt->{parent}->set_last_child( $elt->{last_child});
          }
        # update parent for all siblings
        foreach my $child (@children)
          { $child->set_parent( $elt->{parent}); }
      }
    else
      { # elt had no child
        if( $elt->{prev_sibling})
          { # connect previous sibling to next sibling (can be undef)
            $elt->{prev_sibling}->set_next_sibling( $elt->{next_sibling});      
          }
        else
          { # elt was the first child
            $elt->{parent}->set_first_child( $elt->{next_sibling});
          }
        if( $elt->{next_sibling})
          { # connect next sibling to previous sibling (can be undef)
            $elt->{next_sibling}->set_prev_sibling( $elt->{prev_sibling}); 
          }
        else
          { # elt was the last child
            $elt->{parent}->set_last_child( $elt->{next_sibling});
          }
      }

    # elt is not referenced any more, so it will be DESTROYed
    # so we'd better break the links to its children
    undef $elt->{'first_child'};
    undef $elt->{'last_child'};
    undef $elt->{'parent'};
    undef $elt->{'prev_sibling'};
    undef $elt->{'next_sibling'};

  }
        

BEGIN
  { my %method= ( before      => \&paste_before,
                  after       => \&paste_after,
		  first_child => \&paste_first_child,
		  last_child  => \&paste_last_child,
		  within      => \&paste_within,
		);
	
    # paste elt somewhere around ref
    # pos can be first_child (default), last_child, before, after or within
    sub paste
      { my $elt= shift;
        if( $elt->{parent}) 
          { croak "cannot paste an element that belongs to a tree"; }
        my $pos;
        my $ref;
        if( ref $_[0]) 
          { $pos= 'first_child'; 
            croak "wrong argument order in paste, should be $_[1] first" 
	      if($_[1]); 
          }
        else
          { $pos= shift; }

    if( my $method= $method{$pos})
      { $elt->$method( @_); }
    else
      { croak "tried to paste in wrong position ($pos), allowed positions " . 
              " are 'first_child', 'last_child', 'before', 'after' and "    .
	      "'within'";
      }
  }
  

    sub paste_before
      { my( $elt, $ref)= @_;
        my( $parent, $prev_sibling, $next_sibling );
        unless( $ref->{parent}) { croak "cannot paste before root"; }
        $parent= $ref->{parent};
        $prev_sibling= $ref->{prev_sibling};
        $next_sibling= $ref;

        $elt->set_parent( $parent);
        $parent->{first_child}=  $elt if( $parent->{first_child} == $ref);

        $prev_sibling->{next_sibling}=  $elt if( $prev_sibling);
        $elt->set_prev_sibling( $prev_sibling);

        $next_sibling->set_prev_sibling( $elt);
        $elt->{next_sibling}=  $ref;
      }
     
     sub paste_after
      { my( $elt, $ref)= @_;
        my( $parent, $prev_sibling, $next_sibling );
        unless( $ref->{parent}) { croak "cannot paste after root"; }
        $parent= $ref->{parent};
        $prev_sibling= $ref;
        $next_sibling= $ref->{next_sibling};

        $elt->set_parent( $parent);
        $parent->set_last_child( $elt) if( $parent->{last_child}== $ref);

        $prev_sibling->{next_sibling}=  $elt;
        $elt->set_prev_sibling( $prev_sibling);

        $next_sibling->set_prev_sibling( $elt) if( $next_sibling);
        $elt->{next_sibling}=  $next_sibling;

      }

    sub paste_first_child
      { my( $elt, $ref)= @_;
        my( $parent, $prev_sibling, $next_sibling );
        $parent= $ref;
        $next_sibling= $ref->{first_child};
        delete $ref->{empty} if( $ref->is_empty);

        $elt->set_parent( $parent);
        $parent->{first_child}=  $elt;
        $parent->set_last_child( $elt) unless( $parent->{last_child});

        $elt->set_prev_sibling( undef);

        $next_sibling->set_prev_sibling( $elt) if( $next_sibling);
        $elt->{next_sibling}=  $next_sibling;

      }
      
    sub paste_last_child
      { my( $elt, $ref)= @_;
        my( $parent, $prev_sibling, $next_sibling );
        $parent= $ref;
        $prev_sibling= $ref->{last_child};
        delete $ref->{empty} if( $ref->is_empty);

        $elt->set_parent( $parent);
        $parent->set_last_child( $elt);
        $parent->{first_child}=  $elt unless( $parent->{first_child});

        $elt->set_prev_sibling( $prev_sibling);
        $prev_sibling->{next_sibling}=  $elt if( $prev_sibling);

        $elt->{next_sibling}=  undef;

      }

    sub paste_within
      { my( $elt, $ref, $offset)= @_;
        my( $parent, $prev_sibling, $next_sibling );
        my $new= $ref->split( $offset);
	$elt->paste_before( $new);
      }
  }

# split a text element at a given offset
sub split_at
  { my( $elt, $offset)= @_;
    unless( $elt->is_text)
      { $elt= $elt->first_child( TEXT) || return ''; }
    my $string= $elt->text; 
    my $left_string= substr( $string, 0, $offset);
    my $right_string= substr( $string, $offset);
    $elt->{pcdata}=  $left_string;
    my $new_elt= XML::Twig::Elt->new( $XML::Twig::index2gi[$elt->{'gi'}], $right_string);
    $new_elt->paste( 'after', $elt);
    return $new_elt;
  }

    
# split an element or its text descendants into several, in place
# all elements (new and untouched) are returned
sub split    
  { my $elt= shift;
    my @text_chunks;
    my @result;
    if( $elt->is_text) { @text_chunks= ($elt); }
    else               { @text_chunks= $elt->descendants( '#TEXT'); }
    foreach my $text_chunk (@text_chunks)
      { push @result, $text_chunk->_split( 1, @_); }
    return @result;
  }

# split an element or its text descendants into several, in place
# created elements (those which match the regexp) are returned
sub mark
  { my $elt= shift;
    my @text_chunks;
    my @result;
    if( $elt->is_text) { @text_chunks= ($elt); }
    else               { @text_chunks= $elt->descendants( '#TEXT'); }
    foreach my $text_chunk (@text_chunks)
      { push @result, $text_chunk->_split( 0, @_); }
    return @result;
  }

# split a single text element
# return_all defines what is returned: if it is true 
# only returns the elements created by matches in the split regexp
# otherwise all elements (new and untouched) are returned
sub _split
  { my $elt= shift;
    my $return_all= shift;
    my( $regexp, $tag, $atts)= @_;
    my @result;                                 # the returned list of elements
    my $text= $elt->text;
    my $gi= $XML::Twig::index2gi[$elt->{'gi'}];
    $tag||= $gi;                                # default: same tag as $elt
    $atts ||= {};                               # default: no attributes

    # 2 uses: if split matches then the first substring reuses $elt
    #         once a split has occured then the last match needs to be put in
    #         a new element      
    my $replaced= 0;

    # emulate the split built-in: break on \s+ (probably useless!)
    $regexp ||= " ";
    if( $regexp eq " ") { $regexp= '\s+'; }

    while( $text=~/(.*?)(?:($regexp)|$)/sg)
      { # $1 is the pre-regexp match
        # $2 is the string that matches the regexp (if true then the regexp 
        #    matched, otherwise $ matched)
        # $3...$n are captured by the regexp (and should be wrapped in tag)
        if( defined $2 || $replaced)
          { # the regexp matched this time ($2) or previously ($replaced)
            unless( $replaced)
              { # first match in $elt, re-use $elt for the first sub-string
                $elt->set_text( $1);
                $replaced++;                     # note that there was a match
                push @result, $elt if( $return_all);
              }
            else
              { # match, not the first one, create a new text ($gi) element
                my $new_text= XML::Twig::Elt->new( $gi, $1);
                $new_text->paste( 'after', $elt); # paste it after $elt
                $elt= $new_text;                  # $elt: element to paste after
                push @result, $elt if( $return_all);
              }
            # now deal with matches captured in the regexp
            no strict( 'refs');                   # needed to access $3...$n
            for( my $match=3; defined $$match; $match++)
              { # create new element, text is the match
                my %atts= %$atts; # or the same atts is used for all matches!
                my $new_text= XML::Twig::Elt->new( $tag, \%atts, $$match);
                $new_text->paste( 'after', $elt); # paste it after the current
                $elt= $new_text;                  # it becomes the current elt
                push @result, $elt;
              }
          }
        else
          { # the regep did not match at all, $elt is not changed
            push @result, $elt if( $return_all);
          }
      } 
    return @result; # return all elements
 }


# recursively copy an element and returns the copy (can be huge and long)
sub copy
  { my $elt= shift;
    my $copy= XML::Twig::Elt->new( $XML::Twig::index2gi[$elt->{'gi'}]);

    if( $elt->extra_data)
      { $copy->set_extra_data( $elt->extra_data) }

    if( (exists $elt->{'pcdata'}))
      { $copy->{pcdata}=  $elt->{pcdata}; }
    elsif( (exists $elt->{'cdata'}))
      { $copy->{cdata}=  $elt->{cdata}; }
    elsif( (exists $elt->{'target'}))
      { $copy->set_pi( $elt->{target}, $elt->{data}); }
    elsif( (exists $elt->{'comment'}))
      { $copy->{comment}=  $elt->{comment}; }
    elsif( (exists $elt->{'ent'}))
      { $copy->{ent}=  $elt->{ent}; }
    else
      { my @children= $elt->children;
        if( my $atts= $elt->atts)
          { my %atts= %{$atts}; # we want to do a real copy of the attributes
            $copy->{'att'}=  \%atts;
          }
        foreach my $child (@children)
          { my $child_copy= $child->copy;
            $child_copy->paste( 'last_child', $copy);
          }
      }
    return $copy;
  }

sub delete
  { my $elt= shift;
    $elt->cut;
    $elt->DESTROY;
  }

sub DESTROY
  { my $elt= shift;

    return if( $XML::Twig::weakrefs);

    foreach( @{[$elt->children]}) { XML::Twig::Elt::DESTROY($_); }
    # destroy all references in the tree
    delete $elt->{'parent'};
    delete $elt->{'first_child'};
    delete $elt->{'last_child'};
    delete $elt->{'prev_sibling'};
    delete $elt->{'next_sibling'};
    # the id reference also needs to be destroyed
    $elt->del_id if( $ID && exists $elt->{att}->{$ID});
    delete $elt->{'att'};         # $elt->{'att'}=  undef;
    $elt= undef;
  }


# to be called only from a start_tag_handler: ignores the current element
sub ignore
  { my $elt= shift;
    my $t= $elt->twig;
    $t->ignore( $elt);
  }

BEGIN {
  my $pretty=0;
  my $quote='"';
  my $INDENT= '  ';
  my $empty_tag_style= 0;
  my $keep_encoding= 0;
  my $expand_external_entities= 0;

  my ($NSGMLS, $NICE, $INDENTED, $RECORD1, $RECORD2)= (1..5);

  my %pretty_print_style=
    ( none     => 0,         # no added \n
      nsgmls   => $NSGMLS,   # nsgmls-style, \n in tags
      # below this line styles are UNSAFE (the generated XML can be invalid)
      nice     => $NICE,     # \n after open/close tags except when the element
                            # starts with text
      indented => $INDENTED, # nice plus idented
      record_c => $RECORD1,  # for record-like data (compact)
      record   => $RECORD2,  # for record-like data  (not so compact)
    );

  my ($HTML, $EXPAND)= (1..2);
  my %empty_tag_style=
    ( normal => 0,        # <tag/>
      html   => $HTML,    # <tag />
      xhtml  => $HTML,    # <tag />
      expand => $EXPAND,  # <tag></tag>
    );

  my %quote_style=
    ( double  => '"',    
      single  => "'", 
      # smart  => "smart", 
    );

  my $output_filter;

  # set the pretty_print style (in $pretty) and returns the old one
  # can be called from outside the package with 2 arguments (elt, style)
  # or from inside with only one argument (style)
  # the style can be either a string (one of the keys of %pretty_print_style
  # or a number (presumably an old value saved)
  sub set_pretty_print
    { my $style= lc( $_[1] || $_[0]); # so we cover both cases 
      my $old_pretty= $pretty;
      if( $style=~ /^\d+$/)
        { croak "illegal pretty print style $style"
	    unless( $style < keys %pretty_print_style);
	    $pretty= $style;
	}
      else
        { croak "illegal pretty print style $style"
            unless( exists $pretty_print_style{$style});
          $pretty= $pretty_print_style{$style};
	}
      return $old_pretty;
    }
  
  
  # set the empty tag style (in $empty_tag_style) and returns the old one
  # can be called from outside the package with 2 arguments (elt, style)
  # or from inside with only one argument (style)
  # the style can be either a string (one of the keys of %empty_tag_style
  # or a number (presumably an old value saved)
  sub set_empty_tag_style
    { my $style= lc( $_[1] || $_[0]);  # works whether called on an elt or
                                       # just as a regular function call
      my $old_style= $empty_tag_style;
      if( $style=~ /^\d+$/)
        { croak "illegal empty tag style $style"
	    unless( $style < keys %empty_tag_style);
	    $empty_tag_style= $style;
	}
      else
        { croak "illegal empty_tag stype style $style"
            unless( exists $empty_tag_style{$style});
          $empty_tag_style= $empty_tag_style{$style};
	}
      return $old_style;
    }
      
  sub set_quote
    { my $style= $_[1] || $_[0];
      my $old_quote= $quote;
      croak "illegal quote style $_[1]"
        unless( exists $quote_style{$style});
      $quote= $quote_style{$style};
      return $old_quote;
    }
      
  sub set_indent
    { my $new_value= defined $_[1] ? $_[1] : $_[0];
      my $old_value= $INDENT;
      $keep_encoding= $new_value;
      return $old_value;
    }
       
  sub set_keep_encoding
    { my $new_value= defined $_[1] ? $_[1] : $_[0];
      my $old_value= $keep_encoding;
      $keep_encoding= $new_value;
      return $old_value;
    
   }

  sub set_output_filter
    { my $new_value= defined $_[1] ? $_[1] : $_[0];
      my $old_value= $output_filter;
      if( !$new_value || UNIVERSAL::isa( $new_value, 'CODE') )
        { $output_filter= $new_value; }
      elsif( $new_value eq 'latin1')
        { $output_filter= XML::Twig::latin1(); }
      elsif( $XML::Twig::filter{$new_value})
        {  $output_filter= $XML::Twig::filter{$new_value}; }
      else
        { croak "invalid output filter: $new_value"; }
      
      return $old_value;
    }
       
  sub set_expand_external_entities
    { my $new_value= defined $_[1] ? $_[1] : $_[0];
      my $old_value= $expand_external_entities;
      $expand_external_entities= $new_value;
      return $old_value;
    }
       
  # $elt is an element to print
  # $pretty is an optionnal value, if true a \n is printed after the <
  sub start_tag
    { my $elt= shift;
  
      return if( $elt->{gi}<$XML::Twig::SPECIAL_GI);
  
      my $tag="<" . $XML::Twig::index2gi[$elt->{'gi'}];
  
      # get the attribute and their values
      my $att= $elt->atts;
      if( $att)
        { foreach my $att_name (sort keys %{$att}) 
           { # skip private attributes (they start with #)
             next if( substr( $att_name, 0,1) eq '#');

             if( $pretty==$NSGMLS) { $tag .= "\n"; } 
             else                  { $tag .= ' ';  }
             $tag .=   $att_name . '=' . $quote  
	             . $elt->att_xml_string( $att_name, $quote) . 
		       $quote; 
           }
        } 
  
      $tag .= "\n" if($pretty==$NSGMLS);

      if( $elt->{empty})
        { if( !$empty_tag_style)
            { $tag .= "/>";     }
          elsif( $empty_tag_style eq $HTML)
            { $tag .= " />";  }
	  else #  $empty_tag_style eq $EXPAND
            { $tag .= "></" . $XML::Twig::index2gi[$elt->{'gi'}] .">";  }
        }
      else
        { $tag .= ">"; }

      return $tag unless $pretty;

      my $prefix='';
      my $return=0;    # 1 if a \n is to be printed before the tag
      my $indent=0;    # number of indents before the tag

      if( $pretty==$RECORD1)
        { my $level= $elt->level;
          $return= 1 if( $level < 2);
          $indent= 1 if( $level == 1);
        }

     elsif( $pretty==$RECORD2)
        { $return= 1;
          $indent= $elt->level;
        }

      elsif( $pretty==$NICE)
        { my $parent= $elt->{parent};
          unless( !$parent || $parent->{contains_text}) 
            { $return= 1; }
          $elt->{contains_text}= 1 if( ($parent && $parent->{contains_text})
                                     || $elt->contains_text);
        }

      elsif( $pretty==$INDENTED)
        { my $parent= $elt->{parent};
          unless( !$parent || $parent->{contains_text}) 
            { $return= 1; 
              $indent= $elt->level; 
            }
          $elt->{contains_text}= 1 if( ($parent && $parent->{contains_text})
                                     || $elt->contains_text);
        }

      if( $return || $indent)
        { # check for elements in which spaces should be kept
	  my $t= $elt->twig;
	  if( $t && $t->{twig_keep_spaces_in})
	    { foreach my $ancestor ($elt->ancestors)
	        { return $tag if( $t->{twig_keep_spaces_in}->{$XML::Twig::index2gi[$ancestor->{'gi'}]}) }
            }
	    
	  $prefix= "\n" if( $return and !$elt->{extra_data});
          $prefix.= $INDENT x $indent;
	}
              
      return $prefix . $tag;

    }
  
  sub end_tag
    { my $elt= shift;
      return  '' if( ($elt->{gi}<$XML::Twig::SPECIAL_GI) || ($elt->{'empty'} || 0));
      my $tag= "<";
      $tag.= "\n" if($pretty==$NSGMLS);
      $tag .=  "/$XML::Twig::index2gi[$elt->{'gi'}]>";

      $tag = ($elt->{extra_data_before_end_tag} || '') . $tag;

      return $tag unless $pretty;

      my $prefix='';
      my $return=0;    # 1 if a \n is to be printed before the tag
      my $indent=0;    # number of indents before the tag

      if( $pretty==$RECORD1)
        { $return= 1 if( $elt->level == 0);
        }

     elsif( $pretty==$RECORD2)
        { unless( $elt->contains_text)
            { $return= 1 ;
              $indent= $elt->level;
            }
        }

      elsif( $pretty==$NICE)
        { my $parent= $elt->{parent};
          unless( ($parent || $parent->{contains_text}) || $elt->{contains_text}
                  || !$elt->_first_child() ) 
            { $return= 1; }
        }

      elsif( $pretty==$INDENTED)
        { my $parent= $elt->{parent};
          unless( ($parent || $parent->{contains_text}) || $elt->{contains_text}
                  || !$elt->_first_child() ) 
            { $return= 1; 
              $indent= $elt->level; 
            }
        }

      if( $return || $indent)
        { # check for elements in which spaces should be kept
	  my $t= $elt->twig;
	  if( $t && $t->{twig_keep_spaces_in})
	    { foreach my $ancestor ($elt, $elt->ancestors)
	        { return $tag if( $t->{twig_keep_spaces_in}->{$XML::Twig::index2gi[$ancestor->{'gi'}]}) }
            }
      
          $prefix= "\n" if( $return);
          $prefix.= $INDENT x $indent;
	}
              
      return $prefix . $tag;
    }

  sub pretty_print
    { print( @_); }

  # $elt is an element to print
  # $fh is an optionnal filehandle to print to
  # $pretty is an optionnal value, if true a \n is printed after the < of the
  # opening tag
  sub print
    { my $elt= shift;
  
      my $pretty;
      my $fh=  shift if( defined( $_[0]) && UNIVERSAL::isa($_[0], 'GLOB') );
      my $old_select= select $fh if( defined $fh);
      my $old_pretty= set_pretty_print( $pretty) if( defined ($pretty= shift));
  
      $elt->_print;
    
      select $old_select if( defined $old_select);
      set_pretty_print( $old_pretty) if( defined $old_pretty);
    }
      
 sub _print
   { my $elt= shift;
      # in case there's some comments or PI's piggybacking
      if( $elt->{extra_data})
        { print $output_filter ? $output_filter->($elt->{extra_data}) 
                               : $elt->{extra_data};
        }

      if( $elt->{gi} >= $XML::Twig::SPECIAL_GI)
        { print $output_filter ? $output_filter->($elt->start_tag()) 
                               : $elt->start_tag();
  
          # print the children
          my $child= $elt->{first_child};
          while( $child)
            { $child->_print();
              $child= $child->{next_sibling};
            }
          print $output_filter ? $output_filter->($elt->end_tag()) 
                               : $elt->end_tag;
        }
      else # text or special element
        { my $text='';
          if( (exists $elt->{'pcdata'}))     { $text= $elt->pcdata_xml_string;  }
          elsif( (exists $elt->{'cdata'}))   { $text= $elt->cdata_string;       }
          elsif( (exists $elt->{'target'}))      { $text= $elt->pi_string;          }
          elsif( (exists $elt->{'comment'})) { $text= $elt->comment_string;     }
          elsif( (exists $elt->{'ent'}))     { $text= $elt->ent_string;         }

          print $output_filter ? $output_filter->( $text) : $text;
        }
    }
  
  
  # same as output but does not output the start tag if the element
  # is marked as flushed
  sub flush
    { my $elt= shift;
  
      my $pretty;
      my $fh=  shift if( defined( $_[0]) && UNIVERSAL::isa($_[0], 'GLOB') );
      my $old_select= select $fh if( defined $fh);
      my $old_pretty= set_pretty_print( shift) if( defined $_[0]);

      $elt->_flush();

      select $old_select if( defined $old_select);
      set_pretty_print( $old_pretty) if( defined $old_pretty);
    }

sub _flush
  { my $elt= shift;
  
      # in case there's some comments or PI's piggybacking
      if( $elt->{extra_data})
        { print $output_filter ? $output_filter->($elt->{extra_data}) 
                               : $elt->{extra_data};
        }

      if( $elt->{gi} >= $XML::Twig::SPECIAL_GI)
        {
          unless( $elt->{flushed})
            { print $output_filter ? $output_filter->($elt->start_tag()) 
                                   : $elt->start_tag();
            }
      
          # flush the children
          my @children= $elt->children;
          foreach my $child (@children)
            { $child->_flush( $pretty); }
          print $output_filter ? $output_filter->($elt->end_tag()) 
                               : $elt->end_tag;
        }
      else # text or special element
        { my $text;
          if( (exists $elt->{'pcdata'}))     { $text= $elt->pcdata_xml_string;  }
          elsif( (exists $elt->{'cdata'}))   { $text= $elt->cdata_string;       }
          elsif( (exists $elt->{'target'}))      { $text= $elt->pi_string;          }
          elsif( (exists $elt->{'comment'})) { $text= $elt->comment_string;     }
          elsif( (exists $elt->{'ent'}))     { $text= $elt->ent_string;         }

          print $output_filter ? $output_filter->( $text) : $text;
        }
    }
  
  # just a shortcut to $elt->sprint( 1)
  sub xml_string
    { $_[0]->sprint( 1); }

  # same as print but except... it does not print but rather returns the string
  # if the second parameter is set then only the content is returned, not the
  # start and end tags of the element (but the tags of the included elements are
  # returned)
  sub sprint
    { my $elt= shift;
      my $no_tag= shift || 0;
  
      # in case there's some comments or PI's piggybacking
      my $string='';
      if( $elt->{extra_data})
        { $string= $output_filter ? $output_filter->($elt->{extra_data}) 
                                  : $elt->{extra_data};
        }

      if( $elt->{gi} >= $XML::Twig::SPECIAL_GI)
        {
          unless( $no_tag)
            { $string.=$output_filter ? $output_filter->($elt->start_tag) 
                                      :  $elt->start_tag;
            }
      
          # sprint the children
          my $child= $elt->{first_child}||'';
          while( $child)
            { $string.= $child->sprint;
              $child= $child->{next_sibling};
            }
          unless( $no_tag)
            { $string.=$output_filter ? $output_filter->($elt->end_tag) 
                                      :  $elt->end_tag;
            }
        }
      elsif( (exists $elt->{'pcdata'}))  { $string .= $elt->pcdata_xml_string; }
      elsif( (exists $elt->{'cdata'}))   { $string .= $elt->cdata_string;      }
      elsif( (exists $elt->{'target'}))      { $string .= $elt->pi_string;         }
      elsif( (exists $elt->{'comment'})) { $string .= $elt->comment_string;    }
      elsif( (exists $elt->{'ent'}))     { $string .= $elt->ent_string;        }

      if( $output_filter) { $string= $output_filter->( $string); }
      return $string;
    }

sub pcdata_xml_string 
  { my $string='';
    if( defined( $string= $_[0]->{pcdata}) )
      { $string=~ s/([&<])/$XML::Twig::base_ent{$1}/g
          unless( $keep_encoding || $_[0]->{asis}); 
      }
    return $string;
  }

sub att_xml_string 
  { my $elt= shift;
    my $att= shift;
    my $quote= shift || '"';
    my $string='';
    if( defined ($string= $elt->{att}->{$att}))
      { $string=~ s/([$quote<&])/$XML::Twig::base_ent{$1}/g
          unless( $keep_encoding); 
      }
    return $string;
  }

sub ent_string 
  { my $ent= shift;
    my $ent_text= $ent->{ent};
    my( $t, $el, $ent_string);
    if(    $expand_external_entities
        && ($t= $ent->twig) 
        && ($el= $t->entity_list)
        && ($ent_string= $el->{$ent->ent_name}->{val})
      )
     { return $ent_string; }

     return $ent_text; 
  }

# returns just the text, no tags, for an element
sub text
  { my $elt= shift;
    my $string;

    if( (exists $elt->{'pcdata'}))     { return  $elt->{pcdata};   }
    elsif( (exists $elt->{'cdata'}))   { return  $elt->{cdata};    }
    elsif( (exists $elt->{'target'}))      { return  $elt->pi;       }
    elsif( (exists $elt->{'comment'})) { return  $elt->{comment};  }
    elsif( (exists $elt->{'ent'}))     { return  $elt->{ent} ;     }

    my $child= $elt->{first_child} ||'';
    while( $child)
      { $string.= defined($child->text) ? $child->text : '';
        $child= $child->{next_sibling};
      }
    unless( defined $string) { $string=''; }

    return $string;
  }

# un-escape XML base entities if $keep_encoding is set
sub unescape
  { return $_[0] unless $keep_encoding;
    my $string= shift;
    $string=~ s{&lt;}   {<}g;
    $string=~ s{&gt;}   {>}g;
    $string=~ s{&apos;} {'}g;
    $string=~ s{&quot;} {"}g;
    $string=~ s{&amp;}  {&}g;
    return $string;
   }

} # end of block containing package globals ($pretty_print, $quotes, keep_encoding...)


#start-extract twig_node
  sub contains_text
  { my $elt= shift;
    my $child= $elt->{first_child};
    while ($child)
      { return 1 if( $child->is_text); 
        $child= $child->{next_sibling};
      }
    return 0;
  }

#end-extract twig_node

# creates a single pcdata element containing the text as child of the element
sub set_text
  { my $elt= shift;
    my $string= shift;

    if( $XML::Twig::index2gi[$elt->{'gi'}] eq PCDATA) 
      { return $elt->{pcdata}=  $string; }
    elsif( $XML::Twig::index2gi[$elt->{'gi'}] eq CDATA)  
      { $elt->set_gi( PCDATA);
        $elt->{cdata}= '';
        return $elt->{pcdata}=  $string;
      }

    foreach my $child (@{[$elt->children]})
      { $child->cut; }

    my $pcdata= XML::Twig::Elt->new( PCDATA, $string);
    $pcdata->paste( $elt);

    delete $elt->{empty} if( $elt->is_empty);

    return;
  }

# set the content of an element from a list of strings and elements
sub set_content
  { my $elt= shift;

    return unless defined $_[0];

    # attributes can be given as a hash (passed by ref)
    if( ref $_[0] eq 'HASH')
      { my $atts= shift;
        $elt->del_atts; # usually useless but better safe than sorry
        $elt->{'att'}=  $atts;
        return unless defined $_[0];
      }

    # check next argument for #EMPTY
    if( !(ref $_[0]) && ($_[0] eq EMPTY) ) 
      { $elt->{empty}= 1 unless( $elt->is_empty); return; }

    # case where we really want to do a set_text, the element is '#PCDATA'
    # and we only want to add text in it
    if( ($XML::Twig::index2gi[$elt->{'gi'}] eq PCDATA) && ($#_ == 0) && !( ref $_[0]))
      { $elt->{pcdata}=  $_[0];
        return;
      }
    elsif( ($XML::Twig::index2gi[$elt->{'gi'}] eq CDATA) && ($#_ == 0) && !( ref $_[0]))
      { $elt->{cdata}=  $_[0];
        return;
      }

    # delete the children
    # WARNING: potential problem here if the children are used
    # somewhere else (where?). Will be solved when I use weak refs
    foreach my $child (@{[$elt->children]})
      { $child->delete; }

    foreach my $child (@_)
      { if( UNIVERSAL::isa( $child, 'XML::Twig::Elt'))
          { $child->paste( 'last_child', $elt); }
        else
          { my $pcdata= XML::Twig::Elt->new( PCDATA, $child);
            $pcdata->paste( 'last_child', $elt);  
          }
      }

    delete $elt->{empty} if( $elt->is_empty);

    return;
  }

# inserts an element (whose gi is given) as child of the element
# all children of the element are now children of the new element
# returns the new element
sub insert
  { my ($elt, @args)= @_;
    # first cut the childrena
    my @children= $elt->children;
    foreach my $child (@children)
      { $child->cut; }
    # insert elements
    while( my $gi= shift @args)
      { my $new_elt= XML::Twig::Elt->new( $gi);
        # add attributes if needed
        if( UNIVERSAL::isa( $args[0], 'HASH'))
	  { $new_elt->{'att'}=  shift @args; }
	# paste the element
        $new_elt->paste( $elt);
        delete $elt->{empty} if( $elt->is_empty);
        $elt= $new_elt;
      }
    # paste back the children
    foreach my $child (@children)
      { $child->paste( 'last_child', $elt); }
    return $elt;
  }

# insert a new element 
# $elt->insert_new_element( $opt_position, $gi, $opt_atts_hash, @opt_content); 
# the element is created with the same syntax as new
# position is the same as in paste, first_child by default
sub insert_new_elt
  { my $elt= shift;
    my $position= $_[0];
    if(     ($position eq 'before') || ($position eq 'after')
         || ($position eq 'first_child') || ($position eq 'last_child'))
      { shift; }
    else
      { $position= 'first_child'; }

    my $new_elt= XML::Twig::Elt->new( @_);
    $new_elt->paste( $position, $elt);
    return $new_elt;
  }

# wraps an element in elements which gi's are given as arguments
# $elt->wrap_in( 'td', 'tr', 'table') wraps the element as a single
# cell in a table for example
# returns the new element
sub wrap_in
  { my $elt= shift;
    while( my $gi = shift @_)
      { my $new_elt = XML::Twig::Elt->new( $gi);
        if( $elt->{twig_current})
          { my $t= $elt->twig;
            $t->{twig_current}= $new_elt;
            delete $elt->{'twig_current'};
            $new_elt->{'twig_current'}=1;
          }

        if( my $parent= $elt->{parent})
          { $new_elt->set_parent( $parent); 
            $parent->{first_child}=  $new_elt if( $parent->{first_child} == $elt);
            $parent->set_last_child( $new_elt)  if( $parent->{last_child} == $elt);
          }
        else
          { # wrapping the root
            my $twig= $elt->twig;
            if( twig->root && (twig->root eq $elt) )
              { $twig->{twig_root}= $new_elt; }
          }

        if( my $prev_sibling= $elt->{prev_sibling})
          { $new_elt->set_prev_sibling( $prev_sibling);
            $prev_sibling->{next_sibling}=  $new_elt;
          }

        if( my $next_sibling= $elt->{next_sibling})
          { $new_elt->{next_sibling}=  $next_sibling;
            $next_sibling->set_prev_sibling( $new_elt);
          }
        $new_elt->{first_child}=  $elt;
        $new_elt->set_last_child( $elt);

        $elt->set_parent( $new_elt);
        $elt->set_prev_sibling( undef);
        $elt->{next_sibling}=  undef;

        # add the attributes if the next argument is a hash ref
	if( UNIVERSAL::isa( $_[0], 'HASH'))
	  { $new_elt->{'att'}=  shift @_; }

        $elt= $new_elt;
      }
      
    return $elt;
  }

sub replace
  { my( $elt, $ref)= @_;
    if( my $parent= $ref->{parent})
      { $elt->set_parent( $parent);
        $parent->{first_child}=  $elt if( $parent->{first_child} == $ref);
        $parent->set_last_child( $elt)  if( $parent->{last_child} == $ref);
      }
    if( my $prev_sibling= $ref->{prev_sibling})
      { $elt->set_prev_sibling( $prev_sibling);
        $prev_sibling->{next_sibling}=  $elt;
      }
    if( my $next_sibling= $ref->{next_sibling})
      { $elt->{next_sibling}=  $next_sibling;
        $next_sibling->set_prev_sibling( $elt);
      }
   
    $ref->set_parent( undef);
    $ref->set_prev_sibling( undef);
    $ref->{next_sibling}=  undef;
    return $ref;
  }


#start-extract twig_node
# move an element, same syntax as paste, except the element is first cut
sub move
  { my $elt= shift;
    $elt->cut;
    $elt->paste( @_);
  }
#end-extract twig_node


# adds a prefix to an element, creating a pcdata child if needed
sub prefix
  { my ($elt, $prefix, $option)= @_;
    my $asis= ($option && ($option eq 'asis')) ? 1 : 0;
    if( (exists $elt->{'pcdata'}) 
        && (($asis && $elt->{asis}) || (!$asis && ! $elt->{asis}))
      )
      { $elt->{pcdata}=  $prefix . $elt->{pcdata}; }
    elsif( $elt->{first_child} && $elt->{first_child}->is_pcdata
        && (   ($asis && $elt->{first_child}->{asis}) 
            || (!$asis && ! $elt->{first_child}->{asis}))
         )
      { $elt->{first_child}->set_pcdata( $prefix . $elt->{first_child}->pcdata); }
    else
      { my $new_elt= XML::Twig::Elt->new( PCDATA, $prefix);
        $new_elt->paste( $elt);
        $new_elt->set_asis if( $asis);
      }
  }

# adds a suffix to an element, creating a pcdata child if needed
sub suffix
  { my ($elt, $suffix, $option)= @_;
    my $asis= ($option && ($option eq 'asis')) ? 1 : 0;
    if( (exists $elt->{'pcdata'})
        && (($asis && $elt->{asis}) || (!$asis && ! $elt->{asis}))
      )
      { $elt->{pcdata}=  $elt->{pcdata} . $suffix; }
    elsif( $elt->{last_child} && $elt->{last_child}->is_pcdata
        && (   ($asis && $elt->{last_child}->{asis}) 
            || (!$asis && ! $elt->{last_child}->{asis}))
         )
      { $elt->{last_child}->set_pcdata( $elt->{first_child}->pcdata . $suffix); }
    else
      { my $new_elt= XML::Twig::Elt->new( PCDATA, $suffix);
        $new_elt->paste( 'last_child', $elt);
        $new_elt->set_asis if( $asis);
      }
  }

#start-extract twig_node
# create a path to an element ('/root/.../gi)
sub path
  { my $elt= shift;
    my @context= ( $elt, $elt->ancestors);
    return "/" . join( "/", reverse map {$_->gi} @context);
  }

sub before
  { my( $a, $b)=@_;
    if( $a->cmp( $b) == -1) { return 1; } else { return 0; }
  }

sub after
  { my( $a, $b)=@_;
    if( $a->cmp( $b) == 1) { return 1; } else { return 0; }
  }

sub lt
  { my( $a, $b)=@_;
    return 1 if( $a->cmp( $b) == -1);
    return 0;
  }

sub le
  { my( $a, $b)=@_;
    return 1 if( $a->cmp( $b) == 1);
    return 0;
  }

sub gt
  { my( $a, $b)=@_;
    return 1 unless( $a->cmp( $b) == 1);
    return 0;
  }

sub ge
  { my( $a, $b)=@_;
    return 1 unless( $a->cmp( $b) == -1);
    return 0;
  }


sub cmp
  { my( $a, $b)=@_;

    # easy cases
    return  0 if( $a == $b);    
    return  1 if( $a->in($b)); # a starts after b 
    return -1 if( $b->in($a)); # a starts before b

    # ancestors does not include the element itself
    my @a_pile= ($a, $a->ancestors); 
    my @b_pile= ($b, $b->ancestors);

    # the 2 elements are not in the same twig
    return undef unless( $a_pile[-1] == $b_pile[-1]);

    # find the first non common ancestors (they are siblings)
    my $a_anc= pop @a_pile;
    my $b_anc= pop @b_pile;

    while( $a_anc == $b_anc) 
      { $a_anc= pop @a_pile;
        $b_anc= pop @b_pile;
      }

    # from there move left and right and figure out the order
    my( $a_prev, $a_next, $b_prev, $b_next)= ($a_anc, $a_anc, $b_anc, $b_anc);
    while()
      { $a_prev= $a_prev->{prev_sibling} || return( -1);
        return 1 if( $a_prev == $b_next);
        $a_next= $a_next->{next_sibling} || return( 1);
        return -1 if( $a_next == $b_prev);
        $b_prev= $b_prev->{prev_sibling} || return( 1);
        return -1 if( $b_prev == $a_next);
        $b_next= $b_next->{next_sibling} || return( -1);
        return 1 if( $b_next == $a_prev);
      }
  }
    
#end-extract twig_node

__END__

=head1 NAME

XML::Twig - A perl module for processing huge XML documents in tree mode.

=head1 SYNOPSYS

Small documents

  my $twig=XML::Twig->new(); # create the twig
  $twig->parse( 'doc.xml'); # build it
  my_process( $twig);       # use twig methods to process it 
  $twig->print;             # output the twig

Huge documents

  my $twig=XML::Twig->new(   
    twig_handlers => 
      { title   => sub { $_->set_gi( 'h2' }, # change title tags to h2
        para    => sub { $_->set_gi( 'p') }, # change para to p
	hidden  => sub { $_->delete;      }, # remove hidden elements
	list    => \&my_list_process,        # process list elements
	div     => sub { $_[0]->flush;    }, # output and free memory
      },
    PrettyPrint => 'indented',               # output will be nicely formatted
    EmptyTags   => 'html',                   # outputs <empty_tag />
	                );
    $t->flush;                               # flush the end of the document

See L<XML::Twig 101|XML::Twig 101> for other ways to use the module, as a 
filter for example

=head1 DESCRIPTION

This module provides a way to process XML documents. It is build on top
of XML::Parser.

The module offers a tree interface to the document, while allowing you
to output the parts of it that have been completely processed.

It allows minimal resource (CPU and memory) usage by building the tree
only for the parts of the documents that need actual processing, through the 
use of the C<L<twig_roots|twig_roots>> and 
C<L<twig_print_outside_roots|twig_print_outside_roots>> options. The 
C<L<finish|finish>> and C<L<finish_print|finish_print>> methods also help 
to increase performances.

XML::Twig tries to make simple things easy so it tries its best to takes care 
of a lot of the (usually) annoying (but sometimes necessary) features that 
come with XML and XML::Parser.

=head1 XML::Twig 101

XML::Twig can be used either on "small" XML documents (that fit in memory)
or on huge ones, by processing parts of the document and outputting or
discarding them once they are processed.


=head2 Loading an XML document and processing it

        my $t= XML::Twig->new();
        $t->parse( '<d><tit>title</tit><para>para1</para><para>p2</para></d>');
        my $root= $t->root;
	$root->set_gi( 'html');               # change doc to html
	$title= $root->first_child( 'tit');   # get the title
	$title->set_gi( 'h1');                # turn it into h1
	my @para= $root->children( 'para');   # get the para children
	foreach my $para (@para)
	  { $para->set_gi( 'p'); }            # turn them into p
	$t->print;                            # output the document

Other useful methods include:

L<att|att>: C<< $elt->{'att'}->{'type'} >> returns the C<type> attribute for an 
element,

L<set_att|set_att>: C<< $elt->set_att( type => "important") >> sets the C<type> 
attribute to the C<important> value,

L<next_sibling|next_sibling>: C<< $elt->{next_sibling} >> returns the next sibling
in the document (in the example C<< $title->{next_sibling} >> is the first C<para>
while C<< $elt->next_sibling( 'table') >> is the next C<table> sibling 

The document can also be transformed through the use of the L<cut|cut>, 
L<copy|copy>, L<paste|paste> and L<move|move> methods: 
C<< $title->cut; $title->paste( 'after', $p); >> for example

And much, much more, see L<Elt|"Elt">.

=head2 Processing an XML document chunk by chunk

One of the strength of XML::Twig is that it let you work with files that do 
not fit in memory (BTW storing an XML document in memory as a tree is quite
memory-expensive, the expansion factor being often around 10).

To do this you can define handlers, that will be called once a specific 
element has been completely parsed. In this handlers you can access the
element and process it as you see fit, using the navigation and the
cut-n-paste methods, plus lots of convenient ones like C<L<prefix|prefix>>.
Once the element is completely processed you can then C<L<flush|flush>> it, 
which will output it and free the memory. You can also C<L<purge|purge>> it 
if you don't need to output it (if you are just extracting some data from 
the document for example). The handler will be called again once the next 
relevant element has been parsed.

        my $t= XML::Twig->new( twig_handlers => 
                                { section => \&section,
	                          para   => sub { $_->set_gi( 'p');
			        },
		            );
        $t->parsefile( 'doc.xml');
        $t->flush; # don't forget to flush one last time in the end or anything
	           # after the last </section> tag will not be output 
	
	# the handler is called once a section is completely parsed, ie when 
	# the end tag for section is found, it receives the twig itself and
	# the element (including all its sub-elements) as arguments
        sub section 
	  { my( $t, $section)= @_;      # arguments for all twig_handlers
	    $section->set_gi( 'div');   # change the gi, my favourite method...
	    # let's use the attribute nb as a prefix to the title
	    my $title= $section->first_child( 'title'); # find the title
	    my $nb= $title->{'att'}->{'nb'}; # get the attribute
	    $title->prefix( "$nb - ");  # easy isn't it?
	    $section->flush;            # outputs the section and frees memory
	  }

        my $t= XML::Twig->new( twig_handlers => 
	                        { 'section/title' => \&print_elt_text} );
        $t->parsefile( 'doc.xml');
        sub print_elt_text 
          { my( $t, $elt)= @_;
            print $elt->text; 
          }

        my $t= XML::Twig->new( twig_handlers => 
	                        { 'section[@level="1"]' => \&print_elt_text }
			    );
        $t->parsefile( 'doc.xml');

There is of course more to it: you can trigger handlers on more elaborate 
conditions than just the name of the element, C<section/title> for example.
You can also use C<L<TwigStartHandlers|TwigStartHandlers>> to process an 
element as soon as the start tag is found. Besides C<L<prefix|prefix>> you
can also use C<L<suffix|suffix>>, 

=head2 Processing just parts of an XML document

The twig_roots mode builds only the required sub-trees from the document
Anything outside of the twig roots will just be ignored:

        my $t= XML::Twig->new( 
	         # the twig will include just the root and selected titles 
                 twig_roots   => { 'section/title' => \&print_elt_text,
                                   'annex/title'   => \&print_elt_text
				 }
                            );
        $t->parsefile( 'doc.xml');
	
        sub print_elt_text 
          { my( $t, $elt)= @_;
            print $elt->text;    # print the text (including sub-element texts)
	    $t->purge;           # frees the memory
          }

You can use that mode when you want to process parts of a documents but are
not interested in the rest and you don't want to pay the price, either in
time or memory, to build the tree for the it.


=head2 Building an XML filter

You can combine the twig_roots and the twig_print_outside_roots options to build
filters, which let you modify selected elements and will output the rest of 
the document as is.

This would convert prices in $ to prices in Euro in a document:

        my $t= XML::Twig->new( 
                 twig_roots   => { 'price' => \&convert, },    # process prices 
		 twig_print_outside_roots => 1,                # print the rest
                            );
        $t->parsefile( 'doc.xml');
	
        sub convert 
          { my( $t, $price)= @_;
	    my $currency=  $price->{'att'}->{'currency'};        # get the currency
	    if( $currency eq 'USD')
	      { $usd_price= $price->text;                   # get the price
	        # %rate is just a conversion table 
	        my $euro_price= $usd_price * $rate{usd2euro};
		$price->set_text( $euro_price);             # set the new price
		$price->set_att( currency => 'EUR');        # don't forget this!
	      }
            $price->print;                                  # output the price
	  }


=head2 Simplifying XML processing

=over 4

=item Whitespaces

Whitespaces that look non-significant are discarded, this behaviour can be 
controlled using the C<L<keep_spaces|keep_spaces>>, 
C<L<keep_spaces_in|keep_spaces_in>> and 
C<L<discard_spaces_in options|discard_spaces_in options>>.

=item Encoding

You can specify that you want the output in the same encoding as the input
(provided you have valid XML, which means you have to specify the encoding
either in the document or when you create the Twig object) using the 
C<L<keep_encoding|keep_encoding>> option

=item Comments and Processing Instructions (PI)

Comments and PI's can be hidden from the processing, but still appear in the
output (they are carried by the "real" element closer to them)

=item Pretty Printing

XML::Twig can output the document pretty printed so it is easier to read for
us humans.

=item Surviving an untimely death

XML parsers are supposed to react violently when fed improper XML. 
XML::Parser just dies.

XML::Twig provides the C<L<safe_parse|safe_parse>> and the 
C<L<safe_parsefile|safe_parsefile>> methods which wrap the parse in an eval
and return either the parsed twig or 0 in case of failure.

=item Private attributes

Attributes with a name starting with # (illegal in XML) will not be
output, so you can safely use them to store temporary values during
processing.

=back

=head1 METHODS

=head2 Twig 

A twig is a subclass of XML::Parser, so all XML::Parser methods can be
called on a twig object, including parse and parsefile.
setHandlers on the other hand cannot be used, see C<L<BUGS|BUGS>>


=over 4

=item new 

This is a class method, the constructor for XML::Twig. Options are passed
as keyword value pairs. Recognized options are the same as XML::Parser,
plus some XML::Twig specifics:

=over 4

=item twig_handlers

This argument replaces the corresponding XML::Parser argument. It consists
of a hash { expression => \&handler} where expression is a 
I<generic_attribute_condition>, I<string_condition>,
an I<attribute_condition>,I<full_path>, a I<partial_path>, a I<gi>,
I<_default_> or <_all_>.

The idea is to support a usefull but efficient (thus limited) subset of
XPATH. A fuller expression set will be supported in the future, as users
ask for more and as I manage to implement it efficiently. This will never
encompass all of XPATH due to the streaming nature of parsing (no lookahead
after the element end tag).

A B<generic_attribute_condition> is a condition on an attribute, in the form
I<*[@att="val"]> or I<*[@att]>, simple quotes can be used instead of double 
quotes and the leading '*' is actually optional. No matter what the gi of the
element is, the handler will be triggered either if the attribute has the 
specified value or if it just exists. 

A B<string_condition> is a condition on the content of an element, in the form
I<gi[string()="foo"]>, simple quotes can be used instead of double quotes, at 
the moment you cannot escape the quotes (this will be added as soon as I
dig out my copy of Mastering Regular Expressions from its storage box).
The text returned is, as per what I (and Matt Sergeant!) understood from
the XPATH spec the concatenation of all the text in the element, excluding
all markup. Thus to call a handler on the element <p>text <b>bold</b></p>
the appropriate condition is p[string()="text bold"]. Note that this is not
exactly conformant to the XPATH spec, it just tries to mimic it while being
still quite concise. 

A extension of that notation is I<gi[string(B<child_gi>)="foo"]> where the
handler will be called if a child of a C<gi> element has a text value of 
C<foo>.  At the moment only direct children of the C<gi> element are checked.
If you need to test on descendants of the element let me know. The fix is
trivial but would slow down the checks, so I'd like to keep it the way it is.

A B<regexp_condition> is a condition on the content of an element, in the form
I<gi[string()=~ /foo/"]>. This is the same as a string condition except that
the text of the element is matched to the regexp. The C<i>, C<m>, <s> and C<o>
modifiers can be used on the regexp.

The I<gi[string(B<child_gi>)=~ /foo/"]> extension is also supported.

An B<attribute_condition> is a simple condition of an attribute of the
current element in the form I<gi[@att="val"]> (simple quotes can be used
instead of double quotes, you can escape quotes either). 
If several attribute_condition are true the same element all the handlers
can be called in turn (in the order in which they were first defined).
If the ="val" part is ommited ( the condition is then gi[@att]) then
the handler is triggered if the attribute actually exists for the element,
no matter what it's value is.

A B<full_path> looks like I<'/doc/section/chapter/title'>, it starts with
a / then gives all the gi's to the element. The handler will be called if
the path to the current element (in the input document) is exactly as
defined by the full_path.

A B<partial_path> is like a full_path except it does not start with a /:
I<'chapter/title'> for example. The handler will be called if the path to
the element (in the input document) ends as defined in the partial_path.

B<WARNING>: (hopefully temporary) at the moment I<string_condition>, 
I<regexp_condition> and I<attribute_condition> are only supported on a 
simple gi, not on a path.

A B<gi> (generic identifier) is just a tag name.

A special gi B<_all_> is used to call a function for each element.
The special gi B<_default_> is used to call a handler for each element
that does NOT have a specific handler.

The order of precedence to trigger a handler is: I<generic_attribute_condition>,
I<string_condition>, I<regexp_condition>, I<attribute_condition>, I<full_path>,
longer I<partial_path>, shorter I<partial_path>, I<gi>, I<_default_> . 

B<Important>: once a handler has been triggered if it returns 0 then no other
handler is called, exept a _all_ handler which will be called anyway.

If a handler returns a true value and other handlers apply, then the next
applicable handler will be called. Repeat, rince, lather..;

When an element is CLOSED the corresponding handler is called, with 2
arguments: the twig and the C<L</Element|/Element>>. The twig includes the 
document tree that has been built so far, the element is the complete sub-tree
for the element. $_ is also set to the element. 

Text is stored in elements where gi is #PCDATA (due to mixed content, text
and sub-element in an element there is no way to store the text as just an
attribute of the enclosing element).

B<Warning>: if you have used purge or flush on the twig the element might not
be complete, some of its children might have been entirely flushed or purged,
and the start tag might even have been printed (by flush) already, so changing
its gi might not give the expected result.

More generally, the I<full_path>, I<partial_path> and I<gi> expressions are
evaluated against the input document. Which means that even if you have changed
the gi of an element (changing the gi of a parent element from a handler for
example) the change will not impact the expression evaluation. Attributes in
I<attribute_condition> are different though. As the initial value of attribute
is not stored the handler will be triggered if the B<current> attribute/value
pair is found when the element end tag is found. Although this can be quite
confusing it should not impact most of users, and allow others to play clever
tricks with temporary attributes. Let me know if this is a problem for you.


=item twig_roots

This argument let's you build the tree only for those elements you are
interested in. 

  Example: my $t= XML::Twig->new( twig_roots => { title => 1, subtitle => 1});
           $t->parsefile( file);
           my $t= XML::Twig->new( twig_roots => { 'section/title' => 1});
           $t->parsefile( file);


returns a twig containing a document including only title and subtitle 
elements, as children of the root element.

You can use I<generic_attribute_condition>, I<attribute_condition>,
I<full_path>, I<partial_path>, I<gi>, I<_default_> and I<_all_> to 
trigger the building of the twig. 
I<string_condition> and I<regexp_condition> cannot be used as the content 
of the element, and the string, have not yet been parsed when the condition
is checked.

B<WARNING>: path are checked for the document. Even if the twig_roots option
is used they will be checked against the full document tree, not the virtual
tree created by XML::Twig


B<WARNING>: twig_roots elements should NOT be nested, that would hopelessly
confuse XML::Twig ;--(

Note: you can set handlers (twig_handlers) using twig_roots
  Example: my $t= XML::Twig->new( twig_roots => 
                                   { title    => sub { $_{1]->print;}, 
                                     subtitle => \&process_subtitle 
                                   }
                               );
           $t->parsefile( file);
 

=item twig_print_outside_roots

To be used in conjunction with the twig_roots argument. When set to a true 
value this will print the document outside of the twig_roots elements.

 Example: my $t= XML::Twig->new( twig_roots => { title => \&number_title },
                                twig_print_outside_roots => 1,
                               );
           $t->parsefile( file);
           { my $nb;
           sub number_title
             { my( $twig, $title);
               $nb++;
               $title->prefix( "$nb "; }
               $title->print;
             }
           }
               

This example prints the document outside of the title element, calls 
number_title for each title element, prints it, and then resumes printing
the document. The twig is built only for the title elements. 


=item start_tag_handlers

A hash { expression => \&handler}. Sets element handlers that are called when
the element is open (at the end of the XML::Parser Start handler). The handlers
are called with 2 params: the twig and the element. The element is empty at 
that point, its attributes are created though. 

You can use I<generic_attribute_condition>, I<attribute_condition>,
I<full_path>, I<partial_path>, I<gi>, I<_default_>  and I<_all_> to trigger 
the handler. 

I<string_condition> and I<regexp_condition> cannot be used as the content of 
the element, and the string, have not yet been parsed when the condition is 
checked.

The main uses for those handlers are to change the tag name (you might have to 
do it as soon as you find the open tag if you plan to C<flush> the twig at some
point in the element, and to create temporary attributes that will be used
when processing sub-element with TwigHanlders. 

You should also use it to change tags if you use flush. If you change the tag 
in a regular TwigHandler then the start tag might already have been flushed. 

B<Note>: StartTag handlers can be called outside ot I<twig_roots> if this 
argument is used, in this case handlers are called with the following arguments:
$t (the twig), $gi (the gi of the element) and %att (a hash of the attributes
of the element). 

If the I<twig_print_outside_roots> argument is also used then the start tag
will be printed if the last handler called returns a C<true> value, if it
does not then the start tag will B<not> be printed (so you can print a
modified string yourself for example);

Note that you can use the L<ignore|ignore> method in start_tag_handlers 
(and only there). 

=item end_tag_handlers

A hash { expression => \&handler}. Sets element handlers that are called when
the element is closed (at the end of the XML::Parser End handler). The handlers
are called with 2 params: the twig and the gi of the element. 

I<twig_handlers> are called when an element is completely parsed, so why have 
this redundant option? There is only one use for end_tag_handlers: when using
the twig_roots option, to trigger a handler for an element B<outside> the roots.
It is for example very useful to number titles in a document using nested 
sections: 

  my @no= (0);
  my $no;
  my $t= XML::Twig->new( 
          start_tag_handlers => 
           { section => sub { $no[$#no]++; $no= join '.', @no; push @no, 0; } },
          twig_roots         => 
           { title   => sub { $_[1]->prefix( $no); $_[1]->print; } },
          end_tag_handlers   => { section => sub { pop @no;  } },
          twig_print_outside_roots => 1
                      );
   $t->parsefile( $file);

Using the end_tag_handlers argument without twig_roots will result in an error.

=item CharHandler

A reference to a subroutine that will be called every time PCDATA is found.

=item keep_encoding

This is a (slightly?) evil option: if the XML document is not UTF-8 encoded and
you want to keep it that way, then setting keep_encoding will use the Expat
original_string method for character, thus keeping the original encoding, as 
well as the original entities in the strings.

See the t/test6.t test file to see what results you can expect from the various
encoding options.

B<WARNING>: if the original encoding is multi-byte then attribute parsing will
be EXTREMELY unsafe under any Perl before 5.6, as it uses regular expressions
which do not deal properly with multi-byte characters. You can specify an 
alternate function to parse the start tags with the parse_start_tag option 
(see below)

B<WARNING>: this option is NOT used when parsing with the non-blocking parser 
(parse_start, parse_more, parse_done methods) which you probably should not use
with XML::Twig anyway as they are totally untested!

=item output_filter

This option is used to convert the character encoding of the output document.
It is passed either a string corresponding to a predefined filter or
a subroutine reference. The filter will be called every time a document or 
element is processed by the "print" functions (C<print>, C<sprint>, C<flush>). 

Pre-defined filters are: 

=over 4 

=item latin1 

uses either Text::Iconv or Unicode::Map8 and Unicode::String or a regexp
(which works only with XML::Parser 2.27), in this order, to convert all 
characters to ISO-8859-1 (aka latin1)

=item html

does the same conversion as latin1, plus encodes entities using HTML::Entities
(you need to have HTML::Entities intalled for it to be available). This should
only be used if the tags and attribute names themselves are in US-ASCII, or they
will be converted and the output will not be valid XML any more

=item safe

converts the output to ASCII (US) only  plus character entities (&#nnn;) this
should be used only if the tags and attribute names themselves are in US-ASCII,
or they will be converted and the output will not be valid XML any more

=item iconv_convert ($encoding)

this function is used to create a filter subroutine that will be used to 
convert the characters to the target encoding using Text::Iconv (which need
to be installed, look at the documentation for the module and for the
C<iconv> library to find out which encodings are available on your system)

   my $conv = XML::Twig::iconv_convert( 'latin1');
   my $t = XML::Twig->new(output_filter => $conv);

=item :unicode_convert ($encoding)

this function is used to create a filter subroutine that will be used to 
convert the characters to the target encoding using  Unicode::Strings 
and Unicode::Map8 (which need to be installed, look at the documentation 
for the modules to find out which encodings are available on your system)

   my $conv = XML::Twig::unicode_convert( 'latin1');
   my $t = XML::Twig->new(output_filter => $conv);

=back

Note that the C<text> and C<att> methods do not use the filter, so their 
result are always in unicode.

=item input_filter

This option is similar to output_filter except the filter is applied to 
the characters before they are stored in the twig, at parsing time.


=item parse_start_tag

If you use the keep_encoding option then this option can be used to replace the
default parsing function. You should provide a coderef (a reference to a 
subroutine) as the argument, this subroutine takes the original tag (given
by XML::Parser::Expat original_string() method) and returns a gi and the
attributes in a hash (or in a list attribute_name/attribute value).

=item expand_external_ents

When this option is used external entities (that are defined) are expanded
when the document is output using "print" functions such as C<Lprint>>,
C<L<sprint|sprint>>, C<L<flush|flush>> and C<L<xml_string|xml_string>>. 
Note that in the twig the entity will be stored as an element whith a 
gi '#ENT', the entity will not be expanded there, so you might want to 
process the entities before outputting it. 

=item load_DTD

If this argument is set to a true value, parse or parsefile on the twig will 
load  the DTD information. This information can then be accessed through the 
twig, in a DTD_handler for example. This will load even an external DTD.

Note that to do this the module will generate a temporary file in the current
directory. If this is a problem let me know and I will add an option to
specify an alternate directory.

See L<DTD Handling|DTD Handling> for more information

=item DTD_handler

Sets a handler that will be called once the doctype (and the DTD) have been 
loaded, with 2 arguments, the twig and the DTD.

=item id

This optional argument gives the name of an attribute that can be used as
an ID in the document. Elements whose ID is known can be accessed through
the elt_id method. id defaults to 'id'.
See C<L<BUGS|BUGS>>

=item discard_spaces

If this optional argument is set to a true value then spaces are discarded
when they look non-significant: strings containing only spaces are discarded.
This argument is set to true by default.

=item keep_spaces

If this optional argument is set to a true value then all spaces in the
document are kept, and stored as PCDATA.
keep_spaces and discard_spaces cannot be both set.

=item discard_spaces_in

This argument sets keep_spaces to true but will cause the twig builder to
discard spaces in the elements listed.
The syntax for using this argument is: 
  XML::Twig->new( discard_spaces_in => [ 'elt1', 'elt2']);

=item keep_spaces_in

This argument sets discard_spaces to true but will cause the twig builder to
keep spaces in the elements listed.
The syntax for using this argument is: 
  XML::Twig->new( keep_spaces_in => [ 'elt1', 'elt2']);

=item PrettyPrint

Sets the pretty print method, amongst 'none' (default), 'nsgmls', 'nice', 
'indented', 'record' and 'record_c'

=over 4

=item none

The document is output as one ling string, with no linebreaks except those 
found within text elements

=item nsgmls

Line breaks are inserted in safe places: that is within tags, between a tag 
and an attribute, between attributes and before the > at the end of a tag.

This is quite ugly but better than C<none>, and it is very safe, the document 
will still be valid (conforming to its DTD).

This is how the SGML parser C<sgmls> splits documents, hence the name.

=item nice

This option inserts line breaks before any tag that does not contain text (so
element with textual content are not broken as the \n is the significant).

B<WARNING>: this option leaves the document well-formed but might make it
invalid (not conformant to its DTD). If you have elements declared as

  <!ELEMENT foo (#PCDATA|bar)>

then a C<foo> element including a C<bar> one will be printed as

  <foo>
  <bar>bar is just pcdata</bar>
  </foo>

This is invalid, as the parser will take the line break after the foo tag as a
sign that the element contains PCDATA, it will then die when it finds the 
C<bar> tag. This may or may not be important for you, but be aware of it!

=item indented

Same as C<nice> (and with the same warning) but indents elements according to 
their level 

=item record

This is a record_oriented pretty print, that display data in records, one field 
per line (which looks a LOT like C<indented>)

=item record_c

Stands for record compact, one record per line

=back


=item EmptyTags

Sets the empty tag display style (normal, html or expand).

=item comments

Sets the way comments are processed: drop (default), keep or process

=over 4

=item drop

drops the comments, they are not read, nor printed to the output

=item keep

comments are loaded and will appear on the output, they are not 
accessible within the twig and will not interfere with processing
though

B<Bug>: comments in the middle of a text element such as 

  <p>text <!-- comment --> more text --></p>

are output at the end of the text:

  <p>text  more text <!-- comment --></p>

=item process

comments are loaded in the twig and will be treated as regular elements 
(their C<gi> is C<#COMMENT>) this can interfere with processing if you
expect C<< $elt->{first_child} >> to be an element but find a comment there.
Validation will not protect you from this as comments can happen anywhere.
You can use C<< $elt->first_child( 'gi') >> (which is a good habit anyway)
to get where you want. Consider using 

=back

=item pi

Sets the way processing instructions are processed: C<drop>, C<keep> 
(default) or C<process>

Note that you can also set PI handlers in the twig_handlers option: 

  '?'       => \&handler
  '?target' => \&handler 2

The handlers will be called with 2 parameters, the twig and the PI element if
pi is set to C<process>, and with 3, the twig, the target and the data if pi
is set to C<keep>. Of course they will not be called if PI is set to C<drop>.

If pi is set to C<keep> the handler should return a string that will be used
as-is as the PI text (it should look like "C< <?target data?> >" or '' if you
want to remove the PI), 

Only one handler will be called, C<?target> or C<?> if no specific handler for
that target is available.


=back

B<Note>: I _HATE_ the Java-like name of arguments used by most XML modules. 
As XML::Twig is based on XML::Parser I kept the style, but you can also use
a more perlish naming convention, using C<twig_print_outside_roots> instead
of C<twig_print_outside_roots> or C<pretty_print> instead of C<PrettyPrint>,
XML::Twig then normalizes all the argument names. 

=item parse(SOURCE [, OPT => OPT_VALUE [...]])

This method is inherited from XML::Parser.
The SOURCE parameter should either be a string containing the whole XML
document, or it should be an open IO::Handle. Constructor options to
XML::Parser::Expat given as keyword-value pairs may follow the SOURCE
parameter. These override, for this call, any options or attributes passed
through from the XML::Parser instance.

A die call is thrown if a parse error occurs. Otherwise it will return 
the twig built by the parse. Use I<safe_parse> if you want the parsing
to return even when an error occurs.

=item parsestring

This is just an alias for parse for backwards compatibility.

=item parsefile(FILE [, OPT => OPT_VALUE [...]])

This method is inherited from XML::Parser.

Open FILE for reading, then call parse with the open handle. The file
is closed no matter how parse returns. 

A die call is thrown if a parse error occurs. Otherwise it will return 
the twig built by the parse. Use I<safe_parsefile> if you want the parsing
to return even when an error occurs.

=item parseurl $url $optionnal_user_agent

Gets the data from the url and parse it. Note that the data is piped to the
parser in chunks the size of the XML::Parser::Expat buffer, so memory 
consumption and hopefully speed are optimal.

If the $optionnal_user_agent argument is used then it is used, otherwise a
new one is created.

=item safe_parse( SOURCE [, OPT => OPT_VALUE [...]])

This method is similar to I<parse> except that it wraps the parsing in an
eval block. It returns the twig on success and 0 on failure (the twig object
also contains the parsed twig). $@ contains the error message on failure.

Note that the parsing still stops as soon as an error is detected, there is
no way to keep going after an error.

=item safe_parsefile(FILE [, OPT => OPT_VALUE [...]])

This method is similar to I<parsefile> except that it wraps the parsing in an
eval block. It returns the twig on success and 0 on failure (the twig object
also contains the parsed twig) . $@ contains the error message on failure

Note that the parsing still stops as soon as an error is detected, there is
no way to keep going after an error.

=item safe_parseurl $url $optional_user_agent

Same as I<parseurl> except that it wraps the parsing in an eval block. It 
returns the twig on success and 0 on failure (the twig object also contains
the parsed twig) . $@ contains the error message on failure

=item parser

This method returns the expat object (actually the XML::Parser::Expat object) 
used during parsing. It is useful for example to call XML::Parser::Expat methods
on it. To get the line of a tag for example use $t->parser->current_line.

=item setTwigHandlers ($handlers)

Set the Twig handlers. $handlers is a reference to a hash similar to the
one in the TwigHandlers option of new. All previous handlers are unset.
The method returns the reference to the previous handlers.

=item setTwigHandler ($gi $handler)

Set a single Twig handlers for the $gi element. $handler is a reference to 
a subroutine. If the handler was previously set then the reference to the
previous handler is returned.

=item setStartTagHandlers ($handlers)

Set the StartTag handlers. $handlers is a reference to a hash similar to the
one in the start_tag_handlers option of new. All previous handlers are unset.
The method returns the reference to the previous handlers.

=item setStartTagHandler ($gi $handler)

Set a single StartTag handlers for the $gi element. $handler is a reference to 
a subroutine. If the handler was previously set then the reference to the
previous handler is returned.

=item setEndTagHandlers ($handlers)

Set the EndTag handlers. $handlers is a reference to a hash similar to the
one in the end_tag_handlers option of new. All previous handlers are unset.
The method returns the reference to the previous handlers.

=item setEndTagHandler ($gi $handler)

Set a single EndTag handlers for the $gi element. $handler is a reference to 
a subroutine. If the handler was previously set then the reference to the
previous handler is returned.


=item setTwigHandlers ($handlers)

Set the Twig handlers. $handlers is a reference to a hash similar to the
one in the twig_handlers option of new.


=item dtd

Returns the dtd (an XML::Twig::DTD object) of a twig

=item root

Returns the root element of a twig

=item first_elt ($optionnal_gi)

Returns the first element whose gi is $optionnal_gi of a twig, if
no $optionnal_gi is given then the root is returned

=item elt_id        ($id)

Returns the element whose id attribute is $id

=item entity_list

Returns the entity list of a twig

=item change_gi      ($old_gi, $new_gi)

Performs a (very fast) global change. All elements old_gi are now new_gi.
See C<L<BUGS|BUGS>>

=item flush            ($optional_filehandle, $options)

Flushes a twig up to (and including) the current element, then deletes
all unnecessary elements from the tree that's kept in memory.
flush keeps track of which elements need to be open/closed, so if you
flush from handlers you don't have to worry about anything. Just keep 
flushing the twig every time you're done with a sub-tree and it will
come out well-formed. After the whole parsing don't forget to flush
one more time to print the end of the document.
The doctype and entity declarations are also printed.

flush take an optional filehandle as an argument.

options: use the Update_DTD option if you have updated the (internal) DTD 
and/or the entity list and you want the updated DTD to be output 

The PrettyPrint option sets the pretty printing of the document.

   Example: $t->flush( Update_DTD => 1);
            $t->flush( \*FILE, Update_DTD => 1);
            $t->flush( \*FILE);


=item flush_up_to ($elt, $optionnal_filehandle, %options)

Flushes up to the $elt element. This allows you to keep part of the
tree in memory when you flush.

options: see flush.

=item purge

Does the same as a flush except it does not print the twig. It just deletes
all elements that have been completely parsed so far.

=item purge_up_to ($elt)

Purges up to the $elt element. This allows you to keep part of the tree in 
memory when you flush.

=item print            ($optional_filehandle, %options)

Prints the whole document associated with the twig. To be used only AFTER the
parse.
 
options: see flush.

=item sprint

Returns the text of the whole document associated with the twig. To be used only
AFTER the parse.

options: see flush.

=item ignore

This method can B<only> be called in start_tag_handlers. It causes the element
to be skipped during the parsing: the twig is not built for this element, it 
will not be accessible during parsing or after it. The element will not take
up any memory and parsing will be faster.

Note that this method can also be called on an element. If the element is a 
parent of the current element then this element will be ignored (the twig will
not be built any more for it and what has already been built will be deleted)


=item set_pretty_print  ($style)

Sets the pretty print method, amongst 'none' (default), 'nsgmls', 'nice', 
'indented', 'record' and rec'record'ord_c

B<WARNING:> the pretty print style is a B<GLOBAL> variable, so once set it's
applied to B<ALL> print's (and sprint's). Same goes if you use XML::Twig
with mod_perl . This should not be a problem as the XML that's generated 
is valid anyway, and XML processors (as well as HTML processors, including
browsers) should not care. Let me know if this is a big problem, but at the
moment the performance/cleanliness trade-off clearly favors the global 
approach.

=item set_empty_tag_style  ($style)

Sets the empty tag display style (normal, html or expand). As with 
set_pretty_print this sets a global flag.  

normal outputs an empty tag '<tag/>', html adds a space '<tag /> and
expand outputs '<tag></tag>'

=item print_prolog     ($optional_filehandle, %options)

Prints the prolog (XML declaration + DTD + entity declarations) of a document.

options: see flush.

=item prolog     ($optional_filehandle, %options)

Returns the prolog (XML declaration + DTD + entity declarations) of a document.

options: see flush.

=item finish

Call Expat finish method.
Unsets all handlers (including internal ones that set context), but expat
continues parsing to the end of the document or until it finds an error.
It should finish up a lot faster than with the handlers set.

=item finish_print

Stop twig processing, flush the twig and proceed to finish printing the 
document as fast as possible. Use this method when modifying a document and 
the modification is done. 

=item Methods inherited from XML::Parser::Expat

A twig inherits all the relevant methods from XML::Parser::Expat. These 
methods can only be used during the parsing phase (they will generate
a fatal error otherwise).

Inherited methods are:

  depth in_element within_element context
  current_line current_column current_byte position_in_context
  base current_element element_index 
  namespace eq_name generate_ns_name new_ns_prefixes expand_ns_prefix current_ns_prefixes
  recognized_string original_string 
  xpcroak xpcarp 
                           

=item path($gi)

Returns the element context in a form similar to XPath's short
form: '/root/gi1/../gi'

=item get_xpath  ($xpath, $optional_offset)

Performs a get_xpath on the document root (see <Elt|"Elt">)

=item find_nodes

same as get_xpath

=item dispose

Useful only if you don't have WeakRef installed.

Reclaims properly the memory used by an XML::Twig object. As the object has
circular references it never goes out of scope, so if you want to parse lots 
of XML documents then the memory leak becomes a problem. Use $twig->dispose
to clear this problem.

=back 


=head2 Elt

=over 4

=item print         ($optional_filehandle, $optional_pretty_print_style)

Prints an entire element, including the tags, optionally to a 
$optional_filehandle, optionally with a $pretty_print_style.

The print outputs XML data so base entities are escaped.

=item sprint       ($elt, $optional_no_enclosing_tag)

Returns the xml string for an entire element, including the tags. 
If the optional second argument is true then only the string inside the 
element is returned (the start and end tag for $elt are not).
The text is XML-escaped: base entities (& and < in text, & < and " in
attribute values) are turned into entities.

=item gi                       

Returns the gi of the element (the gi is the C<generic identifier> the tag
name in SGML parlance).

=item tag

Same as L<gi|gi>

=item set_gi         ($gi)

Sets the gi (tag) of an element

=item set_tag        ($gi)

Sets the tag (=L<gi|gi>) of an element

=item root 

Returns the root of the twig in which the element is contained.

=item twig 

Returns the twig containing the element. 

=item parent        ($optional_cond)

Returns the parent of the element, or the first ancestor matching the 
L<cond|cond>

=item first_child   ($optional_cond)

Returns the first child of the element, or the first child matching the 
L<cond|cond>

=item first_child_text   ($optional_cond)

Returns the text of the first child of the element, or the first child
If there is no first_child then returns ''. This avoids getting the
child, checking for its existence then getting the text for trivial cases.

=item first_child_is   ($optional_cond)

Returns the element if the first child of the element (if it exists) passes
the $cond, '' otherwise

  if( $elt->first_child_is( 'title')) ... 

is equivalent to
  if( $elt->{first_child} && $elt->{first_child}->passes( 'title')) 

=item field         ($optional_cond)

Same method as first_child_text with a different name

=item prev_sibling  ($optional_cond)

Returns the previous sibling of the element, or the previous sibling matching
L<cond|cond>

=item next_sibling  ($optional_cond)

Returns the next sibling of the element, or the first one matching L<cond|cond>. 

=item next_elt     ($optional_elt, $optional_cond)

Returns the next elt (optionally matching L<cond|cond>) of the element. This is 
defined as the next element which opens after the current element opens.
Which usually means the first child of the element.
Counter-intuitive as it might look this allows you to loop through the
whole document by starting from the root.

The $optional_elt is the root of a subtree. When the next_elt is out of the
subtree then the method returns undef. You can then walk a sub tree with:

  my $elt= $subtree_root;
  while( $elt= $elt->next_elt( $subtree_root)
    { # insert processing code here
    }

=item prev_elt     ($optional_cond)

Returns the previous elt (optionally matching L<cond|cond>) of the
element. This is the first element which opens before the current one.
It is usually either the last descendant of the previous sibling or
simply the parent


=item children     ($optional_cond)

Returns the list of children (optionally which matches L<cond|cond>) of the
element. The list is in document order.

=item descendants     ($optional_cond)

Returns the list of all descendants (optionally which matches L<cond|cond>)
of the element. This is the equivalent of the getElementsByTagName of the DOM
(by the way, if you are really a DOM addict, you can use C<getElementsByTagName>
instead)

=item descendants_or_self ($optional_cond)

Same as descendants except that the element itself is included in the list
if it matches the $optional_cond

=item ancestors    ($optional_cond)

Returns the list of ancestors (optionally matching L<cond|cond>) of the element.
The list is ordered from the innermost ancestor to the outtermost one

NOTE: the element itself is not part of the list, in order to include it 
you will have to write:

  my @array= ($elt, $elt->ancestors)

=item att          ($att)

Returns the attribute value or C<undef>

=item set_att      ($att, $att_value)

Sets the attribute of the element to the given value

You can actually set several attributes this way:

  $elt->set_att( att1 => "val1", att2 => "val2");

=item del_att      ($att)

Delete the attribute for the element

You can actually delete several attributes at once:

  $elt->del_att( 'att1', 'att2', 'att3');


=item cut

Cuts the element from the tree. The element still exists, it can be copied
or pasted somewhere else, it is just not attached to the tree anymore.

=item copy        ($elt)

Returns a copy of the element. The copy is a "deep" copy: all sub elements of 
the element are duplicated.

=item paste       ($optional_position, $ref)

Pastes a (previously cut or newly generated) element. Dies if the element
already belongs to a tree.

The optional position element can be:

=over 4

=item first_child (default)

The element is pasted as the first child of the element object this
method is called on.

=item last_child

The element is pasted as the last child of the element object this
method is called on.

=item before

The element is pasted before the element object, as its previous
sibling.

=item after

The element is pasted after the element object, as its next sibling.

=item within

In this case an extra argument, $offset, should be supplied. The element
will be pasted in the reference element (or in its first text child) at the
given offset. To achieve this the reference element will be split at the 
offset.

=back

=item move       ($optional_position, $ref)

Move an element in the tree.
This is just a cut then a paste.  The syntax is the same as paste.

=item replace       ($ref)

Replaces an element in the tree. Sometimes it is just not possible to cut
an element then paste another in its place, so replace comes in handy.

=item delete

Cut the element and frees the memory.

=item prefix       ($text, $optional_option)

Add a prefix to an element. If the element is a PCDATA element the text
is added to the pcdata, if the elements first_child is a PCDATA then the
text is added to it's pcdata, otherwise a new PCDATA element is created 
and pasted as the first child of the element.

If the option is C<asis> then the prefix is added asis: it is created in
a separate PCDATA element with an asis property. You can then write:

  $elt1->prefix( '<b>', 'asis');

to create a C< <b> > in the output of C<print>.

=item suffix       ($text, $optional_option)

Add a suffix to an element. If the element is a PCDATA element the text
is added to the pcdata, if the elements last_child is a PCDATA then the
text is added to it's pcdata, otherwise a new PCDATA element is created 
and pasted as the last child of the element.

If the option is C<asis> then the suffix is added asis: it is created in
a separate PCDATA element with an asis property. You can then write:

  $elt2->suffix( '<b>', 'asis');

=item split_at        ($offset)

Split a text (C<PCDATA> or C<CDATA>) element in 2 at $offset, the original
element now holds the first part of the string and a new element holds the
right part. The new element is returned

If the element is not a text element then the first text child of the element
is split

=item split        ( $optional_regexp, $optional_tag, $optional_attribute_ref)

Split the text descendants of an element in place, the text is split using 
the regexp, if the regexp includes () then the matched separators will be 
wrapped in $optional_tag, with $optional_attribute_ref attributes

if $elt is C<< <p>tati tata <b>tutu tati titi</b> tata tati tata</p> >>

  $elt->split( qr/(ta)ti/, 'foo', {type => 'toto'} )

will change $elt to

  <p><foo type="toto">ta</foo> tata <b>tutu <foo type="toto">ta</foo>
      titi</b> tata <foo type="toto">ta</foo> tata</p> 

The regexp can be passed either as a string or as qr// (perl 5.005 and later),
it defaults to \s+ just as the C<split> built-in (but this would be quite a
useless behaviour without the $optional_tag parameter)

$optional_tag defaults to PCDATA or CDATA, depending on the initial element
type

The list of descendants is returned (including un-touched original elements 
and newly created ones)

=item mark        ( $regexp, $optional_tag, $optional_attribute_ref)

This method behaves exactly as L<split|split>, except only the newly created 
elements are returned

=item new          ($optional_gi, $optional_atts, @optional_content)

The gi is optional (but then you can't have a content ), the optional atts
is the ref of a hash of attributes, the content can be just a string or a 
list of strings and element. A content of '#EMPTY' creates an empty element;

 Examples: my $elt= XML::Twig::Elt->new();
           my $elt= XML::Twig::Elt->new( 'para', { align => 'center' });  
           my $elt= XML::Twig::Elt->new( 'para', { align => 'center' }, 'foo');  
	   my $elt= XML::Twig::Elt->new( 'br', '#EMPTY');
	   my $elt= XML::Twig::Elt->new( 'para');
           my $elt= XML::Twig::Elt->new( 'para', 'this is a para');  
           my $elt= XML::Twig::Elt->new( 'para', $elt3, 'another para'); 

The strings are not parsed, the element is not attached to any twig.

B<WARNING>: if you rely on ID's then you will have to set the id yourself. At
this point the element does not belong to a twig yet, so the ID attribute
is not known so it won't be strored in the ID list.

=item parse         ($string, %args)

Creates an element from an XML string. The string is actually
parsed as a new twig, then the root of that twig is returned.
The arguments in %args are passed to the twig.
As always if the parse fails the parser will die, so use an
eval if you want to trap syntax errors.

As obviously the element does not exist beforehand this method has to be 
called on the class: 

  my $elt= parse XML::Twig::Elt( "<a> string to parse, with <sub/>
                                  <elements>, actually tons of </elements>
				  h</a>");

=item get_xpath  ($xpath, $optional_offset)

Returns a list of elements satisfying the $xpath. $xpath is an XPATH-like 
expression.

A subset of the XPATH abbreviated syntax is covered:

  gi
  gi[1] (or any other positive number)
  gi[last()]
  gi[@att] (the attribute exists for the element)
  gi[@att="val"]
  gi[@att=~ /regexp/]
  gi[att1="val1" and att2="val2"]
  gi[att1="val1" or att2="val2"]
  gi[string()="toto"] (returns gi elements which text (as per the text method) 
                       is toto)
  gi[string()=~/regexp/] (returns gi elements which text (as per the text 
                          method) matches regexp)
  expressions can start with / (search starts at the document root)
  expressions can start with . (search starts at the current element)
  // can be used to get all descendants instead of just direct children
  * matches any gi
  
So the following examples from the XPATH recommendation 
(http://www.w3.org/TR/xpath.html#path-abbrev) work:

  para selects the para element children of the context node
  * selects all element children of the context node
  para[1] selects the first para child of the context node
  para[last()] selects the last para child of the context node
  */para selects all para grandchildren of the context node
  /doc/chapter[5]/section[2] selects the second section of the fifth chapter 
     of the doc 
  chapter//para selects the para element descendants of the chapter element 
     children of the context node
  //para selects all the para descendants of the document root and thus selects
     all para elements in the same document as the context node
  //olist/item selects all the item elements in the same document as the 
     context node that have an olist parent
  .//para selects the para element descendants of the context node
  .. selects the parent of the context node
  para[@type="warning"] selects all para children of the context node that have
     a type attribute with value warning 
  employee[@secretary and @assistant] selects all the employee children of the
     context node that have both a secretary attribute and an assistant 
     attribute


The elements will be returned in the document order.

If $optional_offset is used then only one element will be returned, the one 
with the appropriate offset in the list, starting at 0

Quoting and interpolating variables can be a pain when the Perl syntax and the 
XPATH syntax collide, so here are some more examples to get you started:

  my $p1= "p1";
  my $p2= "p2";
  my @res= $t->get_xpath( "p[string( '$p1') or string( '$p2')]");

  my $a= "a1";
  my @res= $t->get_xpath( "//*[@att=\"$a\"]);

  my $val= "a1";
  my $exp= "//p[ \@att='$val']"; # you need to use \@ or you will get a warning
  my @res= $t->get_xpath( $exp);

XML::Twig does not provide full XPATH support. If that's what you want then 
look no further than the XML::XPath module on CPAN.

Note that the only supported regexps delimiters are / and that you must 
backslash all / in regexps AND in regular strings.

=item find_nodes

same as get_xpath

=item text

Returns a string consisting of all the PCDATA and CDATA in an element, 
without any tags. The text is not XML-escaped: base entities such as &
and < are not escaped.

=item set_text        ($string)

Sets the text for the element: if the element is a PCDATA, just set its
text, otherwise cut all the children of the element and create a single
PCDATA child for it, which holds the text.

=item insert         ($gi1, [$optional_atts1], $gi2, [$optional_atts2],...)

For each gi in the list inserts an element $gi as the only child of the 
element.  The element gets the optional attributes in $optional_attsn.
All children of the element are set as children of the new element.
The upper level element is returned.

  $p->insert( table => { border=> 1}, 'tr', 'td') 

puts $p in a table with a visible border, a single tr and a single td and
returns the table element:

  <p><table border="1"><tr><td>original content of p</td></tr></table></p>

=item wrap_in        (@gi)

Wraps elements $gi as the successive ancestors of the element, returns the 
new element.
$elt->wrap_in( 'td', 'tr', 'table') wraps the element as a single cell in a 
table for example.

=item insert_new_elt $opt_position, $gi, $opt_atts_hashref, @opt_content

Combines a C<L<new|new>> and a C<L<paste|paste>>: creates a new element using 
$gi, $opt_atts_hashref and @opt_content which are arguments similar to those for
C<new>, then paste it, using $opt_position or C<'first_child'>, relative to 
$elt.

Returns the newly created element

=item erase

Erases the element: the element is deleted and all of its children are
pasted in its place.

=item set_content    ( $optional_atts, @list_of_elt_and_strings)
                     ( $optional_atts, '#EMPTY')

Sets the content for the element, from a list of strings and
elements.  Cuts all the element children, then pastes the list
elements as the children.  This method will create a PCDATA element
for any strings in the list.

The optional_atts argument is the ref of a hash of attributes. If this
argument is used then the previous attributes are deleted, otherwise they
are left untouched. 

B<WARNING>: if you rely on ID's then you will have to set the id yourself. At
this point the element does not belong to a twig yet, so the ID attribute
is not known so it won't be strored in the ID list.

A content of '#EMPTY' creates an empty element;

=item inherit_att  ($att, @optional_gi_list)

Returns the value of an attribute inherited from parent tags. The value
returned is found by looking for the attribute in the element then in turn
in each of its ancestors. If the @optional_gi_list is supplied only those
ancestors whose gi is in the list will be checked. 

=item all_children_are ($cond)

returns 1 if all children of the element pass the condition, 0 otherwise

=item level       ($optional_gi)

Returns the depth of the element in the twig (root is 0).
If the optional gi is given then only ancestors of the given type are counted.
 
B<WARNING>: in a tree created using the twig_roots option this will not return
the level in the document tree, level 0 will be the document root, level 1 
will be the twig_roots elements. During the parsing (in a TwigHandler)
you can use the depth method on the twig object to get the real parsing depth.

=item in           ($potential_parent)

Returns true if the element is in the potential_parent ($potential_parent is an element)

=item in_context   ($gi, $optional_level)

Returns true if the element is included in an element whose gi is $gi,
optionally within $optional_level levels. The returned value is the including
element.

=item pcdata

Returns the text of a PCDATA element or undef if the element is not PCDATA.

=item pcdata_xml_string

Returns the text of a PCDATA element or undef if the element is not PCDATA. 
The text is "XML-escaped" ('&' and '<' are replaced by '&amp;' and '&lt;')

=item set_pcdata     ($text)

Sets the text of a PCDATA element. 

=item append_pcdata  ($text)

Add the text at the end of a #PCDATA element.

=item is_cdata

Returns 1 if the element is a #CDATA element, returns 0 otherwise.

=item is_text

Returns 1 if the element is a #CDATA or #PCDATA element, returns 0 otherwise.

=item cdata

Returns the text of a CDATA element or undef if the element is not CDATA.

=item set_cdata     ($text)

Sets the text of a CDATA element. 

=item append_cdata  ($text)

Add the text at the end of a #CDATA element.

=item extra_data 

Returns the extra_data (comments and PI's) attached to an element

=item set_extra_data

Sets the extra_data (comments and PI's) attached to an element

=item append_extra_data

Append extra_data to teh existing extra_data before the element (if no
previous extra_data exists then it is created)

=item set_asis

Sets a property of the element that causes it to be output without being XML
escaped by the print functions: if it contains C<a < b> it will be output as
such and not as C<< a > b >>. This can be useful to create text elements that 
will be output as markup. Note that all PCDATA descendants of the element
are also marked as having the property (they are the ones impacted by the
change).

=item set_not_asis

Unsets the asis property for the element and its text descendants.

=item is_asis

Returns the asis property status of the element ( 1 or C<undef>)

=item closed                   

Returns true if the element has been closed. Might be usefull if you are
somewhere in the tree, during the parse, and have no idea whether a parent
element is completely loaded or not.

=item get_type

Returns the type of the element: '#ELT' for "real" elements, or '#PCDATA',
'#CDATA', '#COMMENT', '#ENT', '#PI'

=item is_elt

Returns the gi if the element is a "real" element, or 0 if it is PCDATA, 
CDATA...

=item contains_only_text

Returns 1 if the element does not contain any other "real" element

=item is_field

same as contains_only_text

=item is_pcdata

Returns 1 if the element is a #PCDATA element, returns 0 otherwise.

=item is_empty

Returns 1 if the element is empty, 0 otherwise

=item set_empty

Flags the element as empty. No further check is made, so if the element
is actually not empty the output will be messed. The only effect of this 
method is that the output will be <gi att="value""/>.

=item set_not_empty

Flags the element as not empty. if it is actually empty then the element will
be output as <gi att="value""></gi>

=item child ($offset, $optional_gi)

Returns the $offset-th child of the element, optionally the $offset-th child 
with a gi of $optional_gi. The children are treated as a list, so 
$elt->child( 0) is the first child, while $elt->child( -1) is the last child.

=item child_text ($offset, $optional_gi)

Returns the text of a child or undef if the sibling does not exist. Arguments
are the same as child.

=item last_child    ($optional_gi)

Returns the last child of the element, or the last child whose gi is 
$optional_gi (ie the last of the element children whose gi matches).

=item last_child_text   ($optional_gi)

Same as first_child_text but for the last child.

=item sibling  ($offset, $optional_gi)

Returns the next or previous $offset-th sibling of the element, or the 
$offset-th one whose gi is $optional_gi. If $offset is negative then a 
previous sibling is returned, if $offset is positive then  a next sibling is 
returned. $offset=0 returns the element if there is no $optional_gi or if the 
element gi matches $optional_gi, undef otherwise.

=item sibling_text ($offset, $optional_gi)

Returns the text of a sibling or undef if the sibling does not exist. 
Arguments are the same as sibling.

=item prev_siblings ($optional_gi)

Returns the list of previous siblings (optionaly whose gi is $optional_gi)
for the element. The elements are ordered in document order.

=item next_siblings ($optional_gi)

Returns the list of siblings (optionaly whose gi is $optional_gi)
following the element. The elements are ordered in document order.


=item atts

Returns a hash ref containing the element attributes

=item set_atts      ({att1=>$att1_val, att2=> $att2_val... })

Sets the element attributes with the hash ref supplied as the argument

=item del_atts

Deletes all the element attributes.

=item att_names

returns a list of the attribute names for the element

=item att_xml_string ($att, $optional_quote)

Returns the attribute value, where '&', '<' and $quote (" by default)
are XML-escaped

=item set_id       ($id)

Sets the id attribute of the element to the value.
See C<L<elt_id|elt_id>> to change the id attribute name

=item id

Gets the id attribute value

=item del_id       ($id)

Deletes the id attribute of the element and remove it from the id list
for the document

=item DESTROY

Frees the element from memory.

=item start_tag

Returns the string for the start tag for the element, including 
the /> at the end of an empty element tag

=item end_tag

Returns the string for the end tag of an element.  For an empty
element, this returns the empty string ('').

=item xml_string ($elt)

Equivalent to $elt->sprint( 1), returns the string for the entire element, 
excluding the element's tags (but nested element tags are present)

=item set_pretty_print ($style)

Sets the pretty print method, amongst 'none' (default), 'nsgmls', 'nice', 
'indented', 'record' and 'record_c'

=over 4

=item none

the default, no \n is used

=item nsgmls

nsgmls style, with \n added within tags

=item nice

adds \n wherever possible (NOT SAFE, can lead to invalid XML)

=item indented

same as nice plus indents elements (NOT SAFE, can lead to invalid XML) 

=item record

table-oriented pretty print, one field per line 

=item record_c

table-oriented pretty print, more compact than record, one record per line 

=back

=item set_empty_tag_style ($style)

Sets the method to output empty tags, amongst 'normal' (default), 'html',
and 'expand', 

=item set_indent ($string)

Sets the indentation for the indented pretty print style (default is 2 spaces)

=item set_quote ($quote)

Sets the quotes used for attributes. can be 'double' (default) or 'single'

=item cmp       ($elt)
  Compare the order of the 2 elements in a twig.

  $a is the <A>..</A> element, $b is the <B>...</B> element
  
  document                        $a->cmp( $b)
  <A> ... </A> ... <B>  ... </B>     -1
  <A> ... <B>  ... </B> ... </A>     -1
  <B> ... </B> ... <A>  ... </A>      1
  <B> ... <A>  ... </A> ... </B>      1
   $a == $b                           0
   $a and $b not in the same tree   undef

=item before       ($elt)

Returns 1 if $elt starts before the element, 0 otherwise. If the 2 elements 
are not in the same twig then return undef.

    if( $a->cmp( $b) == -1) { return 1; } else { return 0; }

=item after       ($elt)

Returns 1 if $elt starts after the element, 0 otherwise. If the 2 elements 
are not in the same twig then return undef.

    if( $a->cmp( $b) == -1) { return 1; } else { return 0; }

=item path

Returns the element context in a form similar to XPath's short
form: '/root/gi1/../gi'

=item private methods

=over 4

=item set_parent        ($parent)

=item set_first_child   ($first_child)

=item set_last_child    ($last_child)

=item set_prev_sibling  ($prev_sibling)

=item set_next_sibling  ($next_sibling)

=item set_twig_current

=item del_twig_current

=item twig_current

=item flushed

This method should NOT be used, always flush the twig, not an element.

=item set_flushed

=item del_flushed

=item flush

=item contains_text

=back

Those methods should not be used, unless of course you find some creative 
and interesting, not to mention useful, ways to do it.

=back

=head2 cond

Most of the navigation functions accept a condition as an optional argument
The first element (or all elements for C<L<children|children>> or 
C<L<ancestors|ancestors>>) that passes the condition is returned.

The condition can be 

=over 4

=item #ELT

return a "real" element (not a PCDATA, CDATA, comment or pi element) 

=item #TEXT

return a PCDATA or CDATA element

=item XPath expression

actually a subset of XPath that makes sense in this context

  gi
  /regexp/
  gi[@att]
  gi[@att="val"]
  gi[@att=~/regexp/]
  gi[text()="blah"]
  gi[text(subelt)="blah"]
  gi[text()=~ /blah/]
  gi[text(subelt)=~ /blah/]
  *[@att]            (the * is actually optional)
  *[@att="val"]
  *[@att=~/regexp/]

=item regular expression

return an element whose gi matches the regexp. The regexp has to be created 
with C<qr//> (hence this is available only on perl 5.005 and above)

=item code reference

applies the code, passing the current element as argument, if the code returns
true then the element is returned, if it returns false then the code is applied
to the next candidate.

=back

=head2 Entity_list

=over 4

=item new

Creates an entity list.

=item add         ($ent)

Adds an entity to an entity list.

=item delete     ($ent or $gi).

Deletes an entity (defined by its name or by the Entity object)
from the list.

=item print      ($optional_filehandle)

Prints the entity list.

=back


=head2 Entity

=over 4

=item new        ($name, $val, $sysid, $pubid, $ndata)

Same arguments as the Entity handler for XML::Parser.

=item print       ($optional_filehandle)

Prints an entity declaration.

=item text

Returns the entity declaration text.

=back


=head1 EXAMPLES

See the test file in t/test[1-n].t 
Additional examples (and a complete tutorial) can be found at 
http://www.xmltwig.com/

To figure out what flush does call the following script with an
 xml file and an element name as arguments

  use XML::Twig;

  my ($file, $elt)= @ARGV;
  my $t= XML::Twig->new( twig_handlers => 
      { $elt => sub {$_[0]->flush; print "\n[flushed here]\n";} });
  $t->parsefile( $file, ErrorContext => 2);
  $t->flush;
  print "\n";



=head1 NOTES


=head2 DTD Handling

There are 3 possibilities here.  They are:

=over 4

=item No DTD

No doctype, no DTD information, no entity information, the world is simple...

=item Internal DTD

The XML document includes an internal DTD, and maybe entity declarations.

If you use the load_DTD option when creating the twig the DTD information and
the entity declarations can be accessed.

The DTD and the entity declarations will be flush'ed (or print'ed) either as is
(if they have not been modified) or as reconstructed (poorly, comments are lost, 
order is not kept, due to it's content this DTD should not be viewed by anyone) 
if they have been modified. You can also modify them directly by changing the 
$twig->{twig_doctype}->{internal} field (straight from XML::Parser, see the 
Doctype handler doc)

=item External DTD

The XML document includes a reference to an external DTD, and maybe entity 
declarations.

If you use the load_DTD when creating the twig the DTD information and the 
entity declarations can be accessed. The entity declarations will be flush'ed 
(or print'ed) either as is (if they have not been modified) or as reconstructed 
(badly, comments are lost, order is not kept).

You can change the doctype through the $twig->set_doctype method and print the
dtd through the $twig->dtd_text or $twig->dtd_print methods.

If you need to modify the entity list this is probably the easiest way to do it.

=back


=head2 Flush

If you set handlers and use flush, do not forget to flush the twig one
last time AFTER the parsing, or you might be missing the end of the document.

Remember that element handlers are called when the element is CLOSED, so
if you have handlers for nested elements the inner handlers will be called
first. It makes it for example trickier than it would seem to number nested
clauses.



=head1 BUGS

=over 4

=item entity handling

Due to XML::Parser behaviour, non-base entities in attribute values disappear:
C<att="val&ent;"> will be turned into att => val, unless you use the 
C<keep_encoding> argument to C<< XML::Twig->new >> 

=item DTD handling

Basically the DTD handling methods are competely bugged. No one uses them and it
seems very difficult to get them to work in all cases, including with 2 
slightly incompatible versions of XML::Parser.

So use XML::Twig with standalone documents, or with documents refereing to an
external DTD, but don't expect it to properly parse and even output back the
DTD.

=item memory leak

If you use a lot of twigs you might find that you leak quite a lot of memory
(about 2Ks per twig). You can use the C<L<dispose|dispose>> method to free that
memory after you are done.

If you create elements the same thing might happen, use the C<L<delete|delete>>
method to get rid of them.

Alternatively installing the WeakRef module on a version of Perl that supports
it will get rid of the memory leaks automagically.

=item ID list

The ID list is NOT updated when ID's are modified or elements cut or
deleted.

=item change_gi

This method will not function properly if you do:

     $twig->change_gi( $old1, $new);
     $twig->change_gi( $old2, $new);
     $twig->change_gi( $new, $even_newer);

=item sanity check on XML::Parser method calls

XML::Twig should really prevent calls to some XML::Parser methods, especially 
the setHandlers method.

=back

=head1 Globals

These are the things that can mess up calling code, especially if threaded.
They might also cause problem under mod_perl. 

=over 4

=item Exported constants

Whether you want them or not you get them! These are subroutines to use
as constant when creating or testing elements

=over 4

=item PCDATA

returns '#PCDATA'

=item CDATA

returns '#CDATA'

=item PI

returns '#PI', I had the choice between PROC and PI :--(

=back

=item Module scoped values: constants

these should cause no trouble:

  %base_ent= ( '>' => '&gt;',
               '<' => '&lt;',
               '&' => '&amp;',
               "'" => '&apos;',
               '"' => '&quot;',
             );
  CDATA_START   = "<![CDATA[";
  CDATA_END     = "]]>";
  PI_START      = "<?";
  PI_END        = "?>";
  COMMENT_START = "<!--";
  COMMENT_END   = "-->";

pretty print styles

  ( $NSGMLS, $NICE, $INDENTED, $RECORD1, $RECORD2)= (1..5);

empty tag output style

  ( $HTML, $EXPAND)= (1..2);

=item Module scoped values: might be changed

Most of these deal with pretty printing, so the worst that can
happen is probably that XML output does not look right, but is
still valid and processed identically by XML processors.

$empty_tag_style can mess up HTML bowsers though and changing $ID 
would most likely create problems.

  $pretty=0;           # pretty print style
  $quote='"';          # quote for attributes
  $INDENT= '  ';       # indent for indented pretty print
  $empty_tag_style= 0; # how to display empty tags
  $ID                  # attribute used as a gi ('id' by default)

=item Module scoped values: definitely changed

These 2 variables are used to replace gi's by an index, thus 
saving some space when creating a twig. If they really cause
you too much trouble, let me know, it is probably possible to
create either a switch or at least a version of XML::Twig that 
does not perform this optimisation.

  %gi2index;     # gi => index
  @index2gi;     # list of gi's

=back

=head1 TODO 

=over 4

=item SAX handlers

Allowing XML::Twig to work on top of any SAX parser, and to emit SAX
events to a handler is a priority for version 3.01

=item multiple twigs are not well supported

A number of twig features are just global at the moment. These include
the ID list and the "gi pool" (if you use change_gi then you change the gi 
for ALL twigs).

A future version will try to support this while trying not to be to
hard on performance (at least when a single twig is used!).


=back


=head1 BENCHMARKS

You can use the C<benchmark_twig> file to do additional benchmarks.
Please send me benchmark information for additional systems.

=head1 AUTHOR

Michel Rodriguez <m.v.rodriguez@ieee.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Bug reports and comments to m.v.rodriguez@ieee.org

The XML::Twig page is at http://www.xmltwig.com/xmltwig/
It includes examples and a tutorial at 
  http://www.xmltwig.com/xmltwig/tutorial/index.html

=head1 SEE ALSO

XML::Parser


=cut


