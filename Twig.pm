# XML::Twig 2.01.11 @(#)Twig.pm.slow - 2000/08/18
#
# Copyright (c) 1999-2000 Michel Rodriguez
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


use constant (PCDATA => '#PCDATA');
use constant (CDATA  => '#CDATA');
use constant (PI     => '#PI');

use constant (EMPTY  => '#EMPTY');



BEGIN
{
    require XML::Parser;
    $VERSION = '2.01';

    my $needVersion = '2.23';
    croak "need at least XML::Parser version $needVersion"
	unless $XML::Parser::VERSION >= $needVersion;

    import XML::Twig::Elt;
    import XML::Twig::Entity;
    import XML::Twig::Entity_list;
}

@ISA = ("XML::Parser");

# fake gi's used in TwigHandlers and StartTagHandlers
my $ALL    = '_all_';     # the associated function is always called
my $DEFAULT= '_default_'; # the function is called if no other handler has been


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
                    Proc       => \&twig_proc, 
                  );

my %twig_handlers_roots=
                  ( Start      => \&twig_start_check_roots, 
                    End        => \&twig_end_check_roots, 
                    Char       => undef, 
                    Entity     => undef, 
                    XMLDecl    => undef, 
                    Doctype    => undef, 
                    Element    => undef, 
                    Attlist    => undef, 
                    CdataStart => undef, 
                    CdataEnd   => undef, 
                    Proc       => undef, 
                  );

my %twig_handlers_roots_print=
                  ( Start      => \&twig_start_check_roots_print, 
                    End        => \&twig_end_check_roots_print, 
                    Char       => \&twig_print, 
                    Entity     => \&twig_print, 
                    XMLDecl    => \&twig_print, 
                    Doctype    => \&twig_print, 
                    Element    => \&twig_print, 
                    Attlist    => \&twig_print, 
                    CdataStart => \&twig_print, 
                    CdataEnd   => \&twig_print, 
                    Proc       => \&twig_print, 
                  );

my %twig_handlers_roots_print_original=
                  ( Start      => \&twig_start_check_roots_print_original, 
                    End        => \&twig_end_check_roots_print_original, 
                    Char       => \&twig_print_original, 
                    Entity     => \&twig_print_original, 
                    XMLDecl    => \&twig_print_original, 
                    Doctype    => \&twig_print_original, 
                    Element    => \&twig_print_original, 
                    Attlist    => \&twig_print_original, 
                    CdataStart => \&twig_print_original, 
                    CdataEnd   => \&twig_print_original, 
                    Proc       => \&twig_print_original, 
                  );

my %twig_handlers_finish_print=
                       ( Start      => \&twig_print, 
                         End        => \&twig_print_end, 
                         Char       => \&twig_print, 
                         Entity     => \&twig_print, 
                         XMLDecl    => \&twig_print, 
                         Doctype    => \&twig_print, 
                         Element    => \&twig_print, 
                         Attlist    => \&twig_print, 
                         CdataStart => \&twig_print, 
                         CdataEnd   => \&twig_print, 
                         Proc       => \&twig_print, 
                       );

my %twig_handlers_finish_print_original=
                       ( Start      => \&twig_print_original, 
                         End        => \&twig_print_end_original, 
                         Char       => \&twig_print_original, 
                         Entity     => \&twig_print_original, 
                         XMLDecl    => \&twig_print_original, 
                         Doctype    => \&twig_print_original, 
                         Element    => \&twig_print_original, 
                         Attlist    => \&twig_print_original, 
                         CdataStart => \&twig_print_original, 
                         CdataEnd   => \&twig_print_original, 
                         Proc       => \&twig_print_original, 
                       );

# those handlers are only used if the entities are NOT to be expanded
my %twig_noexpand_handlers= ( Default => \&twig_default, 
                            );

my $ID= 'id'; # default value, set by the Id argument

# used to store the gi's
# should be set for each twig really, at least when there are several
my %gi2index; # gi => index
my @index2gi; # list of gi's

# used to replace the predefined entities if NoExpand is used
my %base_ent= ( '>' => '&gt;',
                '<' => '&lt;',
                '&' => '&amp;',
                "'" => '&apos;',
                '"' => '&quot;',
              );

1;

sub new
  { my ($class, %args) = @_;
    my $handlers;

    my $self= new XML::Parser(%args);
    bless $self, $class;

    if( exists $args{TwigHandlers})
      { $handlers= $args{TwigHandlers};
        $self->setTwigHandlers( $handlers);
        delete $args{TwigHandlers};
      }

   if( exists $args{Id})
      { $ID= $args{Id};
        delete $args{ID};
      }

     if( $args{NoExpand})
      { $self->setHandlers( %twig_noexpand_handlers);
      }

    # take are of twig-specific arguments
    $self->{twig_starttag_handlers}= $args{StartTagHandlers};
    delete $args{StartTagHandlers};
    $self->{twig_dtd_handler}= $args{DTDHandler};
    delete $args{DTDHandler};
    $self->{twig_char_handler}= $args{CharHandler};
    delete $args{CharHandler};
    $self->{twig_read_external_dtd}= $args{LoadDTD};
    delete $args{LoadDTD};

    # deal with TwigRoots argument, a hash of elements for which
    # subtrees will be built (and associated handlers)
     
    if( $args{TwigRoots})
      { $self->setTwigRoots( $args{TwigRoots});
        delete $args{TwigRoots}; 
      }

    if( $args{PrettyPrint})
      { $self->set_pretty_print( $args{PrettyPrint}); }

    if( $args{EmptyTags})
      { $self->set_empty_tag_style( $args{EmptyTags}); }

    if( $args{TwigPrintOutsideRoots})
      { die "cannot use TwigPrintOutsideRoots without TwigRoots"
          unless( $self->{twig_roots});
        $self->{twig_default_print}= $args{TwigPrintOutsideRoots};
      }

    # space policy
    if( $args{KeepSpaces})
      { die "cannot use both KeepSpaces and DiscardSpaces"
          if( $args{DiscardSpaces});
        die "cannot use both KeepSpaces and KeepSpacesIn"
          if( $args{KeepSpacesIn});
        $self->{twig_keep_spaces}=1;
        delete $args{KeepSpaces}; 
      }
    if( $args{DiscardSpaces})
      { die "cannot use both DiscardSpaces and KeepSpacesIn"
          if( $args{KeepSpacesIn});
        $self->{twig_discard_spaces}=1; 
        delete $args{DiscardSpaces}; 
      }
    if( $args{KeepSpacesIn})
      { die "cannot use both KeepSpacesIn and DiscardSpacesIn"
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

    # encoding options
    die "cannot use both KeepEncoding and ConvertEncoding options"
      if( $args{KeepEncoding} && $args{ConvertEncoding});

    $self->{twig_keep_ents}= $args{KeepEncoding};
    delete $args{KeepEncoding};

    if( my $encoding= $args{ConvertEncoding})
      { $self->{twig_convert_encoding}= $encoding;
        unless( $encoding eq 'original')
          { my $out_map= Unicode::Map8->new( $encoding) 
            || die "cannot find map for encoding $encoding";
          }

        delete $args{ConvertEncoding};
      }

    # set handlers
    if( $self->{twig_roots})
      { if( $self->{twig_default_print})
          { if( $self->{twig_keep_ents})
              { $self->setHandlers( %twig_handlers_roots_print_original); }
            else
              { $self->setHandlers( %twig_handlers_roots_print);  }
          }
        else
          { $self->setHandlers( %twig_handlers_roots); }
      }
    else
      { $self->setHandlers( %twig_handlers); }

    # XML::Parser::Expat does not like this handler to be set. So in order to use
    # the various sets of handlers on XML::Parser or XML::Parser::Expat objects
    # when needed this one has to be set only once, here, at XML::Parser level
    $self->setHandlers( Init => \&twig_init);

    
    $self->{twig_entity_list}= new XML::Twig::Entity_list; 

    $self->{twig_id}= $ID; 
    $self->{twig_stored_spaces}='';

    $self->{twig}= $self;

    return $self;

  }


sub set_handler
  { my( $handlers, $path, $handler)= @_;

    $handlers ||= {}; # create the handlers struct if necessary

    my $previous_handler= $handlers->{handlers}->{$path} || undef;

    if( $path=~/\/.*\/([^\/]*)$/)
      { # a full path has been defined
        $handlers->{path_handlers} ||= {}; # create path hash if need be
        # update the path_handlers count, knowing that
        # either the previous or the new handler can be undef
        $handlers->{path_handlers}->{$1}-- if( $previous_handler);
        $handlers->{path_handlers}->{$1}++ if( $handler);
      }
    elsif( $path=~/\/([^\/]*)$/)
      { # a partial path has been defined
        $handlers->{subpath_handlers} ||= {}; # create hash if needed
        $handlers->{subpath_handlers}->{$1}-- if( $previous_handler);
        $handlers->{subpath_handlers}->{$1}++ if( $handler);
      }
    # check for attribute conditions
    elsif( $path=~/^\s*([\w-]+)  # elt
                 \s*\[\s*\@      #    [@
                 ([\w-]+)        #      att
                 \s*=\s*(["'])   #         = "          (or ')
                 (.*?)           #            value
                 \3\]\s*$/gx)    #                 "]   (or ')
      { my( $gi, $att, $val)= ($1, $2, $4);
        $handlers->{att_handlers} ||= {};
        if( $previous_handler)
          { # replace or remove the previous handler
            my $i=0; # so we can splice the array if need be
            foreach my $exp ( @{$handlers->{att_handlers_exp}->{$gi}})
             { if( ($exp->{att} eq $att) && ($exp->{val} eq $val) )
                 { if( $handler) # just replace the handler
                     { $exp->{handler}= $handler; }
                   else          # remove the handler
                     { $handlers->{att_handlers}->{$gi}--;
                       splice( @{$handlers->{att_handlers_exp}->{$gi}}, $i, 1);
                       last;
                     }
                 }
               $i++;
             }
          }
        elsif( $handler)
          { # new handler only
	    $handlers->{att_handlers}->{$gi}++;
            my $exp={att => $att, val => $val, handler => $handler};
            $handlers->{att_handlers_exp}->{$gi} ||= [];
            push @{$handlers->{att_handlers_exp}->{$gi}}, $exp;
          }
      }
    # check for string conditions
    elsif( $path=~/^\s*([\w-]+)  # elt
                 \s*\[\s*string  #    [string
		 \s*\(\s*\)      #           ()
                 \s*=\s*(["'])   #              = "          (or ')
                 (.*?)           #                 text
                 \2\]\s*$/gx)    #                      "]   (or ')
      { my( $gi, $text)= ($1, $3);
        $handlers->{text_handlers} ||= {};
        if( $previous_handler)
          { # replace or remove the previous handler
            my $i=0; # so we can splice the array if need be
            foreach my $exp ( @{$handlers->{text_handlers_exp}->{$gi}})
             { if( ($exp->{text} eq $text) )
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
            my $exp={text => $text, handler => $handler};
            $handlers->{text_handlers_exp}->{$gi} ||= [];
            push @{$handlers->{text_handlers_exp}->{$gi}}, $exp;
          }
      }
    # now trap errors in the expression
    elsif( $path !~ /\A[\w-]+\Z/) 
      { # the trigger does not look like a gi
        croak "unrecognized expression: $path";
      }
	
    # this both takes care of the simple (gi) handlers and store
    # the handler code reference for other handlers
    $handlers->{handlers}->{$path}= $handler;

    return $previous_handler;
  }

sub reset_handlers
  { my $handlers= shift;
    delete $handlers->{handlers};
    delete $handlers->{path_handlers};
    delete $handlers->{subpath_handlers};
    $handlers->{att_handlers_exp}=[] if( $handlers->{att_handlers});
    delete $handlers->{att_handlers};
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

# a little more complex: set the twig_handlers if a code ref is given
sub setTwigRoots
  { my( $t, $handlers)= @_;
    my $previous_roots= $t->{twig_roots} || undef;
    reset_handlers($t->{twig_roots});
    $t->{twig_roots}= set_handlers( $handlers);
    foreach my $path (keys %{$handlers})
      { $t->{twig_handlers}||= {};
        set_handler( $t->{twig_handlers}, $path, $handlers->{$path})
          if( ref $handlers->{$path} eq 'CODE'); 
      }
    return $previous_roots;
  }


# just store the reference to the expat object in the twig
sub twig_init
  { my $p= shift;
    my $t=$p->{twig};
    $t->{twig_parser}= $p; 
  }


# the default twig handlers, which build the tree
sub twig_start($$%)
  { my ($p, $gi, %att)  = @_;
    my $t=$p->{twig};

    # undo the XML::Parser conversion
    unless( $t->{NoExpand})
      { foreach my $att (keys %att)
          { $att{$att}=~ s/([&<>'"])/$base_ent{$1}/g; }
      }

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
        $parent= $parent->{'parent'};
      }

    my $elt= new XML::Twig::Elt( $gi);
    $elt->{'att'}=  \%att;
 
    delete $parent->{'twig_current'} if( $parent);
    $t->{twig_current}= $elt;
    $elt->{'twig_current'}=1;


    if( $parent)
      { my $prev_sibling= $parent->{'last_child'};
        if( $prev_sibling) 
          { $prev_sibling->{'next_sibling'}=  $elt; 
            $elt->{'prev_sibling'}=  $prev_sibling;
          }

        $elt->{'parent'}=  $parent;
        $parent->{'first_child'}=  $elt unless( $parent->{'first_child'}); 
        $parent->{'last_child'}=  $elt;
      }
    else 
      { # processing root
        $t->{twig_root}= $elt;
        $elt->{twig}= $t;
        # call dtd handlerif need be
        $t->{twig_dtd_handler}->($t, $t->{twig_dtd})
          if( defined $t->{twig_dtd_handler});
          
      }
    
    if( $p->recognized_string=~ /\/>\Z/) { $elt->{empty}=1; }

    # if the element is ID-ed then store that info
    my $id= $elt->{'att'}->{$ID};
    if( $id) { $t->{twig_id_list}->{$id}= $elt; }


    # call user handler if need be
    if( $t->{twig_starttag_handlers})
      { # call all appropriate handlers
        my @handlers= handler( $t, $t->{twig_starttag_handlers}, $gi, $elt);
        foreach my $handler ( @handlers)
          { $handler->($t, $elt) || last; }
	# call _all_ handler if needed
        if( my $all= $t->{twig_starttag_handlers}->{handlers}->{$ALL})
          { $all->($t, $elt); }
      }
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
        $elt= $elt->{'parent'} if($elt->{'parent'});
      }

    my $parent= $elt->{parent};
    $parent->{'twig_current'}=1 if( $parent);
    $t->{twig_current}= $parent;

    if( $t->{twig_handlers})
      { # look for start tag handlers
        my @handlers= handler( $t, $t->{twig_handlers}, $gi, $elt);
        foreach my $handler ( @handlers)
          { $handler->($t, $elt) || last; }
	# call _all_ handler if needed
        if( my $all= $t->{twig_handlers}->{handlers}->{$ALL})
          { $all->($t, $elt); }
      }

    # if twig_roots is set for the element then set appropriate handler
    if( handler( $t, $t->{twig_roots}, $gi, $elt))
      { if( $t->{twig_default_print})
          { if( $t->{twig_keep_ents})
              { $p->setHandlers( %twig_handlers_roots_print_original); }
            else
              { $p->setHandlers( %twig_handlers_roots_print); }
          }
        else
          { $p->setHandlers( %twig_handlers_roots); }
      }

  }

# return of handler that can be activated for an element 
# (either of CODE ref's or 1's for TwigRoots)

sub handler
  { my( $t, $handlers, $gi, $elt)= @_;

    my @found_handlers=();

    # warning: $elt can be either a regular element or a ref to the
    #          attribute hash (when called for an element for which
    #          the XML::Twig::Elt has not been built, outside of
    #          the TwigRoots)

    # check for a text expression
    if( $handlers->{text_handlers}->{$gi})
      { my @text_handlers= @{$handlers->{text_handlers_exp}->{$gi}};
        foreach my $exp ( @text_handlers)
          { if( $elt->text eq $exp->{text})
              { push @found_handlers, $exp->{handler}; }
          }
      }

    # check for an attribute expression
    if( $handlers->{att_handlers}->{$gi})
      { my @att_handlers= @{$handlers->{att_handlers_exp}->{$gi}};
        foreach my $exp ( @att_handlers)
          { my $att_val;
	    # get the attribute value
	    if( ref $elt eq 'HASH')
	      { $att_val= $elt->{$exp->{att}} || ''; }    # $elt is lte atts hash
	    else
	      { $att_val= $elt->{'att'}->{$exp->{att}} || ''; }# $elt is an element
	  
	    if( $att_val eq $exp->{val})
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
    if( defined $handlers->{handlers}->{$gi})
      { push @found_handlers, $handlers->{handlers}->{$gi}; }

    # if no handler found call default handler if defined
    if( !@found_handlers && defined $handlers->{$DEFAULT})
      { push @found_handlers, $handlers->{$DEFAULT}; }

    return @found_handlers; # empty if no handler found

  }

sub twig_char($$$)
  { my ($p, $string, $called_from_default)= @_;
    my $t=$p->{twig}; 

    # if KeepEncoding was set then use the original string instead of
    # the parsed (UTF-8 converted) one
    if( $t->{twig_keep_ents})
      { $string= $p->original_string(); }
    elsif( !$called_from_default && !$t->{NoExpand})
      { $string=~ s/&/&amp;/g; }

    # escape special characters
    $string=~ s/([<>"'])/$base_ent{$1}/g
                unless( $t->{twig_in_cdata} || $t->{NoExpand} || $t->{twig_keep_ents});
    $string=~ s/]]&amp;lt;/]]&lt;/g if( $t->{twig_in_cdata});

    if( $t->{twig_char_handler})
      { $string= $t->{twig_char_handler}->( $string); }

    my $elt= $t->{twig_current};

    if(    $t->{twig_in_cdata})
      { # text is the continuation of a previously created pcdata
        $elt->{cdata}.=  $t->{twig_stored_spaces}.$string; } 
    elsif( $t->{twig_in_pcdata})
      { # text is the continuation of a previously created cdata
        $elt->{pcdata}.=  $string; } 
    else
      { # if text is just spaces then store it, we'll decide what to 
        # do with it according to the space policy later
        if( $string=~/\A\s*\Z/)
          { $t->{twig_stored_spaces}.= $string; 
          } 
        else
          { my $new_elt= insert_pcdata( $t, $t->{twig_stored_spaces}.$string);
	    delete $elt->{'twig_current'};
	    $new_elt->{'twig_current'}=1;
	    $t->{twig_current}= $new_elt;
	    $t->{twig_in_pcdata}=1;
	  }
      }
  }

sub twig_cdatastart
  { my $p= shift;
    my $t=$p->{twig};

    $t->{twig_in_cdata}=1;
    my $twig_current= $t->{twig_current};
    my $cdata=  new XML::Twig::Elt( '#CDATA');
    if( $t->{twig_in_pcdata})
      { # create the node as a sibling of the #PCDATA
        $cdata->{'prev_sibling'}=  $twig_current;
        $twig_current->{'next_sibling'}=  $cdata;
	my $parent= $twig_current->{'parent'};
        $cdata->{'parent'}=  $parent;
        $parent->{'last_child'}=  $cdata;
        $t->{twig_in_pcdata}=0;
      }
    else
      { # create the node as a child of the current element
        $cdata->{'parent'}=  $twig_current;
        $twig_current->{'last_child'}=  $cdata;
        if( my $prev_sibling= $twig_current->{'first_child'})
          { $cdata->{'prev_sibling'}=  $prev_sibling;
            $prev_sibling->{'next_sibling'}=  $cdata;
          }
        else
          { $twig_current->{'first_child'}=  $cdata; }
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
    # replace the $amp;lt thingy 
    my $cdata= $elt->{'cdata'};
    $cdata=~ s/]]&amp;lt;/]]&lt;/g;
    $elt->{'cdata'}=  $cdata;

    $elt= $elt->{'parent'};
    $t->{twig_current}= $elt;
    $elt->{'twig_current'}=1;
  }

sub twig_proc
  { my( $p, $target, $data)= @_;
    my $t=$p->{twig};

    my $parent= $t->{twig_current};    # always defined
    my $elt=  new XML::Twig::Elt( PCDATA);
    $elt->{'pcdata'}=  "<?$target $data?>";
    my $prev_sibling= $parent->{'last_child'};
    if( $prev_sibling) 
      { $prev_sibling->{'next_sibling'}=  $elt; 
        $elt->{'prev_sibling'}=  $prev_sibling;
      }

    $elt->{'parent'}=  $parent;
    $parent->{'first_child'}=  $elt unless( $parent->{'first_child'}); 
    $parent->{'last_child'}=  $elt;
  }

sub insert_pcdata
  { my( $t, $string)= @_;
    # create a new #PCDATA element
    my $parent= $t->{twig_current};    # always defined
    my $elt=  new XML::Twig::Elt( PCDATA);
    $elt->{'pcdata'}=  $string;
    my $prev_sibling= $parent->{'last_child'};
    if( $prev_sibling) 
      { $prev_sibling->{'next_sibling'}=  $elt; 
        $elt->{'prev_sibling'}=  $prev_sibling;
      }
    else
      { $parent->{'first_child'}=  $elt; }

    $elt->{'parent'}=  $parent;
    $parent->{'last_child'}=  $elt;
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
    my $ent=new XML::Twig::Entity( $name, $val, $sysid, $pubid, $ndata);
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
    $t->{twig_doctype}= {};                    # create 
    $t->{twig_doctype}->{name}= $name;         # always there
    $t->{twig_doctype}->{sysid}= $sysid;       #  
    $t->{twig_doctype}->{pub}= $pub;           #  
    $t->{twig_doctype}->{internal}=$internal; 
    # now check if we want to get the DTD info
    if( $t->{twig_read_external_dtd} && $sysid)
      { # let's build a fake document with an internal DTD
        # is this portable?
        my $tmpfile= "twig_tmp$$";
        open( TMP, ">$tmpfile") 
          or die "cannot create temp file $tmpfile: $!";
        print TMP "<!DOCTYPE $name [\n";   # print the doctype
        # slurp the DTD
          { open( DTD, "<$sysid") 
              or die "cannot open dtd file $sysid: $!";
            local undef $/;
            my $dtd= <DTD>;
            close DTD;
            print TMP $dtd;                 # add the dtd
          }
        print TMP "]>";                     # close the dtd
        print TMP "<dummy></dummy>\n";      # XML::Parser needs an element

        close TMP;
        
        my $t_dtd= new XML::Twig;           # create a temp twig
        $t_dtd->parsefile( $tmpfile);       # parse it
        $t->{twig_dtd}= $t_dtd->{twig_dtd}; # grab the dtd info
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
  }

# called only when the NoExpand option is set
sub twig_default
  { my( $p, $string)= @_;

    # process only if we have an entity
    return unless( $string=~ /\A&[^;]*;/);
    
    # the entity has to be in a pcdata, or we have a problem
    # the 1 is used by twig_char to avoid replacing the &
    twig_char( $p, $string, 1);
  }
    

# returns the declaration text (or a default one)
sub xmldecl
  { my $t= shift;
    my $decl= $t->{'twig_xmldecl'} or return '';
    my $string= "<?xml";
    $string .= " version=\"$decl->{version}\""       if( $decl->{version});
    $string .= " encoding=\"$decl->{encoding}\""     if( $decl->{encoding});
    $string .= " standalone=\"";  
    $string .= $decl->{standalone} ? "yes" : "no";  
    $string .= "\"";  
    $string .= "?>\n";
    return $string;
  }

# returns the doctype text (or none)
# that's the doctype just has it was in the original document
sub doctype
  { my $t= shift;
    my $doctype= $t->{'twig_doctype'} or return '';
    my $string= "<!DOCTYPE ".$doctype->{name};
    $string .= " SYSTEM \"$doctype->{sysid}\"" if( $doctype->{sysid});
    $string .= " PUBLIC  \"$doctype->{pub}\""  if( $doctype->{pub});
    $string .=  $doctype->{internal}.">\n";
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
    my $fh;
    if( ref $_[0] eq 'GLOB') { $fh=  shift };
    if( $fh) { print $fh $t->prolog( @_); }
    else     { print $t->prolog( @_);     }
  }

sub prolog
  { my $t= shift;
    my %args= @_;
    my $prolog='';

    my $update_dtd = $args{Update_DTD} || '';

    $prolog .= $t->xmldecl;
    return $prolog unless( defined $t->{'twig_doctype'});
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
        $prolog .= ' SYSTEM "' . $doctype->{sysid} . '"'  
                                                   if( $doctype->{sysid}); 
        $prolog .= " " . $doctype->{internal}      if( $doctype->{internal}); 
        $prolog .= ">\n"; 
      }
    return $prolog;
  }

sub print
  { my $t= shift;
    my $fh=  shift if( ref $_[0] eq 'GLOB');
    my %args= @_;

    if( $args{PrettyPrint})
      { $t->set_pretty_print( $args{PrettyPrint}); 
        delete $args{PrettyPrint};
      }

    if( $args{EmptyTags})
      { $t->set_empty_tag_style( $args{EmptyTags}); 
        delete $args{EmptyTags};
      }

    if( $fh)
      { $t->print_prolog( $fh, %args); }
    else
      { $t->print_prolog( %args); }

    $t->{twig_root}->print( $fh, %args) if( $t->{twig_root});
  }


sub flush
  { my $t= shift;
    my $fh=  shift if( ref $_[0] eq 'GLOB');
    my $up_to= shift if( ref $_[0]);
    my %args= @_;

    my $old_select;
    if( $fh)
      { my $old_select= select;
        select $fh;
      }

    if( $args{PrettyPrint})
      { $t->set_pretty_print( $args{PrettyPrint}); 
        delete $args{PrettyPrint};
      }

    if( $args{EmptyTags})
      { $t->set_empty_tag_style( $args{EmptyTags}); 
        delete $args{EmptyTags};
      }


    # the "real" last element processed, as twig_end has closed it
    my $last_elt;
    if( $up_to)
      { $last_elt= $up_to; }
    elsif( $t->{twig_current})
      { $last_elt= $t->{twig_current}->last_child; }
    else
      { $last_elt= $t->{twig_root}; }

    # flush the DTD unless it has ready flushed (id root has been flushed)
    my $elt= $t->{twig_root};
    $t->print_prolog( %args) unless( $elt->{'flushed'});

    while( $elt)
      { my $next_elt; 
        if( $last_elt && $last_elt->in( $elt))
          { 
            unless( $elt->{'flushed'}) 
              { # just output the front tag
                print $elt->start_tag();
                $elt->{'flushed'}=1;
              }
            $next_elt= $elt->{'first_child'};
          }
        else
          { # an element before the last one or the last one,
            $next_elt= $elt->{'next_sibling'};  
            $elt->flush();
            $elt->delete; 
            last if( $elt == $last_elt);
          }
        $elt= $next_elt;
      }
    select $old_select if( $old_select);
  }

# flushes up to an element
# this method just reorders the arguments and calls flush
sub flush_up_to
  { my $t= shift;
    my $up_to= shift;
    if( ref $_[0] eq 'GLOB')
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
    if( $args{PrettyPrint})
      { $t->set_pretty_print( $args{PrettyPrint}); 
        delete $args{PrettyPrint};
      }

    if( $args{EmptyTags})
      { $t->set_empty_tag_style( $args{EmptyTags}); 
        delete $args{EmptyTags};
      }
    my $prolog= $t->prolog( %args) || '';
    return  $prolog . $t->{twig_root}->sprint;
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
      { $last_elt= $t->{twig_current}->last_child; }
    else
      { $last_elt= $t->{twig_root}; }
    
    my $elt= $t->{twig_root};

    while( $elt)
      { my $next_elt; 
        if( $last_elt && $last_elt->in( $elt))
          { $elt->{'flushed'}=1;
            $next_elt= $elt->{'first_child'};
          }
        else
          { # an element before the last one or the last one,
            $next_elt= $elt->{'next_sibling'};  
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
    my $string= "<!DOCTYPE ".$doctype->{name}."[\n";
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
    my $fh=  shift if( ref $_[0] eq 'GLOB');
    if( $fh) { print $fh $t->dtd_text; }
    else     { print $t->dtd_text; }
  }

# those next methods are just calls to Expat methods
sub depth
  { my $t= shift;
    return $t->{twig_parser}->depth;
  }

sub in_element
  { my( $t, $name)= @_;
    return $t->{twig_parser}->in_element( $name);
  }

sub within_element
  { my( $t, $name)= @_;
    return $t->{twig_parser}->within_element( $name);
  }

sub context
  { my( $t)= @_;
    return $t->{twig_parser}->context;
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
    select $fh if( $fh);
    $t->flush;
    my $p=$t->{twig_parser};
    if( $t->{twig_keep_ents})
      { $p->setHandlers( %twig_handlers_finish_print); }
    else
      { $p->setHandlers( %twig_handlers_finish_print_original); }

  }

sub set_empty_tag_style
  { XML::Twig::Elt::set_empty_tag_style( @_); }

sub set_pretty_print
  { XML::Twig::Elt::set_pretty_print( @_); }

sub set_quote
  { XML::Twig::Elt::set_quote( @_); }

sub set_indent
  { XML::Twig::Elt::set_indent( @_); }

sub DESTROY
  { my $t= shift;
    $t->{twig_root}->delete if( $t->{twig_root});
    $t={}; # prevents memory leaks (especially when using mod_perl)
    undef $t;
  }        


#
#  non standard handlers
#

sub twig_print
  { my $p= shift;
    print $p->recognized_string();
  }

# account for the case where the element is empty
sub twig_print_end
  { my $p= shift;
    print $p->recognized_string() unless( $p->recognized_string()=~ /\/>\Z/); 
  }


sub twig_print_original
  { my $p= shift;
    print $p->original_string();
  }

# account for the case where the element is empty
sub twig_print_end_original
  { my $p= shift;
    print $p->original_string() unless( $p->original_string()=~ /\/>\Z/); 
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
    else
      { print $p->original_string(); }
  }

sub twig_end_check_roots
  { my( $p, $gi)= @_;
    twig_end( $p, $gi) if( $p->depth == 0);
  }

sub twig_end_check_roots_print
  { my( $p, $gi, %att)= @_;
    if( $p->depth == 0) { twig_end( $p, $gi); }
    print $p->recognized_string();  
  }

sub twig_end_check_roots_print_original
  { my( $p, $gi, %att)= @_;
    if( $p->depth == 0) { twig_end( $p, $gi); }
    print $p->original_string();
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
    my $old_select;
    if( $fh)
      { $old_select= select;
        select $fh;
      }
    foreach my $ent ( sort keys %{$ent_list})
      { $ent_list->{$ent}->print(); }
    select $old_select if( $old_select);
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


BEGIN
  {sub PCDATA { '#PCDATA' } 
   sub CDATA  { '#CDATA'  } 
   sub PI     { '#PI'}
  }

my $CDATA_START = "<![CDATA[";
my $CDATA_END   = "]]>";

# can be called as new XML::Twig::Elt( [[$gi, [@content]])
# - gi is an optional gi given to the element
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

    # the rest of the arguments are the content of the element
    $self->set_content( @_) if( @_);

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
    my $t= new XML::Twig(%args);
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

sub gi { return $XML::Twig::index2gi[$_[0]->{gi}]; }

sub is_pcdata
  { my $elt= shift;
    return (exists $elt->{'pcdata'});
  }

sub is_cdata
  { my $elt= shift;
    return (exists $elt->{'cdata'});
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
sub pcdata { return $_[0]->{pcdata}; }

sub set_cdata 
  { delete $_[0]->{empty} if( $_[0]->is_empty);
    return( $_[0]->{'cdata'}= $_[1]); 
  }
sub append_cdata
  { return( $_[0]->{'cdata'}.= $_[1]); 
  }
sub cdata { return $_[0]->{'cdata'}; }

sub root 
  { my $elt= shift;
    while( $elt->{'parent'}) { $elt= $elt->{'parent'}; }
    return $elt;
  }

sub twig 
  { my $elt= shift;
    my $root= $elt->root;
    return $root->{twig};
  }

sub set_parent { $_[0]->{'parent'}= $_[1]; }
sub parent
  { my $elt= shift;
    my $gi= shift || return $elt->{parent};
    until( $XML::Twig::index2gi[$elt->{'gi'}] eq $gi){ $elt= $elt->{'parent'} || return; }
    return $elt;
  }

sub set_first_child 
  { delete $_[0]->{empty} if( $_[0]->is_empty);
    $_[0]->{'first_child'}= $_[1]; 
  }

sub first_child
  { my $elt= shift;
    my $gi= shift || return $elt->{first_child};
    my $child= $elt->{'first_child'};
    while( $child)
      { return $child if( $XML::Twig::index2gi[$child->{'gi'}] eq $gi);
        $child= $child->{'next_sibling'};
      }
  }

# return the text of the first child or '' if there is no first
# child (to avoid getting the child, testing it then getting the text)
sub first_child_text
  { my $child= first_child( @_);
    return '' unless $child;
    return $child->text;
  }


sub set_last_child 
  { delete $_[0]->{empty} if( $_[0]->is_empty);
    $_[0]->{'last_child'}= $_[1]; 
  }

sub last_child 
  { my $elt= shift;
    my $gi= shift || return $elt->{last_child};
    my $child= $elt->{'last_child'};
    while( $child)
      { return $child if( $XML::Twig::index2gi[$child->{'gi'}] eq $gi);
        $child= $child->{'prev_sibling'};
      }
  }

# return the text of the last child or '' if there is no first
# child (to avoid getting the child, testing it then getting the text)
sub last_child_text
  { my $child= last_child( @_);
    return '' unless $child;
    return $child->text;
  }


sub set_prev_sibling { $_[0]->{'prev_sibling'}= $_[1]; }
sub prev_sibling
  { my $elt= shift;
    my $gi= shift || return $elt->{prev_sibling};
    my $sibling= $elt->{'prev_sibling'};
    while( $sibling)
      { return $sibling if( $XML::Twig::index2gi[$sibling->{'gi'}] eq $gi);
        $sibling= $sibling->{'prev_sibling'};
      }
  }

sub set_next_sibling { $_[0]->{'next_sibling'}= $_[1]; }
sub next_sibling
  { my $elt= shift;
    my $gi= shift || return $elt->{next_sibling};
    my $sibling= $elt->{'next_sibling'};
    while( $sibling)
      { return $sibling if( $XML::Twig::index2gi[$sibling->{'gi'}] eq $gi);
        $sibling= $sibling->{'next_sibling'};
      }
  }

# get or set all attributes
sub set_atts { $_[0]->{'att'}= $_[1]; }
sub atts { return $_[0]->{att}; }
sub del_atts { $_[0]->{att}={}; }

# get or set a single attributes
sub set_att { $_[0]->{att}->{$_[1]}= $_[2]; }
sub att { return $_[0]->{att}->{$_[1]}; }
sub del_att { delete $_[0]->{'att'}->{$_[1]}; }

sub set_twig_current { $_[0]->{twig_current}=1; }
sub del_twig_current { delete $_[0]->{twig_current}; }


# get or set the id attribute
sub set_id 
  { my( $elt, $id)= @_;
    $elt->set_att($ID, $_[1]); 
    my $t= $elt->twig || return;
    $elt->twig->{twig_id_list}->{$id}= $elt;
  }

sub id { return $_[0]->{'att'}->{$ID}; }

# delete the id attribute and remove the element from the id list
sub del_id 
  { my $elt= shift;
    my $id= $elt->{'att'}->{$ID} or return;
    my $t= $elt->twig && delete $elt->twig->{twig_id_list}->{$id};
    delete $elt->{'att'}->{$ID}; 
  }


sub children
  { my $elt= shift;
    my $gi= shift;
    my @children;
    my $child= $elt->{'first_child'};
    while( $child)
      { push @children, $child unless( $gi && $gi ne $XML::Twig::index2gi[$child->{'gi'}]); 
        $child= $child->{'next_sibling'};
      }
    return @children;
  }



sub ancestors
  { my( $elt, $gi)= @_;
    my @ancestors;
    while( $elt->{'parent'})
      { $elt= $elt->{'parent'};
        push @ancestors, $elt
          unless( $gi && ($XML::Twig::index2gi[$elt->{'gi'}] ne $gi));
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
      } while( $elt= $elt->{'parent'});
    return undef;
  }


# kinda counter-intuitive actually:
# the next element is found by looking for the next open tag after from the
# current one, which is the first child, if it exists, or the next sibling
# optional arguments are: 
#   - $subtree_root: a reference to an element, when the next element is not 
#                    within $subtree_root anymore then next_elt returns undef
#   - $gi: a gi, next_elt returns the next element of this gi
                 
sub next_elt
  { my $elt= shift;
    my $subtree_root= 0;
    $subtree_root= shift if( ref( $_[0]));
    my $gi= shift;
    # get next elt
    my $next_elt;
    if( $elt->{'first_child'})
      { $next_elt= $elt->{'first_child'}; }
    elsif( $elt->{'next_sibling'}) 
      { $next_elt= $elt->{'next_sibling'}; }
    else
      { # backtrack until we find a parent with a next sibling
        $next_elt= $elt->{'parent'} || return undef;
        until( $next_elt->{'next_sibling'})
          { $next_elt= $next_elt->{'parent'} || return undef; }
        return undef if( $subtree_root && ($subtree_root == $next_elt)); 
        $next_elt= $next_elt->{'next_sibling'};   
      }  
    # if no gi or right gi then return, else keep on looking
    if( !$gi || ($gi eq $XML::Twig::index2gi[$next_elt->{'gi'}]))
      { return $next_elt; }
    elsif( $subtree_root)
      { return $next_elt->next_elt( $subtree_root, $gi); }
    else
      { return $next_elt->next_elt( $gi); }
  }

# counter-intuitive too:
# the previous element is found by looking
# for the first open tag backwards from the current one
# it's the last descendant of the previous sibling 
# if it exists, otherwise it's simply the parent
sub prev_elt
  { my $elt= shift;
    my $gi= shift;
    # get prev elt
    my $prev_elt;
    if( $prev_elt= $elt->{'prev_sibling'})
      { while( $prev_elt->{'last_child'})
          { $prev_elt= $prev_elt->{'last_child'}; }
      }
    else
      { $prev_elt= $elt->{'parent'} || return; }

    # if no gi or right gi then return, else keep on looking
    if( !$gi || ($gi eq $XML::Twig::index2gi[$prev_elt->{'gi'}]))
      { return $prev_elt; }
    else
      { return $prev_elt->prev_elt( $gi) }
  }


# checks whether $elt is included in $ancestor, returns 1 in that case
sub in($$)
  { my ($elt, $ancestor)= @_;
    while( $elt= $elt->{'parent'}) { return 1 if( $elt ==  $ancestor); }
    return 0;           
  }

# returns the depth level of the element
# if 2 parameter are used then counts the 2cd element name in the
# ancestors list
sub level
  { my $elt= shift;
    my $level=0;
    my $name=shift || '';
    while( $elt= $elt->{'parent'}) { $level++ if( !$name || ($name eq $XML::Twig::index2gi[$elt->{'gi'}])); }
    return $level;           
  }

# checks whether $elt has an ancestor type $gi, returns the ancestor
sub in_context
  { my ($elt, $gi, $level)= @_;
    $level= -1 unless( $level) ;  # $level-- will never hit 0

    while( $level && $elt->{'parent'})
      { if( $XML::Twig::index2gi[$elt->{'gi'}] eq $gi) { return $elt; }
        $elt= $elt->{'parent'};
        $level--;
      }
    return ;           
  }

sub flushed { return $_[0]->{'flushed'}; }
sub set_flushed { $_[0]->{'flushed'}=1; }
sub del_flushed { delete $_[0]->{'flushed'}; }


sub cut
  { my $elt= shift;
    my( $parent, $prev_sibling, $next_sibling, $last_elt);

    # you can't cut the root, sorry
    unless( $parent= $elt->{'parent'}) 
      { return; }
    # and of course, you cannot cut the current element
    if( $elt->{twig_current})
      { croak "trying to cut an element before it has been completely parsed"; }

    $parent->{'first_child'}=  $elt->{'next_sibling'} 
      if( $parent->{'first_child'} == $elt);
    $parent->{'last_child'}=  $elt->{'prev_sibling'} 
      if( $parent->{'last_child'} == $elt);

    if( $prev_sibling= $elt->{'prev_sibling'})
      { $prev_sibling->{'next_sibling'}=  $elt->{'next_sibling'}; }
    if( $next_sibling= $elt->{'next_sibling'})
      { $next_sibling->{'prev_sibling'}=  $elt->{'prev_sibling'}; }


    $elt->{'parent'}=  undef;
    $elt->{'prev_sibling'}=  undef;
    $elt->{'next_sibling'}=  undef;

  }


sub erase
  { my $elt= shift;
    #you cannot erase the current element
    if( $elt->{twig_current})
      { croak "trying to erase an element before it has been completely parsed"; }
    my @children= $elt->children;
    if( @children)
      { # elt has children, move them up
        if( $elt->{'prev_sibling'})
          { # connect first child to previous sibling
            $elt->{'first_child'}->set_prev_sibling( $elt->{'prev_sibling'});      
            $elt->{'prev_sibling'}->set_next_sibling( $elt->{'first_child'}); 
          }
        else
          { # elt was the first child
            $elt->{'parent'}->set_first_child( $elt->{'first_child'});
          }
        if( $elt->{'next_sibling'})
          { # connect last child to next sibling
            $elt->{'last_child'}->set_next_sibling( $elt->{'next_sibling'});      
            $elt->{'next_sibling'}->set_prev_sibling( $elt->{'last_child'}); 
          }
        else
          { # elt was the last child
            $elt->{'parent'}->set_last_child( $elt->{'last_child'});
          }
        # update parent for all siblings
        foreach my $child (@children)
          { $child->{'parent'}=  $elt->{'parent'}; }
      }
    else
      { # elt had no child
        if( $elt->{'prev_sibling'})
          { # connect previous sibling to next sibling (can be undef)
            $elt->{'prev_sibling'}->set_next_sibling( $elt->{'next_sibling'});      
          }
        else
          { # elt was the first child
            $elt->{'parent'}->set_first_child( $elt->{'next_sibling'});
          }
        if( $elt->{'next_sibling'})
          { # connect next sibling to previous sibling (can be undef)
            $elt->{'next_sibling'}->set_prev_sibling( $elt->{'prev_sibling'}); 
          }
        else
          { # elt was the last child
            $elt->{'parent'}->set_last_child( $elt->{'next_sibling'});
          }
      }

    # elt is not referenced any more, so it will be DESTROYed
    # so we'd better break the links to its children
    undef $elt->{'first_child'};
    undef $elt->{'last_child'};

  }
        


# paste elt somewhere around ref
# pos can be first_child (default), last_child, before, after
sub paste
  { my $elt= shift;
    if( $elt->{'parent'}) 
      { croak "cannot paste an element that belongs to a tree"; }
    my $pos;
    my $ref;
    if( ref $_[0]) 
      { $pos= 'first_child'; $ref= shift; 
        croak "wrong argument order in paste, should be $_[0] first" if(@_); 
      }
    else
      { ($pos, $ref)= @_; }

    my( $parent, $prev_sibling, $next_sibling );

    if( $pos eq "before")
      { unless( $ref->{'parent'}) { croak "cannot paste before root"; }
        $parent= $ref->{'parent'};
        $prev_sibling= $ref->{'prev_sibling'};
        $next_sibling= $ref;

        $elt->{'parent'}=  $parent;
        $parent->{'first_child'}=  $elt if( $parent->{'first_child'} == $ref);

        $prev_sibling->{'next_sibling'}=  $elt if( $prev_sibling);
        $elt->{'prev_sibling'}=  $prev_sibling;

        $next_sibling->{'prev_sibling'}=  $elt;
        $elt->{'next_sibling'}=  $ref;
      }
    elsif( $pos eq "after")
      { unless( $ref->{'parent'}) { croak "cannot paste after root"; }
        $parent= $ref->{'parent'};
        $prev_sibling= $ref;
        $next_sibling= $ref->{'next_sibling'};

        $elt->{'parent'}=  $parent;
        $parent->{'last_child'}=  $elt if( $parent->{'last_child'}== $ref);

        $prev_sibling->{'next_sibling'}=  $elt;
        $elt->{'prev_sibling'}=  $prev_sibling;

        $next_sibling->{'prev_sibling'}=  $elt if( $next_sibling);
        $elt->{'next_sibling'}=  $next_sibling;

      }
    elsif( $pos eq "first_child")
      { $parent= $ref;
        $next_sibling= $ref->{'first_child'};
        delete $ref->{empty} if( $ref->is_empty);

        $elt->{'parent'}=  $parent;
        $parent->{'first_child'}=  $elt;
        $parent->{'last_child'}=  $elt unless( $parent->{'last_child'});

        $elt->{'prev_sibling'}=  undef;

        $next_sibling->{'prev_sibling'}=  $elt if( $next_sibling);
        $elt->{'next_sibling'}=  $next_sibling;

      }
    elsif( $pos eq "last_child")
      { $parent= $ref;
        $prev_sibling= $ref->{'last_child'};
        delete $ref->{empty} if( $ref->is_empty);

        $elt->{'parent'}=  $parent;
        $parent->{'last_child'}=  $elt;
        $parent->{'first_child'}=  $elt unless( $parent->{'first_child'});

        $elt->{'prev_sibling'}=  $prev_sibling;
        $prev_sibling->{'next_sibling'}=  $elt if( $prev_sibling);

        $elt->{'next_sibling'}=  undef;

      }
    else
      { croak "tried to paste in wrong position ($pos), allowed positions " . 
              " are 'first_child', 'last_child', 'before' and 'after'"; }
  }


# recursively copy an element and returns the copy (can be huge and long)
sub copy
  { my $elt= shift;
    my $copy= new XML::Twig::Elt( $XML::Twig::index2gi[$elt->{'gi'}]);
    if( my $atts= $elt->atts)
      { my %atts= %{$atts}; # we want to do a real copy of the attributes
        $copy->{'att'}=  \%atts;
      }

    if( (exists $elt->{'pcdata'}))
      { $copy->{'pcdata'}=  $elt->{'pcdata'};
        return $copy;
      }
    if( (exists $elt->{'cdata'}))
      { $copy->{'cdata'}=  $elt->{'cdata'};
        return $copy;
      }
    else
      { my @children= $elt->children;
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

    foreach( @{[$elt->children]}) { $_->DESTROY; }
    # destroy all references in the tree
    delete $elt->{'parent'};
    delete $elt->{'first_child'};
    delete $elt->{'last_child'};
    delete $elt->{'prev_sibling'};
    delete $elt->{'next_sibling'};
    # the id reference also needs to be destroyed
    $elt->del_id;
    delete $elt->{'att'};         # $elt->{'att'}=  undef;
    $elt= undef;
  }

BEGIN {
  my $pretty=0;
  my $quote='"';
  my $INDENT= '  ';
  my $empty_tag_style= 0;

  my ($NSGMLS, $NICE, $INDENTED, $RECORD1, $RECORD2)= (1..5);

  my %pretty_print_style=
    ( none     => 0,         # no added \n
      nsgmls   => $NSGMLS,   # nsgmls-style, \n in tags
      # below this line sty les are UNSAFE (the generated XML can be invalid)
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
      expand => $EXPAND,  # <tag></tag>
    );

  my %quote_style=
    ( double  => '"',    
      single  => "'", 
      smart  => "smart", 
    );

  sub set_pretty_print
    { my $style= lc( $_[1]);
      croak "illegal pretty print style $_[1]"
        unless( exists $pretty_print_style{$style});
      $pretty= $pretty_print_style{$style};
    }
      
  sub set_empty_tag_style
    { my $style= lc( $_[1]);
      croak "illegal empty tag style $_[1]"
        unless( exists $empty_tag_style{$style});
      $empty_tag_style= $empty_tag_style{$style};
    }
      
  sub set_quote
    { my $style= lc( $_[1]);
      croak "illegal quote style $_[1]"
        unless( exists $quote_style{$style});
      $quote= $quote_style{$style};
    }
      
  sub set_indent
    { my $INDENT= $_[1]; }
      
       
  # $elt is an element to print
  # $pretty is an optionnal value, if true a \n is printed after the <
  sub start_tag
    { my $elt= shift;
  
      return if( (exists $elt->{'pcdata'}));
      return $CDATA_START if( (exists $elt->{'cdata'}));
  
      my $tag="<" . $XML::Twig::index2gi[$elt->{'gi'}];
  
      # get the attribute and their values
      my $att= $elt->atts;
      if( $att)
        { foreach my $att_name (sort keys %{$att}) 
           { if( $pretty==$NSGMLS) { $tag .= "\n"; } 
             else                  { $tag .= ' ';  }
             $tag .= $att_name . '='
                          . $quote . $elt->{'att'}->{$att_name} . $quote; }
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
        { my $parent= $elt->{'parent'};
          unless( $parent && $parent->{contains_text}) 
            { $return= 1; }
          $elt->{contains_text}= 1 if( ($parent && $parent->{contains_text})
                                     || $elt->contains_text);
        }

      elsif( $pretty==$INDENTED)
        { my $parent= $elt->{'parent'};
          unless( $parent && $parent->{contains_text}) 
            { $return= 1; 
              $indent= $elt->level; 
            }
          $elt->{contains_text}= 1 if( ($parent && $parent->{contains_text})
                                     || $elt->contains_text);
        }

      $prefix= "\n" if( $return);
      $prefix.= $INDENT x $indent;
              
      return $prefix . $tag;

    }
  
  sub end_tag
    { my $elt= shift;
      return '' if( (exists $elt->{'pcdata'}) || ($elt->{'empty'} || 0));
      return $CDATA_END if( (exists $elt->{'cdata'}));
      my $gi= $XML::Twig::index2gi[$elt->{'gi'}];
      my $tag= "<";
      $tag.= "\n" if($pretty==$NSGMLS);
      $tag .=  "/$gi>";

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
        { my $parent= $elt->{'parent'};
          unless( ($parent && $parent->{contains_text}) || $elt->{contains_text})
            { $return= 1; }
        }

      elsif( $pretty==$INDENTED)
        { my $parent= $elt->{'parent'};
          unless( $parent && $parent->{contains_text} || $elt->{contains_text}) 
            { $return= 1; 
              $indent= $elt->level; 
            }
        }

      $prefix= "\n" if( $return);
      $prefix.= $INDENT x $indent;
              
      return $prefix . $tag;
    }

  sub pretty_print
    { my $elt= shift;
      my $pretty_style= shift || 0;
      $elt->set_pretty_print( $pretty_style) if( $pretty_style);
      $elt->print();
    }

  # $elt is an element to print
  # $fh is an optionnal filehandle to print to
  # $pretty is an optionnal value, if true a \n is printed after the < of the
  # opening tag
  sub print
    { my $elt= shift;
  
      my( $fh, $pretty);
      if( ref $_[0] eq 'GLOB') { $fh=  shift };
      $pretty= shift || 0;
  
      my $old_select;
      if( $fh)
        { $old_select= select;
          select $fh;
        }
  
  
      if( (exists $elt->{'pcdata'})) 
        { print $elt->{'pcdata'}; return; }
      if( (exists $elt->{'cdata'})) 
        { print $CDATA_START, $elt->{'cdata'}, $CDATA_END; return; }
  
      print $elt->start_tag();
  
      # print the children
      my $child= $elt->{'first_child'};
      while( $child)
        { $child->print();
          $child= $child->{'next_sibling'};
        }
      print $elt->end_tag;
      select $old_select if( $old_select);
    }
  
  
  # same as output but does not output the start tag if the element
  # is marked as flushed
  sub flush
    { my $elt= shift;
  
      my( $fh, $pretty);
      if( ref $_[0] eq 'GLOB') { $fh=  shift };
      $pretty= shift || 0;
  
      my $old_select;
      if( $fh)
        { $old_select= select;
          select $fh;
        }
      $pretty= shift || 0;
  
      if( (exists $elt->{'pcdata'})) 
        { print $elt->{'pcdata'}; return; }
      if( (exists $elt->{'cdata'})) 
        { print $CDATA_START, $elt->{'cdata'}, $CDATA_END; return; }
  
      print $elt->start_tag() unless( $elt->{'flushed'});
  
      # flush the children
      my @children= $elt->children;
      foreach my $child (@children)
        { $child->flush( $pretty); }
      print $elt->end_tag();
      select $old_select if( $old_select);
    }
  
  
  # same as print but except... it does not print but rather returns the string
  # if the second parameter is set then only the content is returned, not the
  # start and end tags of the element (but the tags of the included elements are
  # returned)
  sub sprint
    { my $elt= shift;
      my $no_tag= shift || 0;
  
      if( (exists $elt->{'pcdata'})) { return $elt->{'pcdata'}; }
      if( (exists $elt->{'cdata'}))  
        { return $CDATA_START . $elt->{'cdata'} . $CDATA_END; }
  
      my $string='';
  
      $string= $elt->start_tag unless( $no_tag);
  
      # sprint the children
      my $child= $elt->{'first_child'}||'';
      while( $child)
        { $string.= $child->sprint;
          $child= $child->{'next_sibling'};
        }
      $string .= $elt->end_tag unless( $no_tag);
      return $string;
    }
} # end of block containing $pretty_print and $quotes

  sub contains_text
  { my $elt= shift;
    my $child= $elt->{'first_child'};
    while ($child)
      { return 1 if( ((exists $child->{'pcdata'}) || (exists $child->{'cdata'}))); 
        $child= $child->{'next_sibling'};
      }
    return 0;
  }


# returns just the text, no tags, for an element
sub text
  { my $elt= shift;
    my $string;

    if( (exists $elt->{'pcdata'})) { return $elt->{'pcdata'}; }
    if( (exists $elt->{'cdata'}))  { return $elt->{'cdata'} ; }

    my $child= $elt->{'first_child'} ||'';
    while( $child)
      { $string.= defined($child->text) ? $child->text : '';
        $child= $child->{'next_sibling'};
      }
    return $string;
  }


# creates a single pcdata element containing the text as child of the element
sub set_text
  { my $elt= shift;
    my $string= shift;

    if( $XML::Twig::index2gi[$elt->{'gi'}] eq PCDATA) { return $elt->{'pcdata'}=  $string; }
    if( $XML::Twig::index2gi[$elt->{'gi'}] eq CDATA)  { $elt->set_gi( PCDATA);
                              $elt->{'cdata'}= '';
                              return $elt->{'pcdata'}=  $string;
                            }

    foreach my $child (@{[$elt->children]})
      { $child->cut; }

    my $pcdata= new XML::Twig::Elt( PCDATA, $string);
    $pcdata->paste( $elt);

    delete $elt->{empty} if( $elt->is_empty);

    return;
  }

# set the content of an element from a list of strings and elements
sub set_content
  { my $elt= shift;

    return unless $_[0];

    # attributes can be given as a hash (passed by ref)
    if( ref $_[0] eq 'HASH')
      { my $atts= shift;
        $elt->del_atts; # useless but better safe than sorry
        $elt->{'att'}=  $atts;
        return unless $_[0];

      }

    # check next argument for #EMPTY
    if( !(ref $_[0]) && ($_[0] eq '#EMPTY') ) 
      { $elt->{empty}= 1 unless( $elt->is_empty); return; }

    # case where we really want to do a set_text, the element is '#PCDATA'
    # and we only want to add text in it
    if( ($XML::Twig::index2gi[$elt->{'gi'}] eq PCDATA) && ($#_ == 0) && !( ref $_[0]))
      { $elt->{'pcdata'}=  $_[0];
        return;
      }
    elsif( ($XML::Twig::index2gi[$elt->{'gi'}] eq CDATA) && ($#_ == 0) && !( ref $_[0]))
      { $elt->{'cdata'}=  $_[0];
        return;
      }

    # delete the children
    # WARNING: potential problem here if the children are used
    # somewhere else (where?). Will be solved when I use weak refs
    foreach my $child (@{[$elt->children]})
      { $child->delete; }

    foreach my $child (@_)
      { if( ref $child)
          { $child->paste( 'last_child', $elt); }
        else
          { my $pcdata= new XML::Twig::Elt( PCDATA, $child);
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
  { my ($elt, @gi)= @_;
    foreach my $gi (@gi)
      { my $new_elt= new XML::Twig::Elt( $gi);
        foreach my $child (@{[$elt->children]})
          { $child->cut;
            $child->paste( 'last_child', $new_elt);
          }
        $new_elt->paste( $elt);
        $elt= $new_elt;
      }
    delete $elt->{empty} if( $elt->is_empty);
    return $elt;
  }

# wraps an element in elements which gi's are given as arguments
# $elt->wrap_in( 'td', 'tr', 'table') wraps the element as a single
# cell in a table for example
# returns the new element
sub wrap_in
  { my $elt= shift;
    foreach my $gi (@_)
      { my $new_elt = new XML::Twig::Elt( $gi);
        if( $elt->{twig_current})
          { my $t= $elt->twig;
            $t->{twig_current}= $new_elt;
            delete $elt->{'twig_current'};
            $new_elt->{'twig_current'}=1;
          }

        if( my $parent= $elt->{'parent'})
          { $new_elt->{'parent'}=  $parent; 
            $parent->{'first_child'}=  $new_elt if( $parent->{'first_child'} == $elt);
            $parent->{'last_child'}=  $new_elt  if( $parent->{'last_child'} == $elt);
          }
        if( my $prev_sibling= $elt->{'prev_sibling'})
          { $new_elt->{'prev_sibling'}=  $prev_sibling;
            $prev_sibling->{'next_sibling'}=  $new_elt;
          }
        if( my $next_sibling= $elt->{'next_sibling'})
          { $new_elt->{'next_sibling'}=  $next_sibling;
            $next_sibling->{'prev_sibling'}=  $new_elt;
          }
        $new_elt->{'first_child'}=  $elt;
        $new_elt->{'last_child'}=  $elt;

        $elt->{'parent'}=  $new_elt;
        $elt->{'prev_sibling'}=  undef;
        $elt->{'next_sibling'}=  undef;

        $elt= $new_elt;
      }
    return $elt;
  }

sub replace
  { my( $elt, $ref)= @_;
    if( my $parent= $ref->{'parent'})
      { $elt->{'parent'}=  $parent;
        $parent->{'first_child'}=  $elt if( $parent->{'first_child'} == $ref);
        $parent->{'last_child'}=  $elt  if( $parent->{'last_child'} == $ref);
      }
    if( my $prev_sibling= $ref->{'prev_sibling'})
      { $elt->{'prev_sibling'}=  $prev_sibling;
        $prev_sibling->{'next_sibling'}=  $elt;
      }
    if( my $next_sibling= $ref->{'next_sibling'})
      { $elt->{'next_sibling'}=  $next_sibling;
        $next_sibling->{'prev_sibling'}=  $elt;
      }
   
    $ref->{'parent'}=  undef;
    $ref->{'prev_sibling'}=  undef;
    $ref->{'next_sibling'}=  undef;
    return $ref;
  }


# move an element, same syntax as paste, except the element is first cut
sub move
  { my $elt= shift;
    $elt->cut;
    $elt->paste( @_);
  }
    

# adds a prefix to an element, creating a pcdata child if needed
sub prefix
  { my ($elt, $prefix)= @_;
    if( (exists $elt->{'pcdata'}))
      { $elt->{'pcdata'}=  $prefix . $elt->{'pcdata'}; }
    elsif( $elt->{'first_child'} && $elt->{'first_child'}->is_pcdata)
      { $elt->{'first_child'}->set_pcdata( $prefix . $elt->{'first_child'}->pcdata); }
    else
      { my $new_elt= new XML::Twig::Elt( PCDATA, $prefix);
        $new_elt->paste( $elt);
      }
  }


# adds a suffix to an element, creating a pcdata child if needed
sub suffix
  { my ($elt, $suffix)= @_;
    if( (exists $elt->{'pcdata'}))
      { $elt->{'pcdata'}=  $elt->{'pcdata'} . $suffix; }
    elsif( $elt->{'last_child'} && $elt->{'last_child'}->is_pcdata)
      { $elt->{'last_child'}->set_pcdata( $elt->{'first_child'}->pcdata . $suffix); }
    else
      { my $new_elt= new XML::Twig::Elt( PCDATA, $suffix);
        $new_elt->paste( 'last_child', $elt);
      }
  }

# create a path to an element ('/root/.../gi)
sub path
  { my $elt= shift;
    my @context= ( $elt, $elt->ancestors);
    return "/" . join( "/", reverse map {$XML::Twig::index2gi[$_->{'gi'}]} @context);
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
      { $a_prev= $a_prev->{'prev_sibling'} || return( -1);
        return 1 if( $a_prev == $b_next);
        $a_next= $a_next->{'next_sibling'} || return( 1);
        return -1 if( $a_next == $b_prev);
        $b_prev= $b_prev->{'prev_sibling'} || return( 1);
        return -1 if( $b_prev == $a_next);
        $b_next= $b_next->{'next_sibling'} || return( -1);
        return 1 if( $b_next == $a_prev);
      }
  }
    

__END__

=head1 NAME

XML::Twig - A perl module for processing huge XML documents in tree mode.

=head1 SYNOPSIS

    single-tree mode    
        my $t= new XML::Twig();
        $t->parse( '<doc><para>para1</para></doc>');
        $t->print;

    chunk mode 
        my $t= new XML::Twig( TwigHandlers => { section => \&flush});
        $t->parsefile( 'doc.xml');
        $t->flush;
        sub flush { $_[0]->flush; }

        my $t= new XML::Twig( TwigHandlers => 
	                        { 'section/title' => \&print_elt_text} );
        $t->parsefile( 'doc.xml');
        sub print_elt_text 
          { my( $t, $elt)= @_;
            print $elt->text; 
          }

        my $t= new XML::Twig( TwigHandlers => 
	                        { 'section[@level="1"]' => \&print_elt_text }
			    );
        $t->parsefile( 'doc.xml');

    roots mode (builds only the required sub-trees)
        my $t= new XML::Twig( 
                 TwigRoots    => { 'section/title' => \&print_elt_text}
                            );
        $t->parsefile( 'doc.xml');
        sub print_elt_text 
          { my( $t, $elt)= @_;
            print $elt->text; 
          }

=head1 DESCRIPTION

This module provides a way to process XML documents. It is build on top
of XML::Parser.

The module offers a tree interface to the document, while allowing you
to output the parts of it that have been completely processed.

It allows minimal resource (CPU and memory) usage by building the tree
only for the parts of the documents that need actual processing, through the 
use of the TwigRoots and TwigPrintOutsideRoots options. The finish and 
finish_print methods also help to increase performances.

XML::Twig tries to make simple things easy so it tries its best to takes care 
of a lot of the (usually) annoying (but sometimes necessary) features that 
come with XML and XML::Parser.

=over 4

=item Whitespaces

Whitespaces that look non-significant are discarded, this behaviour can be 
controlled using the KeepSpaces, KeepSpacesIn and DiscardSpacesIn options.

=item Encoding

You can specify that you want the output in the same encoding as the input
(provided you have valid XML, which means you have to specify the encoding
either in the document or when you create the Twig object) using the KeepEncoding
option

=back

=head1 METHODS

=head2 Twig 

A twig is a subclass of XML::Parser, so all XML::Parser methods can be
called on a twig object, including parse and parsefile.
setHandlers on the other hand cannot not be used, see C<L</BUGS>>


=over 4

=item new 

This is a class method, the constructor for XML::Twig. Options are passed
as keyword value pairs. Recognized options are the same as XML::Parser,
plus some XML::Twig specifics:

=over 4

=item TwigHandlers

This argument replaces the corresponding XML::Parser argument. It consists
of a hash { expression => \&handler} where expression is a I<string_condition>,
an I<attribute_condition>,I<full_path>, a I<partial_path>, a I<gi>,
I<_default_> or <_all_>.

The idea is to support a usefull but efficient (thus limited) subset of
XPATH. A fuller expression set will be supported in the future, as users
ask for more and as I manage to implement it efficiently. This will never
encompass all of XPATH due to the streaming nature of parsing (no lookhead
after the element end tag).

A B<string_condition> is a condition on the content of an element, in the form
I<gi[string()="foo"]>, simple quotes can be used instead of double quotes, at 
the moment you cannot escape the quotes (this will be added as soon as I
dig out my copy of Mastering Regular Expressions from its storage box).
The text returned is, as per what I (and Matt Sergeant!) understood from
the XPATH spec the concatenation of all the text in the element, excluding
all markup. Thus to call a handler on the element <p>text <b>bold</b></p>
the appropriate condition is p[string()="text bold"]. Note that this is not
exactly conformant to the XPath spec, it just tries to mimic it while being
still quite concise.

An B<attribute_condition> is a simple condition of an attribute of the
current element in the form I<gi[@att="val"]> (simple quotes can be used
instead of double quotes, you can escape quotes either). 
If several attribute_condition are true the same element all the handlers
can be called in turn (in the order in which they were first defined).

A B<full_path> looks like I<'/doc/section/chapter/title'>, it starts with
a / then gives all the gi's to the element. The handler will be called if
the path to the current element (in the input document) is exactly as
defined by the full_path.

A B<partial_path> is like a full_path except it does not start with a /:
I<'chapter/title'> for example. The handler will be called if the path to
the element (in the input document) ends as defined in the partial_path.

B<WARNING>: (hopefully temporary) at the moment I<string_condition> and
I<attribute_condition> are only supported on a simple gi, not on a path.

A B<gi> (generic identifier) is just a tag name.

A special gi B<_all_> is used to call a function for each element.
The special gi B<_default_> is used to call a handler for each element
that does NOT have a specific handler.

The order of precedence to trigger a handler is: I<string_condition>,
I<attribute_condition>, I<full_path>, longer I<partial_path>,shorter 
I<partial_path>, I<gi>, I<_default_> . 

Once a handler has been triggered if it returns 0 then no other handler 
is called, exept a _all_ handler which will be called anyway.

If a handler returns a true value and other handlers apply, then the next
applicable handler will be called. Repeat, rince, lather..;

When an element is CLOSED the corresponding handler is called, with 2
arguments: the twig and the C<L</Element>>. The twig includes the document
tree that has been built so far, the element is the complete sub-tree for
the element.

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

=item TwigRoots

This argument let's you build the tree only for those elements you are interested
in. 

  Example: my $t= new XML::Twig( TwigRoots => { title => 1, subtitle => 1});
           $t->parsefile( file);
           my $t= new XML::Twig( TwigRoots => { 'section/title' => 1});
           $t->parsefile( file);


returns a twig containing a document including only title and subtitle elements,
as children of the root element.

You can use I<attribute_condition>, I<full_path>, <partial_path>, <gi>,
I<_default_> and <_all_> to trigger the building of the twig. 
I<string_condition> cannot be used as the content of the element, and the 
string, have not yet been parsed when the condition is checked.

B<WARNING>: path are checked for the document. Even if the TwigRoots option is used
they will be checked against the full document tree, not the virtual tree created
by XML::Twig


B<WARNING>: TwigRoots elements should NOT be nested, that would hopelessly confuse
XML::Twig ;--(

Note: you can set handlers (TwigHandlers) using TwigRoots
  Example: my $t= new XML::Twig( TwigRoots => { title    => sub { $_{1]->print;}, 
                                                subtitle => \&process_subtitle });
           $t->parsefile( file);
 

=item TwigPrintOutsideRoots

To be used in conjunction with the TwigRoots argument. When set to a true value this 
will print the document outside of the TwigRoots elements.

 Example: my $t= new XML::Twig( TwigRoots => { title => \&number_title },
                                TwigPrintOutsideRoots => 1,
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
               

This example prints the document outside of the title element, calls number_title for
each title element, prints it, and then resumes printing the document. The twig is built
only for the title elements. 



=item LoadDTD

If this argument is set to a true value, parse or parsefile on the twig will load  
the DTD information. This information can then be accessed through the twig, 
in a DTDHandler for example. This will load even an external DTD.

See L<DTD Handling> for more information

=item DTDHandler

Sets a handler that will be called once the doctype (and the DTD) have been loaded,
with 2 arguments, the twig and the DTD.

=item StartTagHandlers

A hash { expression => \&handler}. Sets element handlers that are called when the element 
is open (at the end of the XML::Parser Start handler). The handlers are called with
2 params: the twig and the element. The element is empty at that point, its 
attributes are created though. 

You can use I<attribute_condition>, I<full_path>, I<partial_path>
, <gi>, I<_default_>  and I<_all_> to trigger the handler. 
I<string_condition> cannot be used as the content of the element, and the 
string, have not yet been parsed when the condition is checked.

B<WARNING>: StartTag handlers are B<NOT> called outside ot TwigRoots if this 
argument is used.


The main use for those handlers is probably to create temporary attributes 
that will be used when processing sub-element with TwigHanlders. 

You should also use it to change tags if you use flush. If you change the tag in a
regular TwigHandler then the start tag might already have been flushed. 

By the way there is no EndTagHandlers option as this would be exactly the same as
the TwigHandlers option.

=item CharHandler

A reference to a subroutine that will be called every time PCDATA is found.

=item KeepEncoding

This is a (slightly?) evil option: if the XML document is not UTF-8 encoded and
you want to keep it that way, then setting KeepEncoding will use the Expat
original_string method for character, thus keeping the original encoding, as 
well as the original entities in the strings.

B<WARNING>: if the original encoding is multi-byte then attribute parsing will
be EXTREMELY unsafe under any Perl before 5.6, as it uses regular expressions
which do not deal properly with multi-byte characters.

B<WARNING>: this option is NOT used when parsing with the non-blocking parser 
(parse_start, parse_more, parse_done methods).

=item Id

This optional argument gives the name of an attribute that can be used as
an ID in the document. Elements whose ID is known can be accessed through
the elt_id method. Id defaults to 'id'.
See C<L</BUGS>>

=item DiscardSpaces

If this optional argument is set to a true value then spaces are discarded
when they look non-significant: strings containing only spaces are discarded.
This argument is set to true by default.

=item KeepSpaces

If this optional argument is set to a true value then all spaces in the
document are kept, and stored as PCDATA.
KeepSpaces and DiscardSpaces cannot be both set.

=item DiscardSpacesIn

This argument sets KeepSpaces to true but will cause the twig builder to
discard spaces in the elements listed.
The syntax for using this argument is: 
  new XML::Twig( DiscardSpacesIn => [ 'elt1', 'elt2']);

=item KeepSpacesIn

This argument sets DiscardSpaces to true but will cause the twig builder to
keep spaces in the elements listed.
The syntax for using this argument is: 
  new XML::Twig( KeepSpacesIn => [ 'elt1', 'elt2']);

=item PrettyPrint

Sets the pretty print method, amongst 'none' (default), 'nsgmls', 'nice', 
'indented', 'record' and rec'record'ord_c

=item EmptyTags

Sets the empty tag display style (normal, html or expand).


=back

=item parse(SOURCE [, OPT => OPT_VALUE [...]])

This method is inherited from XML::Parser.
The SOURCE parameter should either be a string containing the whole XML
document, or it should be an open IO::Handle. Constructor options to
XML::Parser::Expat given as keyword-value pairs may follow the SOURCE
parameter. These override, for this call, any options or attributes passed
through from the XML::Parser instance.

A die call is thrown if a parse error occurs. Otherwise it will return 1
the twig built by the parse.

=item parsestring

This is just an alias for parse for backwards compatibility.

=item parsefile(FILE [, OPT => OPT_VALUE [...]])

This method is inherited from XML::Parser.
Open FILE for reading, then call parse with the open handle. The file
is closed no matter how parse returns. Returns what parse returns.

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
one in the StartTagHandlers option of new. All previous handlers are unset.
The method returns the reference to the previous handlers.

=item setStartTagHandler ($gi $handler)

Set a single StartTag handlers for the $gi element. $handler is a reference to 
a subroutine. If the handler was previously set then the reference to the
previous handler is returned.


=item setTwigHandlers ($handlers)

Set the Twig handlers. $handlers is a reference to a hash similar to the
one in the TwigHandlers option of new.


=item dtd

Returns the dtd (an XML::Twig::DTD object) of a twig

=item root

Returns the root element of a twig

=item elt_id        ($id)

Returns the element whose id attribute is $id

=item entity_list

Returns the entity list of a twig

=item change_gi      ($old_gi, $new_gi)

Performs a (very fast) global change. All elements old_gi are now new_gi.
See C<L</BUGS>>

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

Purges up to the $elt element. This allows you to keep part of the
tree in memory when you flush.

=item print            ($optional_filehandle, %options)

Prints the whole document associated with the twig. To be used only AFTER the
parse.
 
options: see flush.

=item sprint            

Returns the text of the whole document associated with the twig. To be used only
AFTER the parse.

options: see flush.

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

Stop twig processing, flush the twig and proceed to finish printing the document as
fast as possible. Use this method when modifying a document and the modification is 
done. 

=item depth

Calls Expat's depth method , which returns the depth in the tree during the parsing. 
This is usefull when using the TwigRoots option to still get info on the actual document.

=item in_element ($gi)

Call Expat in_element method.
Returns true if $gi is equal to the name of the innermost currently opened
element. If namespace processing is being used and you want to check
against a name that may be in a namespace, then use the generate_ns_name
method to create the $gi argument. Usefull when using the TwigRoots option.

=item within_element($gi)

Call Expat within_element method.
Returns the number of times the given name appears in the context list.
If namespace processing is being used and you want to check
against a name that may be in a namespace, then use the generate_ns_name
method to create the $gi argument. Usefull when using the TwigRoots option.

=item context

Returns a list of element names that represent open elements, with the last
one being the innermost. Inside start and end tag handlers, this will be the
tag of the parent element.

=item path($gi)

Returns the element context in a form similar to XPath's short
form: '/root/gi1/../gi'


=back 

=head2 Elt

=over 4

=item new          ($optional_gi, $optional_atts, @optional_content)

The gi is optional (but then you can't have a content ), the optional atts
is the ref of a hash of attributes, the content can be just a string or a 
list of strings and element. A content of '#EMPTY' creates an empty element;

 Examples: my $elt= new XML::Twig::Elt();
           my $elt= new XML::Twig::Elt( 'para', { align => 'center' });  
	   my $elt= new XML::Twig::Elt( 'br', '#EMPTY');
	   my $elt= new XML::Twig::Elt( 'para');
           my $elt= new XML::Twig::Elt( 'para', 'this is a para');  
           my $elt= new XML::Twig::Elt( 'para', $elt3, 'another para'); 

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

=item set_gi         ($gi)

Sets the gi of an element

=item gi                       

Returns the gi of the element

=item closed                   

Returns true if the element has been closed. Might be usefull if you are
somewhere in the tree, during the parse, and have no idea whether a parent
element is completely loaded or not.

=item is_pcdata

Returns 1 if the element is a #PCDATA element, returns 0 otherwise.

=item pcdata

Returns the text of a PCDATA element or undef if the element is not PCDATA.

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

=item is_empty

Returns 1 if the element is empty, 0 otherwise

=item set_empty

Flags the element as empty. No further check is made, so if the element
is actually not empty the output will be messed. The only effect of this 
method is that the output will be <gi att="value""/>.

=item set_not_empty

Flags the element as not empty. if it is actually empty then the element will
be output as <gi att="value""></gi>

=item root 

Returns the root of the twig in which the element is contained.

=item twig 

Returns the twig containing the element. 

=item parent        ($optional_gi)

Returns the parent of the element, or the first ancestor whose gi is $gi.

=item first_child   ($optional_gi)

Returns the first child of the element, or the first child whose gi is $gi.
(ie the first of the element children whose gi matches).

=item first_child_text   ($optional_gi)

Returns the text of the first child of the element, or the first child
whose gi is $gi.(ie the first of the element children whose gi matches).
If there is no first_child then returns ''. This avoids getting the
child, checking for its existence then getting the text for trivial cases.

=item last_child    ($optional_gi)

Returns the last child of the element, or the last child whose gi is $gi. 
(ie the last of the element children whose gi matches).

=item last_child_text   ($optional_gi)

Same as first_child_text but for the last child.

=item prev_sibling  ($optional_gi)

Returns the previous sibling of the element, or the first one whose gi is $gi. 

=item next_sibling  ($optional_gi)

Returns the next sibling of the element, or the first one whose gi is $gi. 

=item atts

Returns a hash ref containing the element attributes

=item set_atts      ({att1=>$att1_val, att2=> $att2_val... })

Sets the element attributes with the hash ref supplied as the argument

=item del_atts

Deletes all the element attributes.

=item set_att      ($att, $att_value)

Sets the attribute of the element to the given value

=item att          ($att)

Returns the attribute value

=item del_att      ($att)

Delete the attribute for the element

=item inherit_att  ($att, @optional_gi_list)

Returns the value of an attribute inherited from parent tags. The value
returned is found by looking for the attribute in the element then in turn
in each of its ancestors. If the @optional_gi_list is supplied only those
ancestors whose gi is in the list will be checked. 

=item set_id       ($id)

Sets the id attribute of the element to the value.
See C<L</elt_id>> to change the id attribute name

=item id

Gets the id attribute value

=item del_id       ($id)

Deletes the id attribute of the element and remove it from the id list
for the document

=item children     ($optional_gi)

Returns the list of children (optionally whose gi is $gi) of the element

=item ancestors    ($optional_gi)

Returns the list of ancestors (optionally whose gi is $gi) of the element.
The list is ordered from the innermost ancestor to the outtermost one

NOTE: the element itself is not part of the list, in order to include it 
you will have to write:

  my @array= ($elt, $elt->ancestors)

=item next_elt     ($optional_elt, $optional_gi)

Returns the next elt (optionally whose gi is $gi) of the element. This is 
defined as the next element which opens after the current element opens.
Which usually means the first child of the element.
Counter-intuitive as it might look this allows you to loop through the
whole document by starting from the root.

The $optional_elt is the root of a subtree. When the next_elt is out of the
subtree then the method returns undef. You can then walk a sub tree with:

  my $elt= $subtree_root;
  while( $elt= $elt->next_elt( $subtree_root);
    { # insert processing code here
      $elt= $elt->next_elt( $subtree_root);
    }

=item prev_elt     ($optional_gi)

Returns the previous elt (optionally whose gi is $gi) of the
element. This is the first element which opens before the current one.
It is usually either the last descendant of the previous sibling or
simply the parent

=item level       ($optional_gi)

Returns the depth of the element in the twig (root is 0).
If the optional gi is given then only ancestors of the given type are counted.
 
B<WARNING>: in a tree created using the TwigRoots option this will not return the
level in the document tree, level 0 will be the document root, level 1 will be 
the TwigRoots elements. During the parsing (in a TwigHandler)
you can use the depth method on the twig object to get the real parsing depth.

=item in           ($potential_parent)

Returns true if the element is in the potential_parent

=item in_context   ($gi, $optional_level)

Returns true if the element is included in an element whose gi is $gi,
optionally within $optional_level levels. The returned value is the including
element.


=item cut

Cuts the element from the tree.

=item copy        ($elt)

Returns a copy of the element. The copy is a "deep" copy: all sub elements of 
the element are duplicated.

=item paste       ($optional_position, $ref)

Pastes a (previously cut) element.
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

=back

=item move       ($optional_position, $ref)

Move an element in the tree.
This is just a cut then a paste.  The syntax is the same as paste.

=item replace       ($ref)

Replaces an element in the tree. Sometimes it is just not possible to cut
an element then paste another in its place, so replace comes in handy.

=item prefix       ($text)

Add a prefix to an element. If the element is a PCDATA element the text
is added to the pcdata, if the elements first_child is a PCDATA then the
text is added to it's pcdata, otherwise a new PCDATA element is created 
and pasted as the first child of the element.

=item suffix       ($text)

Add a suffix to an element. If the element is a PCDATA element the text
is added to the pcdata, if the elements last_child is a PCDATA then the
text is added to it's pcdata, otherwise a new PCDATA element is created 
and pasted as the last child of the element.

=item erase

Erases the element: the element is deleted and all of its children are
pasted in its place.

=item delete

Cut the element and frees the memory.

=item DESTROY

Frees the element from memory.

=item start_tag

Returns the string for the start tag for the element, including 
the /> at the end of an empty element tag

=item end_tag

Returns the string for the end tag of an element.  For an empty
element, this returns the empty string ('').

=item print         ($optional_filehandle, $pretty_print_style)

Prints an entire element, including the tags, optionally to a $optional_filehandle,
optionally with a $pretty_print_style.
 
=item sprint       ($elt, $optional_no_enclosing_tag)

Returns the string for an entire element, including the tags. To be used 
with caution!
If the optional second argument is true then only the string inside the 
element is returned (the start and end tag for $elt are not).

=item set_pretty_print ($style)

Sets the pretty print method, amongst 'none' (default), 'nsgmls', 'nice', 
'indented', 'record' and rec'record'ord_c

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

=item text

Returns a string consisting of all the PCDATA and CDATA in an element, 
without any tags.

=item set_text        ($string)

Sets the text for the element: if the element is a PCDATA, just set its
text, otherwise cut all the children of the element and create a single
PCDATA child for it, which holds the text.

=item set_content    ( $optional_atts, @list_of_elt_and_strings)
                     ( $optional_atts, '#EMPTY')

Sets the content for the element, from a list of strings and
elements.  Cuts all the element children, then pastes the list
elements as the children.  This method will create a PCDATA element
for any strings in the list.

The optional_atts argumentis the ref of a hash of attributes. If this
argument is used then the previous attrubutes are deleted, otherwise they
are left untouched. 

B<WARNING>: if you rely on ID's then you will have to set the id yourself. At
this point the element does not belong to a twig yet, so the ID attribute
is not known so it won't be strored in the ID list.

A content of '#EMPTY' creates an empty element;

=item insert         (@gi)

For each gi in the list inserts an element $gi as the only child of the 
element.  All children of the element are set as children of the new element.
The upper level element is returned.

$p->insert( 'table', 'tr', 'td') puts $p in a table with a single tr and a
single td and returns the table element.

=item wrap_in        (@gi)

Wraps elements $gi as the successive ancestors of the element, returns the 
new element.
$elt->wrap_in( 'td', 'tr', 'table') wraps the element as a single cell in a 
table for example.

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
Additional examples can be found at 
http://www.xmltwig.cx/

To figure out what flush does call the following script with an
 xml file and an element name as arguments

  use XML::Twig;

  my ($file, $elt)= @ARGV;
  my $t= new XML::Twig( TwigHandlers => 
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

If you use the LoadDTD option when creating the twig the DTD information and
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

If you use the LoadDTD when creating the twig the DTD information and the entity 
declarations can be accessed. The entity declarations will be flush'ed (or 
print'ed) either as is (if they have not been modified) or as reconstructed (badly,
comments are lost, order is not kept).

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
  $CDATA_START = "<![CDATA[";
  $CDATA_END   = "]]>";

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

=item multiple twigs are not well supported

A number of twig features are just global at the moment. These include
the ID list and the "gi pool" (if you use change_gi then you change the gi 
for ALL twigs).

The next version will try to support this while trying not to be to
hard on performance (at least when a single twig is used!).


=item XML::Parser-like handlers

Sometimes it would be nice to be able to use both XML::Twig handlers and
XML::Parser handlers, for example to perform generic tasks on all open
tags, like adding an ID, or taking care of the autonumbering.

Next version...


=back


=head1 BENCHMARKS

You can use the C<benchmark_twig> file to do additional benchmarks.
Please send me benchmark information for additional systems.

=head1 AUTHOR

Michel Rodriguez <m.v.rodriguez@ieee.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Bug reports and comments to m.v.rodriguez@ieee.org.
The XML::Twig page is at http://www.xmltwig.cx/

=head1 SEE ALSO

XML::Parser


=cut


