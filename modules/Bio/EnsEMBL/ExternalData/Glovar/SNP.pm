=head1 NAME

Bio::EnsEMBL::ExternalData::Glovar::SNP -
SNP object used for Glovar SNPs

=head1 SYNOPSIS

my $snp = new Bio::EnsEMBL::ExternalData::Glovar::SNP(-start   => 100,
                                                      -end     => 101,
                                                      -strand  => -1,
                                                      -slice   => $slice
                                                     );

=head1 DESCRIPTION

This is a temporary replacement for Bio::EnsEMBL::SNP representing a Glovar SNP
object. It will stay in place until Bio::EnsEMBL::SNP is modernised
(especially, it needs to inherit from Bio::EnsEMBL::Feature).

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 AUTHOR

Patrick Meidl <pm2@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::ExternalData::Glovar::SNP;

use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::Feature;
@ISA = qw(Bio::EnsEMBL::Feature);

=head2 new_fast

  Arg[1]      : Hashref - initial values for the object
  Example     : 
  Description : creates a new Bio::EnsEMBL::ExternalData::Glovar::SNP very
                quickly by blessing a passed hashref into the object. To be
                used by the drawingcode for fast object creation
  Return type : Bio::EnsEMBL::ExternalData::Glovar::SNP
  Exceptions  : none
  Caller      : drawingcode

=cut

sub new_fast {
    my $class = shift;
    my $hashref = shift;
    return bless $hashref, $class;
}

=head2 display_id

  Arg[1]      : (optional) String - Id to set
  Example     : $self->display_id('rs303');
  Description : getter/setter for SNP display ID
  Return type : String
  Exceptions  : none
  Caller      : general

=cut

sub display_id {
    my $self = shift;
    $self->{'display_id'} = shift if (@_);
    return $self->{'display_id'};
}

=head2 display_name

  Arg[1]      : (optional) String - Id to set
  Example     : $self->display_name('rs303');
  Description : alias for display_id
  Return type : String
  Exceptions  : none
  Caller      : general

=cut

sub display_name {
    my $self = shift;
    return $self->display_id(@_);
}

=head2 alleles

  Arg[1]      : (optional) String - Alleles
  Example     : @alleles = split ('|', $self->alleles);
  Description : Returns the a string where all known alleles for this position
                are listed separated by '|' characters
  Return type : String - Alleles separated by '|'
  Exceptions  : none
  Caller      : general

=cut

sub alleles {
    my $self = shift;
    $self->{'alleles'} = shift if (@_);
    if (defined $self->original_strand && $self->original_strand == -1
        && defined $self->reversed && $self->reversed != 1) {             
        my $value = $self->{'alleles'};
        $value =~ tr/ATGCatgc/TACGtagc/;
        $self->{'alleles'} = $value;
        $self->reversed(1);
    }
    return $self->{'alleles'};
}

=head2 add_DBLink

  Arg[1]      : Bio::Annotation::DBLink $link
  Example     : my $link = new Bio::Annotation::DBLink(-database => 'dbSNP rs',
                                                       -primary_id =>'rs303');
                $self->add_DBLink($link);
  Description : adds a link to an external database to the SNP
  Return type : none
  Exceptions  : none
  Caller      : general

=cut

sub add_DBLink{
    my ($self, $link) = @_;
    if( ! $link->isa('Bio::Annotation::DBLink') ) {
        $self->throw("Is not a link object but a [$link]");
    }
    push(@{$self->{'link'}}, $link);
}

=head2 each_DBLink

  Example     : my @dblinks = $self->each_DBLink;
  Description : return all links to external databases for this SNP
  Return type : list of Bio::Annotation::DBLink
  Exceptions  : none
  Caller      : general

=cut

sub each_DBLink{
    my $self = shift;
    return @{$self->{'link'}} if defined $self->{'link'};
}

=head2 AUTOLOAD

  Arg[1]      : (optional) String/Object - attribute to set
  Example     : # setting a attribute
                $self->attr($val);
                # getting the attribute
                $self->attr;
                # undefining an attribute
                $self->attr(undef);
  Description : lazy function generator for getters/setters
  Return type : String/Object
  Exceptions  : none
  Caller      : general

=cut

sub AUTOLOAD {
    my $self = shift;
    my $attr = our $AUTOLOAD;
    $attr =~ s/.*:://;
    return unless $attr =~ /[^A-Z]/;
    no strict 'refs';
    *{$AUTOLOAD} = sub {
        $_[0]->{$attr} = $_[1] if (@_ > 1);
        return $_[0]->{$attr};
    };
    $self->{$attr} = shift if (@_);
    return $self->{$attr};
}

