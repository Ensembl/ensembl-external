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

Describe the object here

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal
methods are usually preceded with a _

=cut


# Let the code begin...;

;
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
 Usage   :
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

   my ($id,$descr,$debug,) = $self->_rearrange([qw(
                                    ID
                                    DESCRIPTION
                                    DEBUG
                                    )], @args);

   $id || $self->throw("family must have an id");
   $self->id($id);

   $descr || $self->throw("family must have a description");
   $self->description($descr);

   $self->{_members} = []; 
#    foreach my $mem (@args) {
#        $self->add_member($mem);
#    }

   $self->_debug($debug?$debug:0);
}                                       # new



=head2 each_DBLink

 Title   : each_DBLink
 Usage   : foreach $ref ( $self->each_DBlink() )
 Function: gets an array of DBlinks representing/pointing to the family members
 Example :
 Returns : an array of Bio::Annotation::DBLink objects
 Args    : none

=cut


### inherited from Bio::DBLinkContainerI
=head2 each_DBLink

 Title   : each_DBLink
 Usage   : foreach $ref ( $self->each_DBlink() )
 Function: gets an array of DBlink of objects
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
 Usage   :
 Function: add a member to this family
 Example :
 Returns : 
 Args    : a DBLink pointing to the member


=cut
;

sub add_DBLink{
    my ($self,$value) = @_;

    if(     !defined $value 
         || !ref $value 
         || ! $value->isa('Bio::Annotation::DBLink') ) {
        $self->throw("This [$value] is not a DBLink");
    }

    push(@{$self->{'_members'}},$value);
}


# convert a string pair to a DBLink
sub _dbid_to_dblink {
    my($database, $primary_id) = @_; 

    if ($database eq '' || $primary_id eq '') {
        Bio::Root::RootI->throw("Bio::EnsEMBL::ExternalData::Family::Family::_dbid_to_dblink:  must have both a database and an id");
    }
    my $link = Bio::Annotation::DBLink::new();

    $link->database($database);
    $link->primary_id($primary_id);
    $link;
}

=head2 add_member

 Title   : add_member
 Usage   : $fam->add_member('SWISSPROT', 'P12345');

 Function: adds member to family. Like add_DBLlink, but takes a string
           pair, rather than a DBLink.

 Example :
 Returns : 
 Args    : db: the database name and primary_id: the primary_id of the database

=cut

sub add_member { 
    my ($self, $database, $primary_id) = @_; 

    push @{$self->{_members}}, _dbid_to_dblink($database, $primary_id);
}

=head2 _debug

 Title   : _debug
 Usage   : $obj->_debug($newval)
 Function: 
 Example : 
 Returns : value of _debug
 Args    : newvalue (optional)


=cut

sub id {
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'id'} = $value;
    }
    return $self->{'id'};
}

sub description {
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'desc'} = $value;
    }
    return $self->{'desc'};
}



sub _debug{
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'_debug'} = $value;
    }
    return $self->{'_debug'};
}

sub keywords { 
    my ($self) = @_; 
    $self->throw("not yet implemented");
}

sub release { 
    my ($self) = @_; 
    $self->throw("not yet implemented");
}

sub score {  
    my ($self) = @_; 
    $self->throw("not yet implemented");
}

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
 Returns : 
 Args    : the database name

=cut

sub each_member_of_db {
  my ($self, $db) = @_;

  # might be slowish; do we need to change this, e.g., go to database? 

  my @mems = ();

  foreach my $mem ($self->each_DBlink()) {  
    if ($mem->database eq $db) { push @mems, $mem};
  }
  return @mems;
}


