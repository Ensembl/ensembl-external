use strict;

package Bio::EnsEMBL::ExternalData::Haplotype::DBAdaptor;

use vars qw(@ISA);
use Bio::EnsEMBL::DBSQL::DBConnection;

@ISA = qw(Bio::EnsEMBL::DBSQL::DBAdaptor);

=head2 get_HaplotypeAdaptor

  Arg [1]    : none
  Example    : $haplotype_adaptor = new Bio::EnsEMBL::HaplotypeAdaptor;
  Description: Retreives a haplotype adaptor
  Returntype : none
  Exceptions : none
  Caller     : EnsWeb, general

=cut

sub get_HaplotypeAdaptor {
  my $self = shift;

  return $self->_get_adaptor(
		'Bio::EnsEMBL::ExternalData::Haplotype::HaplotypeAdaptor');
}

1;
