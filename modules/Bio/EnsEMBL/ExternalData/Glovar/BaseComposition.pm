#
# Ensembl module for Bio::EnsEMBL::ExternalData::Glovar::BaseComposition
#
# Cared for by Jody Clements <jc3@sanger.ac.uk>
#
# Copyright EnsEMBL
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::Glovar::BaseComposition - DESCRIPTION of Object

  This object represents the base composition as provided by Glovar

=head1 SYNOPSIS

  $base_comp = new Bio::EnsEMBL::ExternalData::Glovar::BaseComposition
                     ('position'     => 1,
		      'genomic_base' => 'A',
		      'alleles'      => {
					 T => 20,
					 G => 10,
					 A => 0,
					 C => 2
					},
		      );

=head1 DESCRIPTION

  This module holds data describing the base composition for
  each base in the genome that has been covered by the Glovar
  project.

=head1 CONTACT - Jody Clements

Jody Clements <jc3@sanger.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

#Let the code begin...

package Bio::EnsEMBL::ExternalData::Glovar::BaseComposition;

use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::SimpleFeature;
@ISA = qw(Bio::EnsEMBL::SimpleFeature);

sub new_fast {
  my $class = shift;
  my $hashref = shift;

  return bless $hashref, $class;
}

sub new {

  my $invocant = shift;
  my $class = ref($invocant) || $invocant;

  my $self = {'position'     => 0,
	      'genomic_base' => 'undef',
	      'alleles'      => {},
              'ethnicity'    => {},
	      '_gsf_strand'  => 1,
	      @_,
	     };

  bless $self, $class;

  return $self;
}

sub position {
  my ($self,$arg) = @_;

  if(defined $arg){
    $self->{'position'} = $arg;
  }
  return $self->{'position'};
}

sub start {
  my ($self,$arg) = @_;

  $self->position($arg) if(defined $arg);
  return $self->position();
}

sub end {
  my ($self,$arg) = @_;

  $self->position($arg) if(defined $arg);
  return $self->position();
}

sub genomic_base {
  my ($self, $arg) = @_;
  $self->{'genomic_base'} = $arg if (defined $arg);

  return $self->{'genomic_base'};
}

sub alleles {
  my($self,$arg) = @_;
  $self->{'alleles'} = $arg if(defined $arg);

  return $self->{'alleles'};
}

sub ethnicity {
  my ($self, $arg) = @_;
  $self->{'ethnicity'} = $arg if (defined $arg);
  return $self->{'ethnicity'};
}

1;








