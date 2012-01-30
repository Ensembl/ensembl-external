package Bio::EnsEMBL::ExternalData::BigFile::BigBedAdaptor;
use strict;

use Data::Dumper;
use Bio::DB::BigFile;
use Bio::DB::BigFile::Constants;
my $DEBUG = 0;


sub new {
  my ($class, $url) = @_;

  my $self = bless {
    _cache => {},
    _url => $url,
  }, $class;
      
  return $self;
}

sub url { return $_[0]->{'_url'} };

sub bigbed_open {
  my $self = shift;

  Bio::DB::BigFile->set_udc_defaults;
  $self->{_cache}->{_bigbed_handle} ||= Bio::DB::BigFile->bigBedFileOpen($self->url);
  return $self->{_cache}->{_bigbed_handle};
}


# UCSC prepend 'chr' on human chr ids. These are in some of the BigBed
# files. This method returns a possibly modified chr_id after
# checking whats in the BigBed file
sub munge_chr_id {
  my ($self, $chr_id) = @_;

  my $ret_id;

  my $bb = $self->bigbed_open;
  warn "Failed to open BigBed file " . $self->url unless $bb;
  return undef unless $bb;

  my $ret_id = $chr_id;

  # Check we get values back for seq region. Maybe need to add 'chr' 
  my $length = $bb->chromSize("$chr_id");

  if (!$length) {
    $length = $bb->chromSize("chr$chr_id");
    if ($length) {
      $ret_id = "chr$chr_id";
    } else {
      warn " *** could not find region $chr_id in BigBed file\n";
      return undef;
    }
  }

  return $ret_id;
}

sub fetch_extended_summary_array  {
  my ($self, $chr_id, $start, $end, $bins) = @_;

  my $bb = $self->bigbed_open;
  warn "Failed to open BigBed file" . $self->url unless $bb;
  return [] unless $bb;
  
  #  Maybe need to add 'chr' 
  my $seq_id = $self->munge_chr_id($chr_id);
  return [] if !defined($seq_id);

# Remember this method takes half-open coords (subtract 1 from start)
  my $summary_e = $bb->bigBedSummaryArrayExtended("$seq_id",$start-1,$end,$bins);

  if ($DEBUG) {
    warn " *** fetch extended summary: $chr_id:$start-$end : found ", scalar(@$summary_e), " summary points\n";
  }
  
  return $summary_e;
}

sub fetch_features  {
  my ($self, $chr_id, $start, $end) = @_;

  my $bb = $self->bigbed_open;
  warn "Failed to open BigBed file" . $self->url unless $bb;
  return [] unless $bb;
  
  #  Maybe need to add 'chr' 
  my $seq_id = $self->munge_chr_id($chr_id);
  return [] if !defined($seq_id);

# Remember this method takes half-open coords (subtract 1 from start)
  my $list_head = $bb->bigBedIntervalQuery("$seq_id",$start-1,$end);

  for (my $i=$list_head->head;$i;$i=$i->next) {
    print STDERR join("\t",$chr_id,$i->start,$i->end,$i->rest),"\n";
  }

  if ($DEBUG) {
    #warn " *** fetch features: $chr_id:$start-$end : found ", scalar(@$list_head), " summary points\n";
  }
  
  return $list_head;
}
1;
