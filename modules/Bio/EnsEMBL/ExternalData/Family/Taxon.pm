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

Taxon - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

 Abel Ureta-Vidal <abel@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# ';  # (pacify emacs).  

# Let the code begin...;

package Bio::EnsEMBL::ExternalData::Family::Taxon;
use vars qw(@ISA);
use strict;
use Bio::Species;

@ISA = qw(Bio::Species);

# new() is inherited from Bio::Species

=head2 adaptor

 Title   : adaptor
 Usage   :
 Function: give the adaptor if known
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
 Function: get/set the dbID (taxon_id) of the taxon
 Example :
 Returns : 
 Args    : 

=cut

sub dbID {
  my ($self,$value) = @_;

  return $self->taxon_id($value);
}

=head2 taxon_id

 Title   : taxon_id
 Usage   : 
 Function: get/set the taxon_id of the taxon
 Example :
 Returns : An integer 
 Args    : 

=cut

sub taxon_id {
    my ($self,$value) = @_;

    if (defined $value) {
	$self->ncbi_taxid($value);
    }

    return $self->ncbi_taxid;
}

1;