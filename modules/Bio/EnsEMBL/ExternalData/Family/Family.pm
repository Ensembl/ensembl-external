# $Id$
#
# BioPerl module for Family
#
# Cared for by Philip Lijnzaad <lijnzaad@ebi.ac.uk>
#
# Copyright Philip Lijnzaad
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Family - DESCRIPTION of Object

=head1 SYNOPSIS

my $famdb=Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor\
                               ->new(-dbname=>'anton-1', 
                                     -host=>'ecs1c', 
                                     -user=>'ensadmin');

my $fam = $famdb->get_family_by_Ensembl_id('ENSP00000012304');

print $fam->description, join('; ',$fam->keywords), $fam->release, 
      $fam->score, $fam->size;


=head1 DESCRIPTION

This object describes protein families obtained from 
clustering SWISSPROT using Anton Enright's algorithm. The clustering
neatly follows the SWISSPROT DE-lines, which are taken as the description
of the whole family.

The object is a bit bare, still; dbxrefs (i.e., family to family) are not
implemented, and SWSISSPROT keywords aren't there yet either. 

The family members are currently represented by DBLink's; more convenient
navigation may be added at a later stage.


=head1 CONTACT

 Philip Lijnzaad <Lijnzaad@ebi.ac.uk>, Anton Enright <enright@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# ';  # (pacify emacs).  

# Let the code begin...;

package Bio::EnsEMBL::ExternalData::Family::Family;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::Object

use Bio::Root::Object;
use Bio::DBLinkContainerI;
use Bio::Annotation::DBLink;


@ISA = qw(Bio::Root::Object Bio::DBLinkContainerI);
# new() is inherited from Bio::Root::Object

# _initialize is where the heavy stuff will happen when new is called

sub _initialize {
  my($self,@args) = @_;

  my $make = $self->SUPER::_initialize;

# set stuff in self from @args
 return $make; # success - we hope!
}

=head2 new

 Title   : new
 Usage   : not intended for general use.
 Function:
 Example :
 Returns : a family (but without members; caller has to fill using
           add_member or add_DBLink)
 Args    :
         
=cut

sub new {
   my ($class, @args) = @_;

   my $self = {};
   bless $self,$class;

# do this explicitly.
#    my ($internal_id, $id,$descr,$score, $rel, $debug,) 
#      = $self->_rearrange([qw(
#                              INTERNAL_ID
#                              ID
#                              DESCRIPTION
#                              RELEASE
#                              SCORE
#                              DEBUG
#                             )], @args);
# 
#    $id || $self->throw("family must have an id");
#    $self->id($id);
# 
#    $descr || $self->throw("family must have a description");
#    $self->description($descr);
# 
#    $self->{_members} = []; 
#    foreach my $mem (@args) {
#        $self->add_member($mem);
#    }
#
#   $self->_debug($debug?$debug:0);
   $self;
}                                       # new


=head2 id

 Title   : id
 Usage   : 
 Function: get/set the display id of the Family
 Example :
 Returns : 
 Args    : 
=cut

sub id {
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'id'} = $value;
    }
    return $self->{'id'};
}

=head2 internal_id

 Title   : internal_id
 Usage   : 
 Function: get/set the internal_id of the Family
 Example :
 Returns : 
 Args    : 
=cut

sub internal_id {
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'internal_id'} = $value;
    }
    return $self->{'internal_id'};
}

=head2 description

 Title   : description
 Usage   : 
 Function: get/set the description of the Family. 
 Example :
 Returns : A string (currently all upper case, and no longer than 255 chars).
 Args    : 
=cut

sub description {
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'desc'} = $value;
    }
    return $self->{'desc'};
}

=head2 release

 Title   : release
 Usage   : 
 Function: get/set the release number of the family database;
 Example :
 Returns : 
 Args    : 
=cut

sub release {
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'release'} = $value;
    }
    return $self->{'release'};
}

=head2 annotation_confidence_score

 Title   : annotation_confidence_score
 Usage   : 

 Function: get/set the annotation_confidence_score of the Family. This a
           measure of how good the cluster is (what is the scale??)
 Example :
 Returns : 
 Args    : 
=cut

sub annotation_confidence_score {
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'annotation_confidence_score'} = $value;
    }
    return $self->{'annotation_confidence_score'};
}

# =head2 keywords
# 
#  Title   : keywords
#  Usage   : 
#  Function: get/set the SWISSPROT keywords
#  Example :
#  Returns : 
#  Args    : 
# =cut
# 
# # sub keywords { 
#     my ($self) = @_; 
#     $self->throw("not yet implemented");
# }


=head2 size

 Title   : size
 Usage   : $fam->size
 Function: returns the number of members of the family
 Returns : an int
 Args    : 

=cut

sub size {
 my ($self) = @_; 
 return int(@{$self->{'_members'}});
}

=head2 each_member_of_db

 Title   : each_member_of_db
 Usage   : $obj->each_member_of_db('SWISSPROT')
 Function: returns all the members that belong to a particular database
 Returns : a list of DBLinks (which may be empty)
 Args    : the database name

=cut

sub each_member_of_db {
  my ($self, $db) = @_;

  # might be slowish; do we need to change this, e.g., go to database? 

  my @mems = ();

  foreach my $mem ($self->each_DBLink()) {  
    if ($mem->database eq $db) { 
         push @mems, $mem;
     };
  }
  return @mems;
}

### inherited from Bio::DBLinkContainerI
=head2 each_DBLink

 Title   : each_DBLink
 Usage   : foreach $ref ( $self->each_DBLink() )
 Function: find all the members of the family
 Example :
 Returns : an array of Bio::Annotation::DBLink objects
 Args    : none
=cut

sub each_DBLink{
   my ($self) = @_;

  return @{$self->{'_members'}};
}

=head2 add_DBLink

 Title   : add_DBLink
 Usage   : not for general use (in fact, currently unused)
 Function: add a member to this family
 Example :
 Returns :  undef;
 Args    : a DBLink pointing to the member


=cut

sub add_DBLink {
    my ($self,$value) = @_;

    if(     !defined $value 
         || !ref $value 
         || ! $value->isa('Bio::Annotation::DBLink') ) {
        $self->throw("This [$value] is not a DBLink");
    }
    push(@{$self->{'_members'}},$value);
    undef;
}


# convert a string pair to a DBLink
sub _dbid_to_dblink {
    my($database, $primary_id) = @_; 

    if ($database eq '' || $primary_id eq '') {
        Bio::Root::RootI->throw("Bio::EnsEMBL::ExternalData::Family::Family::_dbid_to_dblink:  must have both a database and an id");
    }
    my $link = new Bio::Annotation::DBLink();

    $link->database($database);
    $link->primary_id($primary_id);
    $link;
}

=head2 add_member

 Title   : add_member
 Usage   : (not for general usage)
 Function: adds member to family. Like add_DBLlink, but takes a string
           pair, rather than a DBLink.
 Example : $fam->add_member('SWISSPROT', 'P12345');
 Returns : undef
 Args    : db: the database name and primary_id: the primary_id of the database

=cut

sub add_member { 
    my ($self, $database, $primary_id) = @_; 

    push @{$self->{_members}}, _dbid_to_dblink($database, $primary_id);
    undef;
}

=head2 _debug

 Title   : _debug
 Usage   : $obj->_debug($newval)
 Function: 
 Example : 
 Returns : value of _debug
 Args    : newvalue (optional)


=cut

sub _debug{
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'_debug'} = $value;
    }
    return $self->{'_debug'};
}

1;
