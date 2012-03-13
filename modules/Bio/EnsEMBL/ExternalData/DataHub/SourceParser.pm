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

use LWP::Simple;

=head1 METHODS

=head2 new

  Arg [..]   : none
  Example    :
  Description: Constructor
  Returntype : Bio::EnsEMBL::ExternalData::DataHub::SourceParser
  Exceptions : If no location is specified
  Caller     : general
  Status     : Under development
  
=cut

sub new {
  my $class = shift;
  my ($timeout, $proxy) = @_;

  ## Needs implementing with better LWP fetching and error handling
  my $self = {
    'timeout' => $timeout,
    'proxy'   => $proxy,
  };

  bless $self, $class;

  return $self;
}

=head2 parse

  Arg [1]    : URL of root directory for config files
  Arg [2]    : arrayref of config file names
  Example    : $parser->parse();
  Description: Contacts the given data hub, fetches each config 
               file and parses the results. Returns an array of 
               datahub sources (see _parse_file_content for details)
  Returntype : arrayref
  Exceptions : 
  Caller     : EnsEMBL::Web::ConfigPacker
  Status     : Under development

=cut


sub parse {
  my ($self, $hub, $files) = @_;

  $hub || ( warn 'No datahub URL specified!' and return );

  my $tracks = [];

  foreach my $file (@{$files||[]}) {
    my $content = get($hub.'/'.$file);
    if ($content) {
      my $track_set = $self->_parse_file_content($content);
      push @$tracks, $track_set if $track_set;
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
  my $config      = {};
  my $tracks      = [];
  my $track_set   = {};
  my $config_done = 0;
  my $new_track   = 0;
  my $i = 0;

  foreach my $line (split(/\n/, $content)) {
    if ($line =~ /^\s*track/) {
      $new_track = 1;
      $config_done = 1 if scalar keys %$config;
    }
    else {
      $new_track = 0;
    }
    $line =~ /(\w+)\s(.+)/;
    my $key = $1;
    my $values = $2;
    if (!$config_done) {
      if ($key =~ /^subGroup/) {
        my @A = split(/\s/, $values);
        $values = {};
        $values->{'name'} = shift @A;
        $values->{'label'} = shift @A;
        $values->{'values'} = [];
        foreach my $pair (@A) {
          my ($k, $v) = split(/=/, $pair);
          push @{$values->{'values'}}, $k;
        }
      }
      elsif ($key !~ /label/i) {
        my @A = split(/\s/, $values);
        if (scalar(@A) > 1) {
          if ($values =~ /=/) {
            $values = {};
            foreach my $pair (@A) {
              my ($k, $v) = split(/=/, $pair);
              $values->{$k} = $v;
            }
          }
          else {
            $values = [@A];
          }
        }
      }
      $config->{$key} = $values;
    }
    else {
      $key =~ s/^\s+//; 
      if ($new_track) {
        $i++;
        $track_set->{$i} = {};
      }
      else {
        if ($values && $values =~ /=/) {
          my @A = split(/\s/, $values);
          $values = {};
          if ($key eq 'type') {
            $values->{'format'} = shift @A;
            $values->{'number'} = shift @A;
          }
          foreach my $pair (@A) {
            my ($k, $v) = split(/=/, $pair);
            $values->{$k} = $v;
          }
        }
      }
      $track_set->{$i}{$key} = $values;
    }
  }
  foreach my $index (sort keys %$track_set) {
    push @$tracks, $track_set->{$index};
  }

  return {'config' => $config, 'tracks' => $tracks};
}

1;
