
=head1 NAME - Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor

=head1 SYNOPSIS

    $db = Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor->new(
								    -user   => 'myusername',
								    -dbname => 'familydb',
								    -host   => 'myhost',
								   );

    $family_adaptor  = $db->get_FamilyAdaptor;
    $familymember_adaptor  = $db->get_FamilyMemberAdaptor;
    $taxon_adaptor  = $db->get_TaxonAdaptor;

=head1 DESCRIPTION

This object represents a database that is implemented somehow (you shouldn't
care much as long as you can get the object). You can pull
out other objects such as Family, FamilyMember, Taxon through their respective adaptors.

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;

use vars qw(@ISA);
use strict;


use Bio::EnsEMBL::DBSQL::DBConnection;

@ISA = qw( Bio::EnsEMBL::DBSQL::DBConnection );


=head2 get_FamilyAdaptor

 Args       : none
 Example    : my $family_adaptor = $db->get_FamilyAdaptor;
 Description: retrieve the FamilyAdaptor which is used for reading and writing
              Bio::EnsEMBL::ExternalData::Family::Family objects from and to 
              the SQL database.
 Returntype : Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyAdaptor
 Exceptions : none
 Caller     : general

=cut 

sub get_FamilyAdaptor {
  my ($self) = @_;
  
  return $self->_get_adaptor
    ( "Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyAdaptor" );
}

=head2 get_FamilyMemberAdaptor

 Args       : none
 Example    : my $familymember_adaptor = $db->get_FamilyMemberAdaptor;
 Description: retrieve the FamilyMemberAdaptor which is used for reading and writing
              Bio::EnsEMBL::ExternalData::Family::FamilyMember objects from and to 
              the SQL database.
 Returntype : Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyMemberAdaptor
 Exceptions : none
 Caller     : general

=cut 

sub get_FamilyMemberAdaptor {
  my ($self) = @_;
  
  return $self->_get_adaptor
    ( "Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyMemberAdaptor" );
}

=head2 get_TaxonAdaptor

 Args       : none
 Example    : my $taxon__adaptor = $db->get_TaxonAdaptor;
 Description: retrieve the TaxonAdaptor which is used for reading and writing
              Bio::EnsEMBL::ExternalData::Family::Taxon objects from and to 
              the SQL database.
 Returntype : Bio::EnsEMBL::ExternalData::Family::DBSQL::TaxonAdaptor
 Exceptions : none
 Caller     : general

=cut 

sub get_TaxonAdaptor {
  my ($self) = @_;
  
  return $self->_get_adaptor
    ( "Bio::EnsEMBL::ExternalData::Family::DBSQL::TaxonAdaptor" );
}


1;
