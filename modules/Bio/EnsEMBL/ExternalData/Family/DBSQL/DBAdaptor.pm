
=head1 NAME - Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor

=head1 SYNOPSIS

    $db = Bio::EnsEMBL::DBSQL::ExternalData::Family::DBAdaptor->new(
								    -user   => 'myusername',
								    -dbname => 'familydb',
								    -host   => 'myhost',
								   );

    $family_adaptor  = $db->get_FamilyAdaptor();
    $familymember_adaptor  = $db->get_FamilyMemberAdaptor();

=head1 DESCRIPTION

This object represents a database that is implemented somehow (you shouldn\'t
care much as long as you can get the object). From the object you can pull
out other objects by their stable identifier, such as Clone (accession number),
Exons, Genes and Transcripts. The clone gives you a DB::Clone object, from
which you can pull out associated genes and features. 

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;

use vars qw(@ISA);
use strict;


use Bio::EnsEMBL::DBSQL::DBConnection;

@ISA = qw( Bio::EnsEMBL::DBSQL::DBConnection );


=head2 get_FamilyAdaptor

    my $family_adaptor = $db->get_FamilyAdaptor;

Returns a B<Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyAdaptor>
object, which is used for reading and writing
B<Bio::EnsEMBL::ExternalData::Family::Family> objects from and to the SQL database.

=cut 

sub get_FamilyAdaptor {
  my ($self) = @_;
  
  return $self->_get_adaptor
    ( "Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyAdaptor" );
}

=head2 get_FamilyMemberAdaptor

    my $familymember_adaptor = $db->get_FamilyMemberAdaptor;

Returns a B<Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyMemberAdaptor>
object, which is used for reading and writing
B<Bio::EnsEMBL::ExternalData::FamilyMember> objects from and to the SQL database.

=cut 

sub get_FamilyMemberAdaptor {
  my ($self) = @_;
  
  return $self->_get_adaptor
    ( "Bio::EnsEMBL::ExternalData::Family::DBSQL::FamilyMemberAdaptor" );
}

=head2 get_TaxonAdaptor

    my $taxon__adaptor = $db->get_TaxonAdaptor;

Returns a B<Bio::EnsEMBL::ExternalData::Family::DBSQL::TaxonAdaptor>
object, which is used for reading and writing
B<Bio::Species> objects from and to the SQL database.

=cut 

sub get_TaxonAdaptor {
  my ($self) = @_;
  
  return $self->_get_adaptor
    ( "Bio::EnsEMBL::ExternalData::Family::DBSQL::TaxonAdaptor" );
}


1;
