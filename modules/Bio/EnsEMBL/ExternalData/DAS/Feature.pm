package Bio::EnsEMBL::ExternalData::DAS::Feature;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use base qw(Bio::EnsEMBL::FeaturePair);

sub new {
  my $proto = shift;
  my $class = ref $proto || $proto;
  
  my ($type, $links, $notes, $groups)
    = rearrange(['TYPE', 'LINKS', 'NOTES', 'GROUPS'], @_);
  
  my $self  = {};#$class->SUPER::new(@_);
  bless $self, $class;
  
  ###
  # TODO: rest of properties
  ###
  

  $self->type  ( $type   );
  $self->links ( $links  );
  $self->notes ( $notes  );
  $self->groups( $groups );
  
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

sub groups {
  my ( $self, $arg ) = shift;
  if ( defined $arg ) {
    $self->{'groups'} = $arg;
  }
  return $self->{'groups'};
}

1;