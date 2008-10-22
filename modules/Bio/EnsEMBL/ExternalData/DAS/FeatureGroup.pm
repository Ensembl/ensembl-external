#
# EnsEMBL module for Bio::EnsEMBL::ExternalData::DAS::FeatureGroup
#
#

=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::FeatureGroup

=head1 SYNOPSIS

  my $g = Bio::EnsEMBL::ExternalData::DAS::FeatureGroup->new( {
    'group_id'    => 'group1',
    'group_label' => 'Group 1',
    'group_type'  => 'transcript',
    'note'        => [ 'Something interesting' ],
    'link'        => [
                      { 'href' => 'http://...',
                        'txt'  => 'Group Link'  }
                     ],
    'target'      => [
                      { 'target_id'    => 'Seq 1',
                        'target_start' => '400',
                        'target_stop'  => '800'  }
                     ]
  } );
  
  printf "Group ID:     %s\n", $g->display_id();
  printf "Group Label:  %s\n", $g->display_label();
  printf "Group Type:   %s\n", $g->type_label();
  
  for my $l ( @{ $g->links() } ) {
    printf "Group Link:   %s -> %s\n", $l->{'href'}, $l->{'txt'};
  }
  
  for my $n ( @{ $g->notes() } ) {
    printf "Group Note:   %s\n", $n;
  }
  
  for my $t ( @{ $g->targets() } ) {
    printf "Group Target: %s:%s,%s\n", $t->{'target_id'},
                                       $t->{'target_start'},
                                       $t->{'target_stop'};
  }

=head1 DESCRIPTION

An object representation of a DAS feature group.

The constructor is designed to work with the output of the DAS features command,
as obtained from the Bio::Das::Lite module.

=head1 AUTHOR

Andy Jenkinson

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=head1 METHODS

=cut

package Bio::EnsEMBL::ExternalData::DAS::FeatureGroup;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use base qw(Bio::EnsEMBL::Feature);

sub new {
  my $proto = shift;
  my $class = ref $proto || $proto;
  my $raw   = shift;
  
  my $self = {};
  for my $key qw( group_id group_label
                  group_type
                  note link target ) {
    $self->{$key} = $raw->{$key} if exists $raw->{$key};
  }
  
  bless $self, $class;
  return $self;
}

sub display_id {
  my $self = shift;
  return $self->{'group_id'};
}

sub display_label {
  my $self = shift;
  return $self->{'group_label'} || $self->display_id;
}

sub type_label {
  my $self = shift;
  return $self->{'group_type'};
}

# The following are zero-to-many, thus return arrayrefs:

sub notes {
  my $self = shift;
  return $self->{'note'} || [];
}

sub links {
  my $self = shift;
  return $self->{'link'} || [];
}

sub targets {
  my $self = shift;
  return $self->{'target'} || [];
}

1;