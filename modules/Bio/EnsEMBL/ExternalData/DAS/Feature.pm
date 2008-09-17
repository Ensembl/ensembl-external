package Bio::EnsEMBL::ExternalData::DAS::Feature;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use base qw(Bio::EnsEMBL::Feature);

sub new {
  my $proto = shift;
  my $class = ref $proto || $proto;
  my $raw   = shift;
  
  my $self = {};
  for my $key qw( start end strand
                  feature_id feature_label
                  type type_id
                  score
                  note link group ) {
    $self->{$key} = $raw->{$key} if exists $raw->{$key};
  }
  
  bless $self, $class;
  return $self;
}

sub display_id {
  my $self = shift;
  return $self->{'feature_id'};
}

sub display_label {
  my $self = shift;
  return $self->{'feature_label'} || $self->display_id;
}

sub type {
  my $self = shift;
  return $self->{'type'} || $self->type_id;
}

sub type_id {
  my $self = shift;
  return $self->{'type_id'};
}

sub type_category {
  my $self = shift;
  return $self->{'type_category'};
}

sub score {
  my $self = shift;
  return $self->{'score'};
}

sub notes {
  my $self = shift;
  return $self->{'note'} || [];
}

sub links {
  my $self = shift;
  return $self->{'link'} || [];
}

sub groups {
  my $self = shift;
  return $self->{'group'} || [];
}

1;