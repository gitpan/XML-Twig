# XML::Twig  %W% - %E%
#
# Copyright (c) 1999 Michel Rodriguez
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

# This is created in the caller's space
BEGIN
  { sub ::PCDATA { '#PCDATA' } }

######################################################################
package XML::Twig;
######################################################################

require 5.004;

use strict; 
use vars qw($VERSION @ISA);
use Carp;


sub PCDATA { '#PCDATA' }

BEGIN
{
    require XML::Parser;
    $VERSION = '1.7';

    my $needVersion = '2.21';
    croak "need at least XML::Parser version $needVersion"
	unless $XML::Parser::VERSION >= $needVersion;
    import XML::Twig::Elt;
    import XML::Twig::Entity;
    import XML::Twig::Entity_list;
}

@ISA = ("XML::Parser");

my %twig_handlers=( Start   => \&twig_start, 
                    End     => \&twig_end, 
                    Char    => \&twig_char, 
                    Entity  => \&twig_entity, 
                    XMLDecl => \&twig_xmldecl, 
                    Doctype => \&twig_doctype, 
                    Element => \&twig_element, 
                    Attlist => \&twig_attlist, 
                  );

# those handlers are only used if DTD info is needed
#my %twig_dtd_handlers= ( Element => \&twig_element, 
#                         Attlist => \&twig_attlist, 
#                       );

# those handlers are only used if the entities are NOT to be expanded
my %twig_noexpand_handlers= ( Default => \&twig_default, 
                            );

my $ID= 'id'; # default value, set by the Id argument

# used to store the gi's
# should be set for each twig really, at least when tere are several
my %gi2index; # gi => index
my @index2gi; # list of gi's

my $XML_DECL= '<?xml version="1.0" ?>';

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

    if( exists $args{TwigHandlers})
      { $handlers= $args{TwigHandlers};
        delete $args{TwigHandlers};
      }

   if( exists $args{Id})
      { $ID= $args{Id};
        delete $args{ID};
      }
    
    my $self= new XML::Parser(%args, 'Handlers' => \%twig_handlers);
    $self->{twig_handlers}= $handlers;

     if( exists $args{NoExpand})
      { $self->setHandlers( %twig_noexpand_handlers);
      }

    # take care of twig-specific arguments
    $self->{twig_starttag_handlers}= $args{StartTagHandlers} || {};
    delete $args{StartTagHandlers};
    $self->{twig_dtd_handler}= $args{DTDHandler};
    delete $args{DTDHandler};
    $self->{twig_char_handler}= $args{CharHandler};
    delete $args{CharHandler};
    $self->{twig_read_external_dtd}= $args{LoadDTD};
    delete $args{LoadDTD};
    $self->{twig}= $self;

    
    $self->{twig_entity_list}= new XML::Twig::Entity_list; 

    $self->{twig_id}= $ID; 

    bless $self, $class;
    return $self;

  }

# the default twig handlers, which build the tree
sub twig_start($$%)
  { my ($p, $gi, %att)  = @_;
    my $t=$p->{twig};
    my $parent= $t->{twig_current};
    my $elt= new XML::Twig::Elt();
 
    delete $parent->{twig_current} if( $parent);
    $t->{twig_current}= $elt;
    $elt->{twig_current}=1;

    $elt->set_gi( $gi);
    $elt->set_atts( \%att);

    if( $parent)
      { my $prev_sibling= $parent->last_child;
        if( $prev_sibling) 
          { $prev_sibling->set_next_sibling( $elt); 
            $elt->set_prev_sibling( $prev_sibling);
          }

        $elt->{parent}= $parent;
        $parent->set_first_child( $elt) unless( $parent->first_child); 
        $parent->set_last_child( $elt);
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
    my $id= $elt->id;
    if( $id) { $t->{twig_id_list}->{$id}= $elt; }


    # empty the stored pcdata (space stored in case
    # they are really part of a pcdata element)
    $t->{twig_stored_pcdata}='';

    # call user handler if need be
    if( defined $t->{twig_starttag_handlers}->{$gi})
      { $t->{twig_starttag_handlers}->{$gi}->($t, $elt); }
  }


sub twig_end($$%)
  { my ($p, $gi)  = @_;
    my $t=$p->{twig};
        
    # build the tree
    delete $t->{twig_current}->{twig_current} if( $t->{twig_current});
    my $elt= $t->{twig_current};
    $elt->{twig_current}=1;

    $t->{twig_current}= $t->{twig_current}->parent;

    # empty the stored pcdata (spaces stored in case
    # they are really part of a pcdata element)
    $t->{twig_stored_pcdata}='';

    # call user handler if need be
    if( defined $t->{twig_handlers}->{$gi})
      { $t->{twig_handlers}->{$gi}->($t, $elt); }

  }

sub twig_char($$$)
  { my ($p, $string, $called_from_default)= @_;
    my $t=$p->{twig};

    if( $t->{twig_char_handler})
      { $string= $t->{twig_char_handler}->( $string); }

    # why o why does Expat silently convert XML base enttities?
    if( !$called_from_default)
      { $string=~ s/&/&amp;/g; }
    $string=~ s/([<>'"])/$base_ent{$1}/g;


    delete $t->{twig_current}->{twig_current} if( $t->{twig_current});
    my $elt= $t->{twig_current};
    $elt->{twig_current}=1;

    if( $elt->gi eq PCDATA)
      { # text is the continuation of a previously created pcdata
        $elt->set_pcdata( $elt->{pcdata}.$string); } 
    else
      { # if text is just spaces then it's probably to be discarded
        if( $string=~/\A\s*\Z/)
          { $t->{twig_stored_pcdata}= $string; 
            return;
          } 
        # create a new #PCDATA element
        my $parent= $t->{twig_current};    # always defined
        my $elt=  new XML::Twig::Elt();
        $elt->set_gi( PCDATA);
        # if empty spaces had been previously stored they have to be added
        $string= $t->{twig_stored_pcdata}.$string;
        $t->{twig_stored_pcdata}='';
        $elt->set_pcdata( $string);
        my $prev_sibling= $parent->last_child;
        if( $prev_sibling) 
          { $prev_sibling->set_next_sibling( $elt); 
            $elt->set_prev_sibling( $prev_sibling);
          }

        $elt->set_parent( $parent);
        $parent->set_first_child( $elt) unless( $parent->first_child); 
        $parent->set_last_child( $elt);
      }
    delete $t->{twig_current}->{twig_current} if( $t->{twig_current});
    $elt->{twig_current}=1;
   $t->{twig_current}= $elt;
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
    my $decl= $t->{'twig_xmldecl'} or return $XML_DECL;
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
    my $fh= ref $_[0] eq 'GLOB' ? shift : \*STDOUT;
    my %args= @_;

    my $update_dtd = $args{Update_DTD} || '';

    croak "no twig root" unless( $t->root);
    printf $fh $t->xmldecl;
    return unless( defined $t->{'twig_doctype'});
    my $doctype= $t->{'twig_doctype'};
    if( $update_dtd)
      { 
        if( defined $doctype->{sysid}  )  
          { print $fh "<!DOCTYPE ".$doctype->{name};
            print $fh " SYSTEM \"$doctype->{sysid}\"";
            print $fh " PUBLIC  \"$doctype->{pub}\""  if( $doctype->{pub});
            print $fh "[\n";
            print $fh $t->{twig_entity_list}->print( $fh);
            print $fh "]>\n";
          }
        else
          { my $dtd= $t->{'twig_dtd'};
            print $fh $t->dtd_text;
          }            
      }
    else
      { print $fh "<!DOCTYPE ".$doctype->{name} if( $doctype->{name});
        print $fh $doctype->{internal}; 
        print $fh ">\n"; 
      }
  }

sub print
  { my $t= shift;
    my $fh= ref $_[0] eq 'GLOB' ? shift : \*STDOUT;
    my %args= @_;

    my $update_dtd = $args{Update_DTD} || '';
    $t->print_prolog( $fh, Update_DTD => $update_dtd);
    $t->{twig_root}->print( $fh);
  }

sub flush
  { my $t= shift;
    my $fh= ref $_[0] eq 'GLOB' ? shift : \*STDOUT;
    my %args= @_;

    my $update_dtd = $args{Update_DTD} || '';

    # the "real" last element processed, as twig_end has closed it
    my $last_elt;
    if( $t->{twig_current})
      { $last_elt= $t->{twig_current}->last_child; }
    else
      { $last_elt= $t->{twig_root}; }
    
    my $elt= $t->{twig_root};
    $t->print_prolog( $fh, Update_DTD => $update_dtd) unless( $elt->flushed);

    while( $elt)
      { my $next_elt; 
        if( $last_elt && $last_elt->in( $elt))
          { 
            unless( $elt->flushed) 
              { # just output the front tag
                print $fh $elt->start_tag;
                $elt->flushed(1);
              }
            $next_elt= $elt->first_child;
          }
        else
          { # an element before the last one or the last one,
            $next_elt= $elt->next_sibling;  
            $elt->flush( $fh);
            $elt->delete; 
            last if( $elt == $last_elt);
          }
        $elt= $next_elt;
      }
  }
    

sub root
  { return $_[0]->{twig_root}; }

# WARNING: at the moment the id list is never updated
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
    my $fh= shift || *STDOUT;
    print $fh, $t->dtd_text;
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
    $fh ||= *STDOUT;
    foreach my $ent ( sort keys %{$ent_list})
      { $ent_list->{$ent}->print( $fh); }
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
    $fh ||= *STDOUT;
    print $fh $ent->text . "\n";
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

sub PCDATA { '#PCDATA' }

sub new 
  { my $class= shift;
    my $self  = {};
    bless ($self, $class);
    return $self;
  }

sub set_gi 
  { my ($elt, $gi)= @_;
    unless( $gi2index{$gi})
      { # new gi, create entries in %gi2index and @index2gi
        push  @index2gi, $gi;
        $gi2index{$gi}= $#index2gi;
      }
    $elt->{gi}= $gi2index{$gi}; 
  }

sub gi { return $index2gi[$_[0]->{gi}]; }

sub closed 
  { my $elt= shift;
    my $t= $elt->twig || return;
    my $curr_elt= $t->{twig_current};
    return unless( $curr_elt);
    return $curr_elt->in( $elt);
  }

sub set_pcdata 
  { return unless( $_[0]->gi eq PCDATA);
    return( $_[0]->{'pcdata'}= $_[1]); 
  }
sub pcdata { return $_[0]->{pcdata}; }

sub root 
  { my $elt= shift;
    while( $elt->parent) { $elt= $elt->parent; }
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
    until( $elt->gi eq $gi){ $elt= $elt->{parent} || return; }
    return $elt;
  }

sub set_first_child { $_[0]->{'first_child'}= $_[1]; }
sub first_child
  { my $elt= shift;
    my $gi= shift || return $elt->{first_child};
    my $child= $elt->{first_child};
    while( $child)
      { return $child if( $child->gi eq $gi);
        $child= $child->{next_sibling};
      }
  }


sub set_last_child { $_[0]->{'last_child'}= $_[1]; }
sub last_child 
  { my $elt= shift;
    my $gi= shift || return $elt->{last_child};
    my $child= $elt->{last_child};
    while( $child)
      { return $child if( $child->gi eq $gi);
        $child= $child->{prev_sibling};
      }
  }

sub set_prev_sibling { $_[0]->{'prev_sibling'}= $_[1]; }
sub prev_sibling
  { my $elt= shift;
    my $gi= shift || return $elt->{prev_sibling};
    my $sibling= $elt->{'prev_sibling'};
    while( $sibling)
      { return $sibling if( $sibling->gi eq $gi);
        $sibling= $sibling->{'prev_sibling'};
      }
  }

sub set_next_sibling { $_[0]->{'next_sibling'}= $_[1]; }
sub next_sibling
  { my $elt= shift;
    my $gi= shift || return $elt->{next_sibling};
    my $sibling= $elt->{'next_sibling'};
    while( $sibling)
      { return $sibling if( $sibling->gi eq $gi);
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
      { push @children, $child unless( $gi && $gi ne $child->gi); 
        $child= $child->{'next_sibling'};
      }
    return @children;
  }



sub ancestors
  { my( $elt, $gi)= @_;
    my @ancestors;
    while( $elt->parent)
      { $elt= $elt->parent;
        push @ancestors, $elt
          unless( $gi && ($elt->gi ne $gi));
      }
    return @ancestors;
  }


# kinda counter-intuitive actually:
# the next element is found by looking
# for the next open tag after from the current one
# it's the first child, if it exists, 
# or the next sibling
sub next_elt
  { my $elt= shift;
    my $gi= shift;
    # get next elt
    my $next_elt;
    if( $elt->{'first_child'})
      { $next_elt= $elt->{'first_child'}; }
    elsif( $elt->{'next_sibling'}) 
      { $next_elt= $elt->{'next_sibling'}; }
    else
      { $next_elt= $elt->parent || return undef;
        until( $next_elt->{'next_sibling'})
          { $next_elt= $next_elt->parent || return undef; }
        $next_elt= $next_elt->{'next_sibling'};        
      }  
    # if no gi or right gi then return, else keep on looking
    if( !$gi || ($gi eq $next_elt->gi))
      { return $next_elt; }
    else
      { return $next_elt->next_elt( $gi) }
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
    if( $prev_elt= $elt->prev_sibling)
      { while( $prev_elt->last_child)
          { $prev_elt= $prev_elt->last_child; }
      }
    else
      { $prev_elt= $elt->parent || return; }

    # if no gi or right gi then return, else keep on looking
    if( !$gi || ($gi eq $prev_elt->gi))
      { return $prev_elt; }
    else
      { return $prev_elt->prev_elt( $gi) }
  }


# checks whether $elt is included in $ancestor, returns 1 in that case
sub in($$)
  { my ($elt, $ancestor)= @_;
    while( $elt= $elt->parent) { return 1 if( $elt ==  $ancestor); }
    return 0;           
  }

# returns the depth level of the element
# if 2 parameter are used then counts the 2cd element name in the
# ancestors list
sub level
  { my $elt= shift;
    my $level=0;
    my $name=shift || '';
    while( $elt= $elt->parent) { $level++ if( !$name || ($name eq $elt->gi)); }
    return $level;           
  }

# checks whether $elt has an ancestor type $gi, returns the ancestor
sub in_context
  { my ($elt, $gi, $level)= @_;
    $level= -1 unless( $level) ;  # $level-- will never hit 0

    while( $level && $elt->parent)
      { if( $elt->gi eq $gi) { return $elt; }
        $elt= $elt->parent;
        $level--;
      }
    return ;           
  }

sub flushed
  { my $elt= shift;
    my $flushed= shift || '';
    return $elt->{flushed} unless( $flushed);
    $elt->{flushed}= $flushed;
  }


sub cut
  { my $elt= shift;
    my( $parent, $prev_sibling, $next_sibling, $last_elt);

    # you can't cut the root, sorry
    unless( $parent= $elt->parent) { return; }

    $parent->set_first_child( $elt->next_sibling) 
      if( $parent->first_child == $elt);
    $parent->set_last_child( $elt->prev_sibling) 
      if( $parent->last_child == $elt);

    if( $prev_sibling= $elt->prev_sibling)
      { $prev_sibling->set_next_sibling( $elt->next_sibling); }
    if( $next_sibling= $elt->next_sibling)
      { $next_sibling->set_prev_sibling( $elt->prev_sibling); }

    $elt->set_parent( undef);
    $elt->set_prev_sibling( undef);
    $elt->set_next_sibling( undef);
  }


sub erase
  { my $elt= shift;
    my @children= $elt->children;
    if( @children)
      { # elt has children, move them up
        if( $elt->prev_sibling)
          { # connect first child to previous sibling
            $elt->first_child->set_prev_sibling( $elt->prev_sibling);      
            $elt->prev_sibling->set_next_sibling( $elt->first_child); 
          }
        else
          { # elt was the first child
            $elt->parent->set_first_child( $elt->first_child);
          }
        if( $elt->next_sibling)
          { # connect last child to next sibling
            $elt->last_child->set_next_sibling( $elt->next_sibling);      
            $elt->next_sibling->set_prev_sibling( $elt->last_child); 
          }
        else
          { # elt was the last child
            $elt->parent->set_last_child( $elt->last_child);
          }
        # update parent for all siblings
        foreach my $child (@children)
          { $child->set_parent( $elt->parent); }
      }
    else
      { # elt had no child
        if( $elt->prev_sibling)
          { # connect previous sibling to next sibling (can be undef)
            $elt->prev_sibling->set_next_sibling( $elt->next_sibling);      
          }
        else
          { # elt was the first child
            $elt->parent->set_first_child( $elt->next_sibling);
          }
        if( $elt->next_sibling)
          { # connect next sibling to previous sibling (can be undef)
            $elt->next_sibling->set_prev_sibling( $elt->prev_sibling); 
          }
        else
          { # elt was the last child
            $elt->parent->set_last_child( $elt->next_sibling);
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
    my $pos;
    my $ref;
    if( ref $_[0]) 
      { $pos= 'first_child'; $ref= shift; }
    else
      { ($pos, $ref)= @_; }

    my( $parent, $prev_sibling, $next_sibling );

    if( $pos eq "before")
      { unless( $ref->parent) { croak "cannot paste before root\n"; }
        $parent= $ref->parent;
        $prev_sibling= $ref->prev_sibling;
        $next_sibling= $ref;

        $elt->set_parent( $parent);
        $parent->set_first_child( $elt) if( $parent->first_child == $ref);

        $prev_sibling->set_next_sibling( $elt) if( $prev_sibling);
        $elt->set_prev_sibling( $prev_sibling);

        $next_sibling->set_prev_sibling( $elt);
        $elt->set_next_sibling( $ref);
      }
    elsif( $pos eq "after")
      { unless( $ref->parent) { croak "cannot paste after root\n"; }
        $parent= $ref->parent;
        $prev_sibling= $ref;
        $next_sibling= $ref->next_sibling;

        $elt->set_parent( $parent);
        $parent->set_last_child( $elt) if( $parent->last_child== $ref);

        $prev_sibling->set_next_sibling( $elt);
        $elt->set_prev_sibling( $prev_sibling);

        $next_sibling->set_prev_sibling( $elt) if( $next_sibling);
        $elt->set_next_sibling( $next_sibling);

      }
    elsif( $pos eq "first_child")
      { $parent= $ref;
        $next_sibling= $ref->first_child;

        $elt->set_parent( $parent);
        $parent->set_first_child( $elt);
        $parent->set_last_child( $elt) unless( $parent->last_child);

        $elt->set_prev_sibling( undef);

        $next_sibling->set_prev_sibling( $elt) if( $next_sibling);
        $elt->set_next_sibling( $next_sibling);

      }
    elsif( $pos eq "last_child")
      { $parent= $ref;
        $prev_sibling= $ref->last_child;

        $elt->set_parent( $parent);
        $parent->set_last_child( $elt);
        $parent->set_first_child( $elt) unless( $parent->first_child);

        $elt->set_prev_sibling( $prev_sibling);
        $prev_sibling->set_next_sibling( $elt) if( $prev_sibling);

        $elt->set_next_sibling( undef);

      }
    else
      { croak "tried to paste in wrong position ($pos)\n"; }
  }


# recursively copy an element and returns the copy (can be huge and long)
sub copy
  { my $elt= shift;
    my $copy= new XML::Twig::Elt;
    $copy->set_gi( $elt->gi);
    if( my $atts= $elt->atts)
      { my %atts= %{$atts}; # we want to do a real copy of the attributes
        $copy->set_atts( \%atts);
      }

    if( $elt->gi eq PCDATA)
      { $copy->set_pcdata( $elt->pcdata);
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
    $elt->{'parent'}      = undef; # $elt->set_parent( undef);
    $elt->{'first_child'} = undef; # $elt->set_first_child( undef);
    $elt->{'last_child'}  = undef; # $elt->set_last_child( undef);
    $elt->{'prev_sibling'}= undef; # $elt->set_prev_sibling( undef);
    $elt->{'next_sibling'}= undef; # $elt->set_next_sibling( undef);
    # the id reference also needs to be destroyed
    $elt->del_id;
    $elt->{'att'}= undef;         # $elt->set_atts( undef);
    $elt= undef;
  }

sub start_tag
  { my $elt= shift;
    my $gi= $elt->gi;

    return if( $gi eq PCDATA);
    my $att_string=""; 

    # get the attribute and their values
    my $att= $elt->atts;
    if( $att)
      { foreach my $att_name (sort keys %{$att}) 
         { $att_string .= ' '.$att_name.'="'.$att->{$att_name}.'"'; }
      }

    # build the tags
    if( $elt->{empty}) { return "<$gi$att_string/>"; }
    else               { return "<$gi$att_string>";  }
  }

sub end_tag
  { my $elt= shift;
    my $gi= $elt->gi;
    return if( $elt->gi eq PCDATA || $elt->{empty});
    return "</$gi>";
  }


sub print
  { my ($elt, $fh)= @_;

    $fh ||= *STDOUT;

    my $gi= $elt->gi;

    if( $gi eq PCDATA) { print $fh $elt->pcdata; return; }

    print $fh $elt->start_tag;

    # print the children
    my $child= $elt->first_child;
    while( $child)
      { $child->print( $fh);
        $child= $child->next_sibling;
      }
    print $fh $elt->end_tag;
  }


# same as output but does not output the start tag if the element
# is marked as flushed
sub flush
  { my ($elt, $fh)= @_;

    $fh ||= *STDOUT;

    my $gi= $elt->gi;

    if( $gi eq PCDATA) { print $fh $elt->pcdata; return; }

    print $fh $elt->start_tag unless( $elt->flushed);

    # flush the children
    my @children= $elt->children;
    foreach my $child (@children)
      { $child->flush( $fh); }
    print $fh $elt->end_tag;
  }


# same as print but except... it does not print but rather returns the string
# if the second parameter is set then only the content is returned, not the
# start and end tags of the element (but the tags of the included elements are
# returned)
sub sprint
  { my $elt= shift;
    my $no_tag= shift || 0;

    my $gi= $elt->gi;

    if( $gi eq PCDATA) { return $elt->pcdata; }

    my $string='';

    $string= $elt->start_tag unless( $no_tag);

    # sprint the children
    my $child= $elt->first_child;
    while( $child)
      { $string.= $child->sprint;
        $child= $child->next_sibling;
      }
    $string .= $elt->end_tag unless( $no_tag);
    return $string;
  }


# returns just the text, no tags, for an element
sub text
  { my $elt= shift;
    my $string;

    if( $elt->gi eq PCDATA) { return $elt->pcdata; }

    my $child= $elt->first_child;
    while( $child)
      { $string.= defined($child->text) ? $child->text : '';
        $child= $child->next_sibling;
      }
    return $string;
  }


# creates a single pcdata element containing the text as child of the element
sub set_text
  { my $elt= shift;
    my $string= shift;

    if( $elt->gi eq PCDATA) { return $elt->set_pcdata( $string); }

    foreach my $child (@{[$elt->children]})
      { $child->cut; }

    my $pcdata= new XML::Twig::Elt;
    $pcdata->set_gi( PCDATA);
    $pcdata->set_pcdata( $string);
    $pcdata->paste( $elt);

    return;
  }

# set the content of an element from a list of strings and elements
sub set_content
  { my $elt= shift;

    foreach my $child (@{[$elt->children]})
      { $child->cut; }

    foreach my $child (@_)
      { if( ref $child)
          { $child->paste( 'last_child', $elt); }
        else
          { my $pcdata= new XML::Twig::Elt;
            $pcdata->set_gi( PCDATA);
            $pcdata->set_pcdata( $child);
            $pcdata->paste( 'last_child', $elt);  
          }
      }

    return;
  }

# inserts an element (whose gi is given) as child of the element
# all children of the element are now children of the new element
# returns the new element
sub insert
  { my ($elt, $gi)= @_;
    my $new_elt= new XML::Twig::Elt;
    $new_elt->set_gi( $gi);
    foreach my $child (@{[$elt->children]})
      { $child->cut;
        $child->paste( 'last_child', $new_elt);
      }
    $new_elt->paste( $elt);
    return $new_elt;
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

=head1 DESCRIPTION

This module provides a way to process XML documents. It is build on top
of L<XML::Parser>.

The module offers a tree interface to the document, while allowing to output the parts of it that have been completely processed.

What should you use it for: xml to xml or xml to html conversions of documents that are small enough to fit in memory, or that can be divided in chunks that can be processed separately.

=head1 METHODS

=head2 Twigs 

A twig is a subclass of XML::Parser, so all XML::Parser methods can be used
on one, including parse and parsefile.
setHandlers on the other hand should not be used for Start, End and Char,
see C<L</BUGS>>


=over 4

=item new 

This is a class method, the constructor for XML::Twig. Options are passed
as keyword value pairs. Recognized options are the same as L<XML::Parser>,
plus some XML::Twig specifics:

=over 4

=item - TwigHandlers

This argument replaces the corresponding XML::Parser argument. It consists
of a hash { gi => \&handler} 
A gi (generic identifier I guess) is just a tag name by the way.
When an element is CLOSED the corresponding handler is called, with 2 arguments,
the twig and the C<L</Element>>. The twig includes the document tree taht has been 
built so far, the element is the complete sub-tree for the element.
Text is stored in elements which gi is #PCDATA (due to mixed content, text
and sub-element in an element there is no way to store the text as just an
attribute of the enclosing element).

=item LoadDTD

If this argument is set to a true value, parse or parsefile on the twig will load  
the DTD information. This information can then be accessed through the twig, 
in a DTDHandler for example. This will load even an external DTD.

See L<DTD Handling> for more information

=item DTDHandler

Sets a handler that will be called once the doctype (and the DTD) have been loaded,
with 2 arguments, the twig and the DTD.

-item StartTagHandlers

A hash { gi => \&handler}. Sets element handlers that are called when the element 
is open (at the end of the XML::Parser Start handler). THe handlers are called with
2 params: the twig and the element. The element is empty at that point, its attributes
are created though.

The main use for those handlers is probably to create temporary attributes that will
be used when processing the element with the normal TwigHanlder.  

-item CharHandler

A reference to a subroutine that will be called every time PCDATA.

=item - Id

This optional argument gives the name of an attribute that can be used as
an ID in the document. Elements whose ID is known can be accessed through
the elt_id method. Id defaults to 'id'.
See C<L</BUGS>>

=back

=item root

Returns the root element of a twig

=item entity_list

Returns the entity list of a twig



=item change_gi      ($old_gi, $new_gi)

Performs a (very fast) global change. All elements old_gi are now new_gi.
See C<L</BUGS>>

=item flush            OPTIONAL_FILEHANDLE OPTIONNAL_OPTIONS

Flushes a twig up to (and including) the current element, then deletes
all unnecessary elements from the tree that's kept in memory.
flush keeps track of which elements need to be open/closed, so if you
flush from handlers you don't have to worry about anything. Just keep 
flushing the twig every time you're done with a sub-tree and it will
come out well-formed. After the whole parsing don't forget to flush
one more time to print the end of the document.
The doctype and entity declarations are also printed.

OPTIONNAL_OPTIONS

=over 4

= item Update_DTD

Use that option if you have updated the (internal) DTD and/or the enity list
and you want the updated DTD to be output 

Example $t->flush( Update_DTD => 1);
        $t->flush( \*FILE, Update_DTD => 1);
        $t->flush( \*FILE);

=back


flush take an optional filehandle as an argument.

=item print            OPTIONNAL_FILEHANDLE OPTIONNAL_OPTIONS

Prints the whole document associated with the twig. To be used only AFTER the
parse.

OPTIONNAL_OPTIONS: see L<flush>.


=item print_prolog     OPTIONNAL_FILEHANDLE OPTIONNAL_OPTIONS

Prints the prolog (XML declaration + DTD + entity declarations) of a document.

OPTIONNAL_OPTIONS: see L<flush>.

=back 

=head2 Element

=over 4

=item new 

Should be private.

=item set_gi         ($gi)

Sets the gi of an element

=item gi                       

Returns the gi of the element

=item closed                   

Returns true if the element has been closed. Might be usefull if you are
somewhere in the tree, during the parse, and have no idea whether a parent
element is completely loaded or not.


=item set_pcdata     ($text)

Sets the text of a #PCDATA element. Returns the text or undef if the element
was not a #PCDATA.

=item pcdata

Returns the text of a #PCDATA element or undef

=item root 

Returns the root of the twig containing the element

=item twig 

Returns the twig containing the element. 

=item parent        ($optional_gi)

Returns the parent of the element, or the first ancestor whose gi is $gi.

=item first_child   ($optional_gi)

Returns the first child of the element, or the first child whose gi is $gi. 
(ie the first of the element children whose gi matches) .

=item last_child    ($optional_gi)

Returns the last child of the element, or the last child whose gi is $gi. 
(ie the last of the element children whose gi matches) .

=item prev_sibling  ($optional_gi)

Returns the previous sibling of the element, or the first one whose gi is $gi. 

=item next_sibling  ($optional_gi)

Returns the next sibling of the element, or the first one whose gi is $gi. 

=item atts

Returns a hash ref containing the element attributes

=item set_atts      ({att1=>$att1_val, att2=> $att2_val... )

Sets the element attributes with the hash supplied as argument

=item del_atts

Deletes all the element attributes.

=item set_att      ($att, $att_value)

Sets the attribute of the element to a value

=item att          ($att)

Returns the attribute value

=item del_att { delete $_[0]->{'att'}->{$_[1]}; }

Delete the attribute for the element

=item set_id       ($id)

Sets the id attribute of the element to a value.
See C<L</elt_id>> to change the id attribute name

=item id

Gets the id attribute vakue

=item del_id       ($id)

Deletes the id attribute of the element and remove it from the id list
for the document

=item children     ($optional_gi)

Returns the list of children (optionally whose gi is $gi) of the element

=item ancestors    ($optional_gi)

Returns the list of ancestors (optionally whose gi is $gi) of the element

=item next_elt     ($optional_gi)

Returns the next elt (optionally whose gi is $gi) of the element. This is 
defined as the next element which opens after the current element opens.
Which usually means the first child of the element.
Counter-intuitive as it might look this allows you to loop through the
whole document by starting from the root.

=item prev_elt     ($optional_gi)

Returns the previous elt (optionally whose gi is $gi) of the element. This
is the first element which open the current one. So it's usually either
the last descendant of the previous sibling or simply the parent

=item level       ($optionnal_gi)

Returns the depth of the element in the tree (root is 1)
If the optionnal gi is given then only ancestors of the given type are counted 

=item in           ($potential_parent)

Returns true if the element is in the potential_parent

=item in_context   ($gi, $optional_level)

Returns true if the element is included in an element whose gi is $gi,
within $level levels.

=item cut

Cuts the element from the tree.

=item paste       ($optional_position, $ref)

Pastes a (previously cut) element.
The optionnal position element can be

=over 4

=item - first_child (default)

The element is pasted as the first child of the $ref element

=item - last_child

The element is pasted as the last child of the $ref element

=item - before

The element is pasted before the $ref element, as its previous sibling


=item - after

The element is pasted after the $ref element, as its next sibling

=back

=item erase

Erases the element: the element is deleted and all of its children are
pasted in its place.

=item delete

Cut the element and frees the memory

=item DESTROY

Frees the element from memory 

=item start_tag

Returns the string for the start tag for the element, including the
/> at the end of an empty element tag

=item end_tag

Returns the string for the end tag of an element, empty for an empty one.

=item print         OPTIONNAL_FILEHANDLE

Prints an entire element, including the tags, optionally to a FILEHANDLE     

=item sprint  

Returns the string for an entire element, including the tags. To be used 
with caution!

=item text

Returns a string consisting of all the PCDATA in an element, without the
tagging

=item set_text        ($string)

Sets the text for the element: if the element is a PCDATA, just set its
text, otherwise cut all the children of the element and create a single
PCDATA child for it, which holds the text

=item set_content    (@list_of_elt_and_strings)

Sets the content for the element, from as list of strings and elements.
Cuts all the element children, then pastes the list elements, creating a 
PCDATA element for strings.

=item insert         ($gi)

Inserts an element $gi as the only child of the element, all children of 
the element are set as children of the new element, returns the new element

=item private methods

=over 4

=item close

=item set_parent        ( $parent)

=item set_first_child   ( $first_child)

=item set_last_child    ( $last_child)

=item set_prev_sibling  ( $set_prev_sibling)

=item set_next_sibling  ( $set_next_sibling)

=item flushed

=item flush

=back

Those methods should not be used, unless of course you find some creative 
and interesting, not to mention usefull, ways to do it.


=back

=head2 Entity_list

=over 4

=item new

Creates an entity list

=item add         ($ent)

Adds an entity to an entity list.

=item delete     ($ent or $gi).

Deletes an entity (defined by its name or by the Entity object) from the list.

=item print      (OPTIONAL_FILEHANDLE)

Prints the entity list

=back

=head2 Entity

=over 4

=item new        ($name, $val, $sysid, $pubid, $ndata)

Same arguments has the Entity handler for XML::Parser

=item print       (OPTIONNAL_FILEHANDLE)

Prints an entity declaration

=item text

Returns the entity declaration text

=back


=head1 EXAMPLES

See the test file in XML-Twig-1.6/t/test[1-n].t 

To figure out what flush does call the following script with an xml file and an element name as arguments

use XML::Twig;

my ($file, $elt)= @ARGV;
my $t= new XML::Twig( TwigHandlers => 
    { $elt => sub {$_[0]->flush; print "\n[flushed here]\n";} });
$t->parsefile( $file, ErrorContext => 2);
$t->flush;
print "\n";



=head1 NOTES

=head2 DTD Handling

3 possibilities here

=over 4

=item No DTD

No doctype,  no DTD information, no entitiy information, the world is simple...

=item Internal DTD

The XML document includes an internal DTD, and maybe entity declarations

If you use the LoadDTD option when creating the twig the DTD information and the entity 
declarations can be accessed. 

The DTD and the entity declarations will be flush'ed (or print'ed) either asis
(if they have not been modified) or as reconstructed (poorly, comments are lost, 
order is not kept, due to it's content this DTD should not be viewed bu anyone) 
if they have been modified. You can also modify them directly by changing the 
$twig->{twig_doctype}->{internal} field (straight from XML::Parser, see the Doctype 
handler doc)

=item External DTD

The XML document includes a reference to an external DTD, and maybe entity declarations.

If you use the LoadDTD when creating the twig the DTD information and the entity 
declarations can be accessed. The entity declarations will be flush'ed (or print'ed)
either asis (if they have not been modified) or as reconstructed (badly, comments are
lost, order is not kept).

You can change the doctype through the $twig->set_doctype method and print the dtd 
through the $twig->dtd_text or $twig->dtd_print methods.

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

=item - ID list

The ID list is NOT updated at the moment when ID's are modified or elements 
cut or deleted.

=item - change_gi

Does not work if you do:
     $twig->change_gi( $old1, $new);
     $twig->change_gi( $old2, $new);
     $twig->change_gi( $new, $even_newer);

=item - sanity check on XML::Parser method calls

XML::Twig should really prevent calls to some XML::Parser methods, especially the setHandlers one.


=back

=head1 TODO 

=over 4

=item - multiple twigs are not well supported

A number of twig features are just global at the moment. These include
the ID list and the "gi pool" (if you use change_gi then you change the gi 
for ALL twigs).

Next version will try to  support these while trying not to be to hard on
performances (at least when a single twig is used!).  


=item - XML::Parser-like handlers

Sometimes it would be nice to be able to use both XML::Twig handlers and
XML::Parser handlers, for example to perform generic tasks on all open
tags, like adding an ID, or taking care of the autonumbering.

Next version...


=back


=head1 BENCHMARKS

You can use the C<benchmark> file to do additional bechmarks.
Please send me bechmark information for additional systems.

=head1 AUTHOR

Michel Rodriguez <m.v.rodriguez@ieee.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Bug reports and comments to m.v.rodriguez@ieee.org.

=head1 SEE ALSO

L<XML::Parser>


=cut

