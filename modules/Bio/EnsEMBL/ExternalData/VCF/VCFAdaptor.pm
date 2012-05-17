package Bio::EnsEMBL::ExternalData::VCF::VCFAdaptor;
use strict;

use Bio::EnsEMBL::Feature;
use Data::Dumper;
use Vcf;
my $DEBUG = 0;

my $snpCode = {
    'AG' => 'R',
    'GA' => 'R',
    'AC' => 'M',
    'CA' => 'M',
    'AT' => 'W',
    'TA' => 'W',
    'CT' => 'Y',
    'TC' => 'Y',
    'CG' => 'S',
    'GC' => 'S',
    'TG' => 'K',
    'GT' => 'K'
};

sub new {
  my ($class, $url) = @_;
  my $self = bless {
    _cache => {},
    _url => $url,
  }, $class;
      
  return $self;
}

sub url { return $_[0]->{'_url'} };


sub snp_code {
    my ($self, $allele) = @_;
    
    return $snpCode->{$allele};
}


sub fetch_variations {
  my ($self, $chr, $s, $e) = @_;

  delete $self->{_cache}->{features};
  unless ($self->{_cache}->{features}) {
    my @features;
    delete $self->{_cache}->{features};
    foreach my $chr_name ($chr,"chr$chr") { # maybe UCSC-type names?
      my %args = ( 
        region => "$chr_name:$s-$e",
        file => $self->url
      );

      my $vcf = Vcf->new(%args);

      while (my $line=$vcf->next_line()) {
        my $x=$vcf->next_data_hash($line);
        push @features, $x;
      }
      last if(@features);
    }
    $self->{_cache}->{features} = \@features;
  }
  return $self->{_cache}->{features};
}

1;
