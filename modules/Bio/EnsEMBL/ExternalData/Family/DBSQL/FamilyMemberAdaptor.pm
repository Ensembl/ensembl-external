# $Id$
# 
# BioPerl module for Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyMemberAdaptor
# 
# Cared by Abel Ureta-Vidal <abel@ebi.ac.uk>
#
# Copyright EnsEMBL
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

FamilyAdaptor - DESCRIPTION of Object

  This object represents a database of protein families.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

=head1 APPENDIX

=cut

package Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyMemberAdaptor;

use vars qw(@ISA);
use strict;

use Bio::Annotation::DBLink;
use Bio::DBLinkContainerI;
use Bio::EnsEMBL::ExternalData::Family::Family;
use Bio::EnsEMBL::ExternalData::Family::DBSQL::BaseAdaptor;

@ISA = qw(Bio::EnsEMBL::ExternalData::Family::DBSQL::BaseAdaptor);

=head2 fetch_by_dbID

 Title   : fetch_by_dbID
 Usage   : $memberadaptor->fetch_by_dbID($id);
 Function: fetches a FamilyMember given its internal database identifier
 Example : $memberadaptor->fetch_by_dbID(1)
 Returns : a Bio::EnsEMBL::ExternalData::Family::FamilyMember object if found, undef otherwise
 Args    : an integer


=cut

sub fetch_by_dbID {
  my ($self,$family_member_id) = @_;
  
  my $q = "SELECT fm.family_id,db.name as dbname,fm.external_member_id as id,fm.taxon_id
           FROM family_members fm,external_db db
           WHERE fm.external_db_id=db.external_db_id and family_member_id = ?";

  $q = $self->prepare($q);
  $q->execute($family_member_id);
  
  if (defined (my $rowhash = $q->fetchrow_hashref)) {
    my $member = new Bio::EnsEMBL::ExternalData::Family::FamilyMember();
    
    $member->adaptor($self);
    $member->dbID($family_member_id);
    $member->family_id($rowhash->{family_id});
    $member->database($rowhash->{dbname});
    $member->stable_id($rowhash->{id});
    $member->taxon_id($rowhash->{taxon_id});
    
    return $member;
  }
  return undef;
}

=head2 fetch_by_stable_id

 Title   : fetch_by_stable_id
 Usage   : $memberadaptor->fetch_by_stable_id($stable_id);
 Function: fetches a FamilyMember given its stable identifier (external_member_id)
 Example : $db->fetch_by_stable_id('ENSG00000000009');
 Returns : a Bio::EnsEMBL::ExternalData::Family::FamilyMember object if found, undef otherwise
 Args    : an EnsEMBL Gene/Peptide stable id (e.g. ENSG00000000009) or an Accession Number (e.g.O35622)

=cut

sub fetch_by_stable_id  {
    my ($self, $stable_id) = @_; 

    my $q = "SELECT family_member_id FROM family_members WHERE external_member_id = '$stable_id'";
    $q = $self->prepare($q);
    $q->execute;
    my ($id) = $q->fetchrow_array;
    $id || $self->throw("Could not find family member for stable id $stable_id");
    $self->fetch_by_dbID($id);
}           

sub fetch_by_family_id {
  my ($self, $family_id) = @_;

  my $q = "SELECT fm.family_member_id, db.name as dbname, fm.external_member_id as id, fm.taxon_id
           FROM family_members fm, external_db db
           WHERE db.external_db_id = fm.external_db_id and fm.family_id = ?";

  $q = $self->prepare($q);
  $q->execute($family_id);
  
  my @members;

  while (defined (my $rowhash = $q->fetchrow_hashref)) {
    my $member = new Bio::EnsEMBL::ExternalData::Family::FamilyMember();

    $member->adaptor($self);
    $member->dbID($rowhash->{family_member_id});
    $member->family_id($family_id);
    $member->database($rowhash->{dbname});
    $member->stable_id($rowhash->{id});
    $member->taxon_id($rowhash->{taxon_id});
    push @members, $member;
  }
  return @members;
}

sub get_external_db_id_by_dbname {
  my ($self, $dbname) = @_;

  my $q = "SELECT external_db_id FROM external_db WHERE name = ?";
  $q = $self->prepare($q);
  $q->execute($dbname);
  my $rowhash = $q->fetchrow_hashref;

  return $rowhash->{external_db_id};
}

=head2 store

 Title   : store
 Usage   : $memberadaptor->store($member)
 Function: Stores a family member object into the database
 Example : $memberadaptor->store($member)
 Returns : $member->dbID
 Args    : An integer (family_id) and a Bio::EnsEMBL::ExternalData::FamilyMember object

=cut

sub store {
  my ($self,$family_id,$member) = @_;

  $member->isa('Bio::EnsEMBL::ExternalData::Family::FamilyMember') ||
    $self->throw("You have to store a Bio::EnsEMBL::ExternalData::Family::FamilyMember object, not a $member");

  my $q = "INSERT INTO family_members (family_id, external_db_id, taxon_id, external_member_id) 
           VALUES (?,?,?,?)";
  my $sth = $self->prepare($q);
  $sth->execute($family_id,$member->external_db_id,$member->taxon_id,$member->primary_id);
  
  $member->dbID( $sth->{'mysql_insertid'} );
  $member->adaptor($self);


  return $member->dbID;
}

1;
