# $Id$
#
# Module to handle family members
#
# Cared for by Abel Ureta-Vidal <abel@ebi.ac.uk>
#
# Copyright Abel Ureta-Vidal
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

FamilyMember - DESCRIPTION of Object

=head1 SYNOPSIS

  use Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;

  $famdb = Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor->new(
					     -user   => 'myusername',
                                             -dbname => 'myfamily_db',
                                             -host   => 'myhost',
                                              );

  my $FamilyMemberAdaptor = $famdb->get_FamilyAdaptor;

  my $FamilyMember = $FamilyMemberAdaptor->fetch_by_dbID(1);

=head1 DESCRIPTION

=head1 CONTACT

 Abel Ureta-Vidal <abel@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

# ';  # (pacify emacs).  

# Let the code begin...;

package Bio::EnsEMBL::ExternalData::Family::FamilyMember;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::Object
use Bio::EnsEMBL::Root;
use Bio::Annotation::DBLink;


@ISA = qw(Bio::Annotation::DBLink);

# new() is inherited from Bio::Annotation::DBLink

=head2 adaptor

 Arg [1]    : string $adaptor (optional)
 Example    : my $FamilyMember->adaptor;
 Description: get/set the Adaptor which is used for reading and writing
              the calling object from and to the SQL database.
 Returntype : string
 Exceptions : Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyMemberAdaptor
 Caller     : general

=cut

sub adaptor {
   my ($self, $value) = @_;

   if (defined $value) {
      $self->{'_adaptor'} = $value;
   }

   return $self->{'_adaptor'};
}

=head2 dbID

 Arg [1]    : int $dbID (optional)
 Example    : my $FamilyMember->dbID;
 Description: get/set the database dbID
 Returntype : int
 Exceptions : none
 Caller     : general

=cut

sub dbID {
  my ($self,$value) = @_;

  if( defined $value) {
    $self->{'_dbID'} = $value;
  }

  return $self->{'_dbID'};
}

=head2 family_id

 Arg [1]    : int $family_id (optional)
 Example    : my $FamilyMember->family_id;
 Description: get/set the family_id where the FamilyMember belongs to
 Returntype : int
 Exceptions : none
 Caller     : general

=cut

sub family_id {
  my ($self,$value) = @_;

  if( defined $value) {
    $self->{'_family_id'} = $value;
  }

  return $self->{'_family_id'};
}

=head2 stable_id

 Arg [1]    : string $stable_id (optional)
 Example    : my $FamilyMember->stable_id;
 Description: get/set the FamilyMember stable_id
 Returntype : string
 Exceptions : none
 Caller     : general

=cut

sub stable_id {
   my ($self, $value) = @_;

   if (defined $value) {
      $self->primary_id($value);
   }

   return $self->primary_id;
}

=head2 taxon_id

 Arg [1]    : int $taxon_id (optional)
 Example    : my $FamilyMember->taxon_id;
 Description: get/set the FamilyMember taxon_id
 Returntype : int
 Exceptions : none
 Caller     : general

=cut

sub taxon_id {
    my ($self,$value) = @_;

    if (defined $value) {
	$self->{'_taxon_id'} = $value;
    }

    return $self->{'_taxon_id'};
}

=head2 external_db_id

 Arg [1]    : int $external_db_id (optional)
 Example    : my $FamilyMember->external_db_id;
 Description: get/set the FamilyMember external_db_id
 Returntype : int
 Exceptions : none
 Caller     : general

=cut

sub external_db_id {
    my ($self, $value) = @_;

    if (defined $value) {
      $self->{'_external_db_id'} = $value;
    }
    return $self->{'_external_db_id'};
}

=head2 taxon

 Args       : none
 Example    : my $FamilyMember->taxon;
 Description: get the Taxon object corresponding to a FamilyMember
 Returntype : Bio::EnsEMBL::ExternalData::Family::Taxon
 Exceptions : none
 Caller     : general

=cut

sub taxon {
  my ($self) = @_;

  unless (defined $self->{'_taxon'}) {
    my $taxon_adpator = $self->adaptor->db->get_TaxonAdaptor;
    $self->{'_taxon'} = $taxon_adpator->fetch_by_taxon_id($self->taxon_id);
  }

  return $self->{'_taxon'};
}

1;
