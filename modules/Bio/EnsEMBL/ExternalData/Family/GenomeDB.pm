
#
# Ensembl module for Bio::EnsEMBL::ExternalData::GenomeDB
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::Family::GenomeDB

=head1 SYNOPSIS


=head1 DESCRIPTION

=cut

package Bio::EnsEMBL::ExternalData::Family::GenomeDB;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Root;

@ISA = qw(Bio::EnsEMBL::Root);


sub new {
  my($caller, $dba, $name, $assembly, $taxon_id, $dbID) = @_;

  my $class = ref($caller) || $caller;
  my $self = bless({}, $class);

  $dba      && $self->db_adaptor($dba);
  $name     && $self->name($name);
  $assembly && $self->assembly($assembly);
  $taxon_id && $self->taxon_id($taxon_id);
  $dbID     && $self->dbID($dbID);

  return $self;
}



=head2 db_adaptor

  Arg [1]    : (optional) Bio::EnsEMBL::DBSQL::DBConnection $dba
               The DBAdaptor containing sequence information for the genome
               represented by this object.
  Example    : $gdb->db_adaptor($dba);
  Description: Getter/Setter for the DBAdaptor containing sequence 
               information for the genome represented by this object.
  Returntype : Bio::EnsEMBL::DBSQL::DBConnection
  Exceptions : thrown if the argument is not a
               Bio::EnsEMBL::DBSQL::DBConnection
  Caller     : general

=cut

sub db_adaptor{
  my ( $self, $dba ) = @_;

  if( $dba ) {
    unless(ref $dba && $dba->isa('Bio::EnsEMBL::DBSQL::DBConnection')) {
      $self->throw("dba arg must be a Bio::EnsEMBL::DBSQL::DBConnection" .
		   " not a [$dba]\n");
    }

    $self->{'_db_adaptor'} = $dba;
  }

  return $self->{'_db_adaptor'};
}



=head2 name

  Arg [1]    : (optional) string $value
  Example    : $gdb->name('Homo sapiens');
  Description: Getter setter for the name of this genome database, usually
               just the species name.
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub name{
  my ($self,$value) = @_;

  if( defined $value) {
    $self->{'name'} = $value;
  }

  return $self->{'name'};
}



=head2 dbID

  Arg [1]    : (optional) int $value the new value of this objects database 
               identifier
  Example    : $dbID = $genome_db->dbID;
  Description: Getter/Setter for the internal identifier of this GenomeDB
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub dbID{
   my ($self,$value) = @_;
   if( defined $value) {
     $self->{'dbID'} = $value;
   }
   return $self->{'dbID'};
}


=head2 adaptor

  Arg [1]    : (optional) Bio::EnsEMBL::Compara::GenomeDBAdaptor $adaptor
  Example    : $adaptor = $GenomeDB->adaptor();
  Description: Getter/Setter for the GenomeDB object adaptor used
               by this GenomeDB for database interaction.
  Returntype : Bio::EnsEMBL::Compara::GenomeDBAdaptor
  Exceptions : none
  Caller     : general

=cut

sub adaptor{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'adaptor'} = $value;
   }
   return $self->{'adaptor'};
}


=head2 assembly

  Arg [1]    : (optional) string
  Example    : $gdb->assembly('NCBI_31');
  Description: Getter/Setter for the assembly type of this genome db.
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub assembly {
  my $self = shift;
  my $assembly = shift;

  if($assembly) {
    $self->{'assembly'} = $assembly;
  }

  return $self->{'assembly'};
}



=head2 taxon_id

  Arg [1]    : (optional) int
  Example    : $gdb->taxon_id('9606');
  Description: Getter/Setter for the taxon id of the contained genome db
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub taxon_id {
  my $self = shift;
  my $taxon_id = shift;

  if($taxon_id) {
    $self->{'taxon_id'} = $taxon_id;
  }

  return $self->{'taxon_id'};
}

=head2 has_consensus

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genomedb
  Example    : none
  Description: none
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub has_consensus {
  my ($self,$con_gdb) = @_;

  # sanity check on the GenomeDB passed in
  if( !defined $con_gdb || !$con_gdb->isa("Bio::EnsEMBL::Compara::GenomeDB")) {
    $self->throw("No query genome specified or query is not a GenomeDB obj");
  }
  # and check that you are not trying to compare the same GenomeDB
  if ( $con_gdb eq $self ) {
    $self->throw("Trying to return consensus / " .
		 "query information from the same db");
  }

  my $consensus = $self->adaptor->check_for_consensus_db( $self, $con_gdb);

  return $consensus;
}



=head2 has_query

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genomedb
  Example    : none
  Description: none
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub has_query {
  my ($self,$query_gdb) = @_;

  # sanity check on the GenomeDB passed in
  if( !defined $query_gdb || 
      !$query_gdb->isa("Bio::EnsEMBL::Compara::GenomeDB")) {
    $self->throw("No consensus genome specified or query is not a " .
		 "GenomeDB object");
  }
  # and check that you are not trying to compare the same GenomeDB
  if ( $query_gdb eq $self ) {
    $self->throw("Trying to return consensus / query information " .
		 "from the same db");
  }

  my $query = $self->adaptor->check_for_query_db( $self, $query_gdb );

  return $query;
}



=head2 linked_genomes

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genomedb
  Example    : none
  Description: none
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub linked_genomes {
  my ( $self ) = @_;

  my $links = $self->adaptor->get_all_db_links( $self );

  return $links;
}



1;









