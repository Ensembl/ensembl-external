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

=head1 DESCRIPTION

=head1 CONTACT

 Abel Ureta-Vidal <abel@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# ';  # (pacify emacs).  

# Let the code begin...;

package Bio::EnsEMBL::ExternalData::Family::FamilyMember;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::Object
use Bio::EnsEMBL::Root;
use Bio::DBLinkContainerI;
use Bio::Annotation::DBLink;


@ISA = qw(Bio::Annotation::DBLink);

# new() is inherited from Bio::Annotation::DBLink

=head2 adaptor

 Title   : adaptor
 Usage   :
 Function: give this genes FamilyMemberAdaptor if known
 Example :
 Returns :
 Args    :


=cut

sub adaptor {
   my ($self, $value) = @_;

   if (defined $value) {
      $self->{'_adaptor'} = $value;
   }

   return $self->{'_adaptor'};
}

=head2 dbID

 Title   : dbID
 Usage   : 
 Function: get/set the dbID of the FamilyMember
 Example :
 Returns : 
 Args    : 

=cut

sub dbID {
  my ($self,$value) = @_;

  if( defined $value) {
    $self->{'_dbID'} = $value;
  }

  return $self->{'_dbID'};
}

=head2 family_id

 Title   : family_id
 Usage   : 
 Function: get/set the family_id of the FamilyMember
 Example :
 Returns : 
 Args    : 

=cut

sub family_id {
  my ($self,$value) = @_;

  if( defined $value) {
    $self->{'_family_id'} = $value;
  }

  return $self->{'_family_id'};
}

=head2 stable_id

 Title   : stable_id
 Usage   :
 Function: 
 Example :
 Returns :
 Args    :


=cut

sub stable_id {
   my ($self, $value) = @_;

   if (defined $value) {
      $self->primary_id($value);
   }

   return $self->primary_id;
}

=head2 taxon_id

 Title   : taxon_id
 Usage   : 
 Function: get/set the taxon_id of the family member
 Example :
 Returns : An integer 
 Args    : 

=cut

sub taxon_id {
    my ($self,$value) = @_;

    if (defined $value) {
	$self->{'_taxon_id'} = $value;
    }

    return $self->{'_taxon_id'};
}

=head2 external_db_id

 Title   : external_db_id
 Usage   : 
 Function: get/set the external_id of the family member
 Example :
 Returns : An integer 
 Args    : 

=cut

sub external_db_id {
    my ($self,$value) = @_;

    unless (defined $value) {
      $self->{'_external_db_id'} = $self->adaptor->get_external_db_id_by_dbname($self->database);
    }
    return $self->{'_external_db_id'};
}

=head2 taxon

 Title   : taxon
 Usage   : 
 Function: get the Bio::Taxon object of the family member
 Example :
 Returns : An Bio::EnsEMBL:ExternalData::Family::Taxon object 
 Args    : 

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
