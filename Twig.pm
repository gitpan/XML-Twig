# XML::Twig  %W% - %E%
#
# Copyright (c) 1999 Michel Rodriguez
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


######################################################################
package XML::Twig;
######################################################################

require 5.004;

use strict; 
use vars qw($VERSION @ISA);
use Carp;
#use Exporter;

sub PCDATA { '#PCDATA' }

BEGIN
{
    require XML::Parser;
    $VERSION = '1.6';

    my $needVersion = '2.16';
    croak "need at least XML::Parser version $needVersion"
	unless $XML::Parser::VERSION >= $needVersion;
    import XML::Twig::Elt;
    import XML::Twig::Entity;
    import XML::Twig::Entity_list;
}

@ISA = ("XML::Parser");

my %twig_handlers=( Start  => \&twig_start, 
                    End    => \&twig_end, 
                    Char   => \&twig_char, 
                    Entity => \&twig_entity, 
                  );

my $ID= 'id'; # default value, set by the Id argument

# used to store the gi's
# should be set for each twig really, at least when tere are several
my %gi2index; # gi => index
my @index2gi; # list of gi's

my $XML_DECL= '<?xml version="1.0" standalone="%s"?>';

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
    $self->{twig}= $self;

    $self->{twig_entity_list}= new XML::Twig::Entity_list; 

    bless $self, $class;
    return $self;

  }

# the default twig handlers, which build the tree
sub twig_start($$%)
  { my ($p, $gi, %att)  = @_;
    my $t=$p->{twig};
    my $parent= $t->{twig_elt};
    my $elt= new XML::Twig::Elt();

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
      }
    
    if( $p->recognized_string=~ /\/>\Z/) { $elt->{empty}=1; }

    # if the element is ID-ed then store that info
    my $id= $elt->id;
    if( $id) { $t->{twig_id_list}->{$id}= $elt; }

    $t->{twig_elt}= $elt;

    # empty the stored pcdata (space stored in case
    # they are really part of a pcdata element)
    $t->{twig_stored_pcdata}='';
  }


sub twig_end($$%)
  { my ($p, $gi)  = @_;
    my $t=$p->{twig};
        
    # build the tree
    my $elt= $t->{twig_elt};
    if( $elt) { $t->{twig_parent}= $elt->parent; }
    $t->{twig_elt}= $t->{twig_elt}->parent;

    # empty the stored pcdata (space stored in case
    # they are really part of a pcdata element)
    $t->{twig_stored_pcdata}='';

    # call user handler if need be
    if( defined $t->{twig_handlers}->{$gi})
      { $t->{twig_handlers}->{$gi}->($t, $elt); }

  }

sub twig_char($$)
  { my ($p, $string)= @_;
    my $t=$p->{twig};


    my $elt= $t->{twig_elt};
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
        my $parent= $t->{twig_elt};    # always defined
        my $elt=  new XML::Twig::Elt();
        $elt->set_gi( PCDATA);
        # if empty spaces had been previously stored they have to be added
        $string= $t->{twig_stored_pcdata}.$string;
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
  }
 

sub twig_entity($$$$$$)
  { my( $t, $name, $val, $sysid, $pubid, $ndata)= @_;
    my $ent=new XML::Twig::Entity( $name, $val, $sysid, $pubid, $ndata);
    $t->{twig_entity_list}->add( $ent);
  }

sub entity_list($)
  { my $t= shift;
    return $t->{twig_entity_list};
  }


sub print_prolog
  { my( $t, $fh)= @_;
    $fh ||= *STDOUT;
    croak "no twig root" unless( $t->root);
    if( $t->{twig_entity_list})
      { printf $fh $XML_DECL, 'no';
      
        print $fh "<!DOCTYPE " . $t->root->gi . "[\n";
        $t->{twig_entity_list}->print( $fh);
        print "]>\n";
      }
    else
      { printf $fh $XML_DECL, 'yes'; }
  }

sub print
  { my( $t, $fh)= @_;
    $fh ||= *STDOUT;
    $t->flush( $fh);
  }

sub flush
  { my( $t, $fh)= @_;
    $fh ||= *STDOUT;

    # the "real" last element processed, as twig_end has closed it
    my $last_elt;
    if( $t->{twig_elt})
      { $last_elt= $t->{twig_elt}->last_child; }
    else
      { $last_elt= $t->{twig_root}; }
    
    my $elt= $t->{twig_root};
    $t->print_prolog( $fh) unless( $elt->flushed);

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
            $elt->flush;
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


sub print
  { my ($ent, $fh)= @_;
    $fh ||= *STDOUT;
    print $fh $ent->text . "\n";
  }

sub text
  { my ($ent)= @_;
    if( $ent->{val})
      { if( $ent->{val}=~ /"/)
          { return "<!ENTITY $ent->{name} '$ent->{val}'>"; }
        return "<!ENTITY $ent->{name} \"$ent->{val}\">";
      }
    elsif( $ent->{sysid})
      { my $text= "<!ENTITY $ent->{name} ";
        $text .= "SYSTEM \"$ent->{sysid}\" " if( $ent->{sysid});
        $text .= "PUBLIC \"$ent->{pubid}\" " if( $ent->{pubid});
        $text .= "NDATA $ent->{ndata}"        if( $ent->{ndata});
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
    my $curr_elt= $t->{twig_elt};
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
  { $_[0]->set_att($ID, $_[1]); 
}
sub id { return $_[0]->{'att'}->{$ID}; }

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

sub level
  { my $elt= shift;
    my $level=0;
    while( $elt= $elt->parent) { $level++; }
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
  }
        


# paste elt somewhere around ref
# if the second argument is ommited then 'first_child' is used
# first_child (default), last_child, before, after
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

sub delete
  { my $elt= shift;
    $elt->cut;
    $elt->DESTROY;
  }

sub DESTROY
  { my $elt= shift;

    foreach( $elt->children) { $_->DESTROY; }
    # destroy all references in the tree
    $elt->set_parent( undef);
    $elt->set_first_child( undef);
    $elt->set_last_child( undef);
    $elt->set_prev_sibling( undef);
    $elt->set_next_sibling( undef);

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
sub sprint
  { my ($elt)= @_;
    my $gi= $elt->gi;

    if( $gi eq PCDATA) { return $elt->pcdata; }

    my $string= $elt->start_tag;

    # sprint the children
    my $child= $elt->first_child;
    while( $child)
      { $string.= $child->sprint;
        $child= $child->next_sibling;
      }
    return $string.$elt->end_tag;
  }

# returns just the text, no tags, for an element
sub text
  { my $elt= shift;
    my $string;

    if( $elt->gi eq PCDATA) { return $elt->pcdata; }

    my $child= $elt->first_child;
    while( $child)
      { $string.= $child->text || '';
        $child= $child->next_sibling;
      }
    return $string;
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
        my $t= new XML::Twig( Handlers => { section => \&flush});
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

=item - new 

This is a class method, the constructor for XML::Twig. Options are passed
as keyword value pairs. Recognized options are the same as L<XML::Parser>,
plus some XML::Twig specifics:

=over 4

=item - TwigHandlers

This argument replaces the corresponding XML::Parser argument. It consists
of a hash { gi => \&handler} 
A gi (generic identifier I guess) is just a tag name by the way.
When an element is CLOSED the corresponding handler is called, with 2 arguments,
the twig and the C<L</Element>>. The twig includes the document tree taht has been built so far, the element is the complete sub-tree for the element.
Text is stored in elements which gi is #PCDATA (due to mixed content, text
and sub-element in an element there is no way to store the text as just an
attribute of the enclosing element).

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

=item flush            OPTIONAL_FILEHANDLE

Flushes a twig up to (and including) the current element, then deletes
all unnecessary elements from the tree that's kept in memory.
flush keeps track of which elements need to be open/closed, so if you
flush from handlers you don't have to worry about anything. Just keep 
flushing the twig every time you're done with a sub-tree and it will
come out well-formed. After the whole parsing don't forget to flush
one more time to print the end of the document.
The doctype and entity declarations are also printed by the way.

flush take an optional filehandle as an argument.

=item print            OPTIONNAL_FILEHANDLE

Oddly enough this is just an alias for the flush method. For sanity's sake
just try to use it only for trees that have been completely loaded, there
is no check right now but I might add one soon.

=item print_prolog     OPTIONNAL_FILEHANDLE

Prints the prolog (XML declaration + DTD + entity declarations) of a document.
Does not print the DTD at the moment.

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

Returns a hash containing the element attributes

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

=item level

Returns the depth of the element in the tree (root is 1)

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
and interesting ways to do it.


=back

=head2 Entity_list

=over4

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

See the test file in XML-Twig-1.6/t/test1.t


=head1 HINTS

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

=item - Notation declarations

Are not output (in fact they are completely ignored).

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

=item - create an element (not a twig) from a string

=back

=head1 AUTHOR

Michel Rodriguez <m.v.rodriguez@ieee.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Bug reports and comments to m.v.rodriguez@ieee.org.

=head1 SEE ALSO

L<XML::Parser>


=cut

