package Bio::EnsEMBL::ExternalData::DAS::Feature;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use base qw(Bio::EnsEMBL::FeaturePair);

sub new {
  my $proto = shift;
  my $class = ref $proto || $proto;
  my $self  = $class->SUPER::new(@_);
  
  ###
  # TODO: rest of properties, e.g. groups!
  ###
  
  my ($type, $links, $notes) = rearrange(['TYPE', 'LINKS', 'NOTES'], @_);
  $self->type ( $type  );
  $self->links( $links );
  $self->notes( $notes );
  return $self;
}

sub type {
  my ( $self, $arg ) = shift;
  if ( defined $arg ) {
    $self->{'type'} = $arg;
  }
  return $self->{'type'};
}

sub notes {
  my ( $self, $arg ) = shift;
  if ( defined $arg ) {
    $self->{'notes'} = $arg;
  }
  return $self->{'notes'};
}

sub links {
  my ( $self, $arg ) = shift;
  if ( defined $arg ) {
    $self->{'links'} = $arg;
  }
  return $self->{'links'};
}

1;