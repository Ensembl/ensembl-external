# Proxy object to make IdentityXref mappers play nice with the core Mapper
# interface. Differences:
#   does not use real identifiers for the sequences it is mapping between,
#     it uses 'external_id' and 'ensembl_id' strings
#   names the from/to coordinate systems as 'external' and 'ensembl'.
package Bio::EnsEMBL::ExternalData::DAS::XrefPeptideMapper;

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Mapper);

sub new {
  my ( $proto, $from, $to, $from_cs, $to_cs, $identity_xref, $translation ) = @_;
  
  $identity_xref->can('get_mapper') || throw('Xref does not support mapping');
  
  my $class = ref $proto || $proto;
  my $mapper = $identity_xref->get_mapper;
  my $self = {
    %{ $mapper }
  };
  bless $self, $class;
  
  $self->{'real_from'}    = $from;
  $self->{'real_to'}      = $to;
  $self->{'from_cs'}      = $from_cs;
  $self->{'to_cs'}        = $to_cs;
  $self->{'forward'}      = $to_cs->name eq 'ensembl_peptide';
  
  return $self;
}

sub external_id {
  my ($self, $tmp) = @_;
  if ($tmp) {
    $self->{'external_id'} = $tmp;
  }
  return $self->{'external_id'};
}

sub ensembl_id {
  my ($self, $tmp) = @_;
  if ($tmp) {
    $self->{'ensembl_id'} = $tmp;
  }
  return $self->{'ensembl_id'};
}

sub map_coordinates {
  my $self = shift;
  
  my ($in_id, $out_id, $in_name);
  if ( ($_[4] eq $self->{'real_from'}) * $self->{'forward'} ) {
    $in_id   = 'external_id';
    $in_name = 'external';
    $out_id  = $self->{'ensembl_id'};
  } elsif ( ($_[4] eq $self->{'real_to'}) * $self->{'forward'} ) {
    $in_id   = 'ensembl_id';
    $in_name = 'ensembl';
    $out_id  = $self->{'external_id'};
  } else {
    throw($_[4].' is neither from/to coordinate system');
  }
  
  my @coords = $self->SUPER::map_coordinates( $in_id, @_[1..3], $in_name );
  for my $c ( @coords ) {
    $c->id( $out_id ) if ($c->isa('Bio::EnsEMBL::Mapper::Coordinate'));
  }
  return @coords;
}

1;