# Proxy object to adapt TranscriptMapper genomic2pep and pep2genomic methods
# to the core Mapper interface.
# Differences:
#   TranscriptMapper uses different named methods to do conversions rather than
#     having a Mapper per pair of coordinate systems.
#   Transcript Mapper uses slice-relative coordinates...
package Bio::EnsEMBL::ExternalData::DAS::GenomicPeptideMapper;

use strict;
use warnings;
use Bio::EnsEMBL::TranscriptMapper;
use base qw(Bio::EnsEMBL::Mapper);

sub new {
  my ( $proto, $from, $to, $from_cs, $to_cs, $transcript ) = @_;
  my $class = ref $proto || $proto;
  
  my $self = {
    '_mapper' => Bio::EnsEMBL::TranscriptMapper->new( $transcript->transfer($transcript->slice->seq_region_Slice) ),
    'from'    => $from,
    'to'      => $to,
    'from_cs' => $from_cs,
    'to_cs'   => $to_cs,
    'forward' => $to_cs->name eq 'ensembl_peptide',
  };
  bless $self, $class;
  
  $self->{'genomic_id'} = $transcript->slice->seq_region_name;
  $self->{'peptide_id'} = $transcript->translation->stable_id;
  
  return $self;
}

sub map_coordinates {
  my $self = shift;
  
  my (@coords, $out_id);
  if ( ($_[4] eq $self->{'from'}) * $self->{'forward'}) {
    # Query is genomic if:
    #  query is left hand side and left hand side is genomic
    #  query is right hand side and right hand side is genomic
    @coords = $self->{'_mapper'}->genomic2pep(@_[1 .. 3]);
    $out_id = $self->{'peptide_id'};
  } else {
    # Query is peptide if:
    #  query is left hand side and left hand side is peptide
    #  query is right hand side and right hand side is peptide
    @coords = $self->{'_mapper'}->pep2genomic(@_[1 .. 2]);
    $out_id = $self->{'genomic_id'};
  }
  
  for my $c ( @coords ) {
    $c->id( $out_id ) if ($c->isa('Bio::EnsEMBL::Mapper::Coordinate'));
  }
  return @coords;
}

1;