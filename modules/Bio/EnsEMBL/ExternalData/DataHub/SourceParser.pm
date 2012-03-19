=head1 NAME

Bio::EnsEMBL::ExternalData::DataHub::SourceParser

=head1 SYNOPSIS


=head1 DESCRIPTION

Parses UCSC-style datahub configuration files for track information

=head1 AUTHOR

Anne Parker <ap5@sanger.ac.uk>

=cut
package Bio::EnsEMBL::ExternalData::DataHub::SourceParser;

use strict;
use warnings;
use vars qw(@EXPORT_OK);
use base qw(Exporter);

use LWP::UserAgent;

=head1 METHODS

=head2 new

  Arg [..]   : none
  Example    :
  Description: Constructor
  Returntype : Bio::EnsEMBL::ExternalData::DataHub::SourceParser
  Exceptions : none 
  Caller     : general
  Status     : Stable 
  
=cut

sub new {
  my ($class, $settings) = @_;

  my $ua = new LWP::UserAgent;
  $ua->timeout( $settings->{'timeout'} );
  $ua->proxy( 'http', $settings->{'proxy'} ) if $settings->{'proxy'};

  my $self = {'ua' => $ua};
  bless $self, $class;

  return $self;
}

=head2 get_hub_info

  Arg [1]    : URL of datahub
  Example    : $parser->get_hub_info();
  Description: Contacts the given data hub, reads the base config file 
              (hub.txt) and from there gets a list of configuration files 
  Returntype : hashref
  Exceptions : 
  Caller     : EnsEMBL::Web::ConfigPacker
  Status     : Under development

=cut

sub get_hub_info {
  my ($self, $url, $settings) = @_;
  my %genome_info;

  my $ua = $self->{'ua'};
  my $response = $ua->get($url.'/hub.txt');
  if (!$response->is_success) {
    return {'error' => $response->status_line};
  }
  else {
    my $hub_file = $response->content;
    my ($genome_filename, $genomes);

    ## Get file name for file with genome info
    foreach (split(/\n/,$hub_file)) {
      next unless $_ =~ /^genomesFile/;
      ($genome_filename = $_) =~ s/genomesFile //;    
    }

    ## Now get genome file and parse
    $response = $ua->get($url.'/'.$genome_filename);
    if (!$response->is_success) {
      return {'error' => $response->status_line};
    }
    else {
      my $genome_file = $response->content;
      foreach (split(/\n/,$genome_file)) {
        my ($k, $v) = split(/\s/, $_);
        ## We only need the values, not the fieldnames
        push @$genomes, $v;
      }
      %genome_info = @$genomes;

      ## Parse list of config files
      my %track_errors;
      while (my($genome, $file) = each(%genome_info)) {
        $response = $ua->get($url.'/'.$file);
        if (!$response->is_success) {
          $track_errors{$file} = $response->status_line;
          next;
        }
        else {
          my $content = $response->content; 
          my @track_list;
          foreach (split(/\n/,$content)) {
            next if (/^#/ || $_ !~ /\w+/);
            (my $filename = $_) =~ s/^include //;
            push @track_list, $filename;
          }
          ## replace trackDb file location with list of track files
          $genome_info{$genome} = \@track_list;
        }
      }
    }
  }
  return \%genome_info;
}

=head2 parse

  Arg [1]    : URL of datahub
  Arg [2]    : Arrayref of config file names
  Example    : $parser->parse();
  Description: Contacts the given data hub, fetches each config 
               file and parses the results. Returns an array of 
               track configurations (see _parse_file_content for details)
  Returntype : arrayref
  Exceptions : 
  Caller     : EnsEMBL::Web::ConfigPacker
  Status     : Under development

=cut


sub parse {
  my ($self, $url, $files) = @_;

  $url || ( warn 'No datahub URL specified!' and return );

  my $ua = $self->{'ua'};
  my $tracks = [];
  my $response;

  ## Get all the text files in the hub directory
  foreach (@$files) {
    my $config_url = $url.'/'.$_;
    $response = $ua->get($config_url);
    if (!$response->is_success) {
      push @$tracks, {'error' => $response->status_line, 'file' => $config_url};
    }
    else {
      my $config = $response->content;
      my $track_set = $self->_parse_file_content($config);
      if ($track_set) {
        (my $desc_url = $config_url) =~ s/txt$/html/;
        $track_set->{'config'}{'description_url'} = $desc_url;
        push @$tracks, $track_set;
      }
    }
  }
  return $tracks;
}

=head2 _parse_file_content

  Arg [1]    : content of a config file, as a string 
  Example    : 
  Description: Parses the contents of a config file into a configuration 
               hash and an array of tracks 
               {'config' => {}, 'tracks' => []}
  Returntype : hashref
  Exceptions : none
  Caller     : &parse
  Status     : Under development

=cut

sub _parse_file_content {
  my ($self, $content) = @_;

  ## First, parse the whole file into track blocks
  my $block;
  my $i = 0;

  foreach my $line (split(/\n/,$content)) {
    my ($key, $info) = ($line =~ /^\s*(\w+)\s(.+)/);
    next unless $key;
    if ($key eq 'track') {
      $i++;
    }
    ## Preserve full value on labels and URLs
    if ($key =~ /label/i || $key eq 'bigDataUrl') {
      $block->{$i}{$key} = $info;
    }
    else {
      my @V = split(/\s/,$info);
      if (scalar(@V) == 1) {
        $block->{$i}{$key} = $info;
      }
      elsif ($key eq 'type') {
        ## Not clear what additional values in this field are for, since
        ## they're not mentioned in UCSC spec - throwing them away for now!
        $block->{$i}{$key} = $V[0];
      }
      else {
        my $values = {};
        if ($key =~ /^subGroup[0-9]+/) {
          $values->{'name'} = shift @V;
          $values->{'label'} = shift @V;
        }
        foreach my $setting (@V) {
          my ($k, $v) = split(/=/,$setting);
          next unless $k;
          $v ||= 1;
          $values->{$k} = $v;
        }
        $block->{$i}{$key} = $values;
      }
    }
  }

  ## Now assemble the blocks into a hierarchical structure
  my $track_set = {};
  my $has_subsets = 0;
  my ($level, $track_name, $subtracks, $has_data);

  foreach my $j (sort keys %$block) {
    my $track_info = $block->{$j};
    $track_name = $track_info->{'track'};
    next unless $track_name;

    ## Identify what level of hierarchy we're at
    if ($track_info->{'bigDataUrl'}) {
      $level = 'data';
      $has_data = 1;
    }
    else {
      if ($track_info->{'parent'}) {
        $level = 'subset';
        $has_subsets = 1;
      }
      else {
        $level = 'set';
      }
    }

    ## Now assign this block a slot in the datastructure
    if ($level eq 'set') {
      $track_set->{'config'} = $track_info;
      $track_set->{'tracks'} = [];
    }
    elsif ($level eq 'subset') {
      $track_set->{'config'}{'subsets'}++;
      my $track_array = [];
      push @{$track_set->{'tracks'}}, {'config' => $track_info, 'tracks' => $track_array};
      $subtracks = $track_array;
    }
    else {
      if ($has_subsets) {
        push @{$subtracks}, $track_info;
      }
      else {
        push @{$track_set->{'tracks'}}, $track_info;
      }
    } 
  }
  return $track_set if $has_data;
}

1;
