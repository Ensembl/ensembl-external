# $Id$
#
# BioPerl module for Family
#
# Initially cared for by Philip Lijnzaad <lijnzaad@ebi.ac.uk>
# Now cared by Abel Ureta-Vidal <abel@ebi.ac.uk> and Elia Stupka <elia@fugu-sg.org>
#
# Copyright Philip Lijnzaad
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Family - DESCRIPTION of Object

=head1 SYNOPSIS

  use Bio::EnsEMBL::DBSQL::DBAdaptor;
  use Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor;
  use Bio::EnsEMBL::ExternalData::Family::Family;

  $famdb = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
                                             -user   => 'ensro',
                                             -dbname => 'family102',
                                             -host   => 'ecs1b',
                                             -driver => 'mysql',
                                              );

  my $fam_adtor =
    Bio::EnsEMBL::ExternalData::Family::FamilyAdaptor->new($famdb);

  my $fam = $fam_adtor->get_family_by_Ensembl_id('ENSP00000012304');

  print $fam->description, join('; ',$fam->keywords), $fam->release, 
    $fam->score, $fam->size;


=head1 DESCRIPTION

This object describes protein families obtained from clustering
SWISSPROT/TREMBL using Anton Enright's Tribe algorithm. The clustering
neatly follows the SWISSPROT/TREMBL DE-lines, which are taken as the
description of the whole family.

The object is a bit bare, still; dbxrefs (i.e., family to family) are not
implemented, and SWSISSPROT keywords aren't there yet either. 

The family members are currently represented by DBLink's; more convenient
navigation may be added at a later stage.


=head1 CONTACT

 Philip Lijnzaad <Lijnzaad@ebi.ac.uk> [original perl modules]
 Anton Enright <enright@ebi.ac.uk> [TRIBE algorithm]
 Elia Stupka <elia@fugu-sg.org> [refactoring]
 Able Ureta-Vidal <abel@ebi.ac.uk> [multispecies migration]

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# ';  # (pacify emacs).  

# Let the code begin...;

package Bio::EnsEMBL::ExternalData::Family::Family;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::EnsEMBL::Root
use Bio::EnsEMBL::Root;

@ISA = qw(Bio::EnsEMBL::Root);

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
  my($class,@args) = @_;
  
  my $self = $class->SUPER::new(@args);
  
  if (scalar @args) {
     #do this explicitly.
     my ($dbid, $stable_id,$descr,$release, $score, $memb,$adap) = $self->_rearrange([qw(DBID STABLE_ID DESCRIPTION RELEASE SCORE MEMBERS ADAPTOR)], @args);
      
      $dbid && $self->dbID($dbid);
      $stable_id || $self->throw("Must have a stable_id");
      $self->stable_id($stable_id);

      $descr || $self->throw("family must have a description");
      $self->description($descr);

      $release && $self->release($release);
      $score && $self->annotation_confidence_score($score);
      $self->{_members} = []; 
      push (@{$self->{_members}},@{$memb});
      $adap && $self->adaptor($adap);
  }
  
  return $self;
}   

=head2 adaptor

 Title   : adaptor
 Usage   : $adaptor = $fam->adaptor
 Function: find this objects\'s adaptor object (set by FamilyAdaptor)
 Example :
 Returns : 
 Args    : 

=cut

sub adaptor {
  my ($self,$value)= @_;
  
  if (defined $value) {
    $self->{'adaptor'} = $value;
  }

  return $self->{'adaptor'};
}


=head2 stable_id

 Title   : stable_id
 Usage   : 
 Function: get/set the display stable_id of the Family
 Example :
 Returns : 
 Args    : 

=cut

sub stable_id {
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'stable_id'} = $value;
    }
    return $self->{'stable_id'};
}

=head2 dbID

 Title   : dbID
 Usage   : 
 Function: get/set the dbID of the Family
 Example :
 Returns : 
 Args    : 

=cut

sub dbID {
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'dbID'} = $value;
    }
    return $self->{'dbID'};
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

=head2 size

 Title   : size
 Usage   : $fam->size
 Function: returns the number of peptide members of the family
 Returns : an int
 Args    : none

=cut

sub size {
  my ($self) = @_; 
  
  # we do not want to have a total number of gene+peptide members (that is non sense)
  # That is why we substracte from the total those corresponding to genes
  # Need to be fixed as ENSEMBLGENE is here hard coded
  # Probably by just adding a colunm type in external_db, which would be gene, peptide, or
  # even transcript. Then recode size as size_by_type or something like that.
  # size_by_type('peptide'),...

  return scalar $self->each_member - $self->size_by_dbname('ENSEMBLGENE');
}

=head2 size_by_dbname

 Title   : size_by_dbname
 Usage   : $fam->size_by_dbname('ENSEMBLGENE')
 Function: returns the number of members of the family belonging to a particular databasename
 Returns : an int
 Args    : a databasename


=cut

sub size_by_dbname {
  my ($self, $dbname) = @_; 
  
  $self->throw("Should give a defined databasename as argument\n") unless (defined $dbname);
  
  return scalar $self->each_member_of_db($dbname);
}

=head2 size_by_dbname_taxon

 Title   : size_by_dbname_taxon
 Usage   : $fam->size_by_dbname_taxon('ENSEMBLGENE',9606)
 Function: returns the number of members of the family belonging to a particular databasename and a taxon
 Returns : an int
 Args    : a databasename and a taxon_id

=cut

sub size_by_dbname_taxon {
  my ($self, $dbname, $taxon_id) = @_; 
  
  $self->throw("Should give defined databasename and taxon_id as arguments\n") unless (defined $dbname && defined $taxon_id);

  return scalar $self->each_member_of_db_taxon($dbname,$taxon_id);
}

=head2 each_member

 Title   : each_member
 Usage   : foreach $member ($fam->each_member) {...
 Function: fetch all the members of the family
 Example :
 Returns : an array of Bio::EnsEMBL::ExternalData::Family::FamilyMember objects (which may be empty)
 Args    : none

=cut

sub each_member {
  my ($self) = @_;
  
  unless (defined $self->{'_members'}) {
    $self->adaptor->_get_each_member($self);
  }
  return @{$self->{'_members'}};
}

=head2 each_member_of_db

 Title   : each_member_of_db
 Usage   : $fam->each_member_of_db('SPTR')
 Function: fetch all the members that belong to a particular database
 Returns : an array of Bio::EnsEMBL::ExternalData::Family::FamilyMember objects (which may be empty)
 Args    : a databasename

=cut

sub each_member_of_db {
  my ($self, $dbname) = @_;

  $self->throw("Should give a defined databasename as argument\n") unless (defined $dbname);

  unless (defined $self->{_members_per_db}->{$dbname}) {
    $self->{_members_per_db}->{$dbname} = [];
    $self->adaptor->_get_each_member($self);
  }
  return @{$self->{_members_per_db}->{$dbname}};
}

=head2 each_member_of_db_taxon

 Title   : each_member_of_db_taxon
 Usage   : $obj->each_member_of_db('ENSEMBLGENE',9606)
 Function: fetch all the members that belong to a particular database and taxon_id
 Returns : an array of Bio::EnsEMBL::ExternalData::Family::FamilyMember objects (which may be empty)
 Args    : a databasename and taxon_id

=cut

sub each_member_of_db_taxon {
  my ($self, $dbname, $taxon_id) = @_;

  $self->throw("Should give defined databasename and taxon_id as arguments\n") unless (defined $dbname && defined $taxon_id);

  unless (defined $self->{_members_per_db_taxon}->{$dbname."_".$taxon_id}) {
    $self->{_members_per_db_taxon}->{$dbname."_".$taxon_id} = [];
    $self->adaptor->_get_each_member($self);
  }
  return @{$self->{_members_per_db_taxon}->{$dbname."_".$taxon_id}};
}

=head2 add_member

 Title   : add_member
 Usage   : 
 Function: adds member to family. 
 Example : $fam->add_member($family_member);
 Returns : undef
 Args    : a Bio::EnsEMBL::ExternalData::Family::FamilyMember object

=cut

sub add_member { 
    my ($self, $member) = @_; 
    
    $member->isa('Bio::EnsEMBL::ExternalData::Family::FamilyMember') ||
      $self->throw("You have to add a Bio::EnsEMBL::ExternalData::Family::FamilyMember object, not a $member");
   
    push @{$self->{_members}}, $member;
    push @{$self->{_members_per_db}{$member->database}}, $member;
    push @{$self->{_members_per_db_taxon}{$member->database."_".$member->taxon_id}}, $member;
}

=head2 get_alignment_string

 Title   : get_alignment_string
 Usage   : $obj->get_alignment_string
 Function: returns a complete clustal alignment as a string
 Example : 
 Returns : complete clustal alignment as a string, or undef if not found
 Args    : none

=cut

sub get_alignment_string {
    my ($self) = @_;
    $self->adaptor->_get_alignment_string($self);
}

=head2 get_alignment

 Title   : get_alignment
 Usage   : $obj->get_alignment
 Function: returns a complete clustal alignment as a Bio::SimpleAlign
 Example : 
 Returns : complete clustal alignment or undef if not found
 Args    : none

=cut

sub get_alignment {
    my ($self) = @_;
    $self->adaptor->_get_alignment($self);
}

1;
