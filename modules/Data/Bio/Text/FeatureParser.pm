package Data::Bio::Text::FeatureParser;

use strict;
use warnings;
no warnings "uninitialized";
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;

use Data::Bio::Text::Feature::BED;
use Data::Bio::Text::Feature::PSL;
use Data::Bio::Text::Feature::GFF;
use Data::Bio::Text::Feature::GTF;
use Data::Bio::Text::Feature::generic;

sub species_defs {
  my $self = shift;
  return $self->{'_species_defs'} ||= SpeciesDefs->new(); 
}

sub new {
  my $class = shift;
  my $data = {
    'filter' => {},
    'URLs'             => [],
    'browser_switches' => {},
    'tracks'           => {},
    '_current_key'     => 'default',
  };
  bless $data, $class;
  return $data;
}

sub current_key {
  my $self = shift;
  $self->{'_current_key'} = shift if @_;
  return $self->{'_current_key'};
}

sub set_filter {
  my $self = shift;
  $self->{'filter'} = {
       'chr'    => $_[0] eq 'ALL' ? undef : $_[0],
       'start'  => $_[1],
       'end'    => $_[2],
    }
}

sub parse_file {
  my( $self, $file ) = @_;

  while( <$file> ) {
    $self->parse_row( $_ );
  }   
}

sub parse_URL {
  my( $self, $url ) = @_;
  my $useragent = LWP::UserAgent->new();  
  $useragent->proxy( 'http', $self->species_defs->ENSEMBL_WWW_PROXY ) if( $self->species_defs->ENSEMBL_WWW_PROXY );   
  foreach my $URL ( $url ) {  
    my $request = new HTTP::Request( 'GET', $URL );
    $request->header( 'Pragma'           => 'no-cache' );
    $request->header( 'Cache-control' => 'no-cache' );
    my $response = $useragent->request($request); 
    if( $response->is_success ) {
      $self->parse( $response->content );
    } else {
       warn( "Failed to parse: $URL" );
    }
  }   
}

sub parse_row {
  my( $self, $row ) = @_;
  $row=~s/[\t\r\s]+$//g;

  if( $row=~/^browser\s+(\w+)\s+(.*)/i ) {
    $self->{'browser_switches'}{$1}=$2;     
  } elsif( $row=~s/^track\s+(.*)$/$1/i ) {
    my %config;
    while( $row ne '' ) {
      if( $row=~s/^(\w+)\s*=\s*"([^"]+)"// ) {  #"
        my $key   = $1;
        my $value = $2;
        while( $value=~s/\\$// && $row ne '') {
          if( $row=~s/^([^"]+)"\s*// ) {
             $value.="\"$1";
          } else {
            $value.="\"$row"; 
            $row='';
          }
        }
        $row=~s/^\s*//;
        $config{$key} = $value;
      } elsif( $row=~s/(\w+)\s*=\s*(\S+)\s*// ) {
        $config{$1} = $2;
      } else {
        $row ='';
      }
    }
    my $current_key = $config{'name'} || 'default';
    $self->{'tracks'}{ $current_key } = { 'features' => [], 'config' => \%config };
    $self->{'_current_key'} = $current_key;
  } else {
    return unless $row =~ /\d+/g ;
    my @tab_delimited = split /(\t|  +)/, $row;
    my $current_key = $self->{'_current_key'} ;
    if( $tab_delimited[12] eq '.' || $tab_delimited[12] eq '+' || $tab_delimited[12] eq '-' ) {
      if( $tab_delimited[16] =~ /[ ;]/ ) { ## GTF format
        $self->store_feature( $current_key, Data::Bio::Text::Feature::GTF->new( \@tab_delimited ) ) if
          $self->filter($tab_delimited[0],$tab_delimited[3],$tab_delimited[4]);
      } elsif ($tab_delimited[5]){         ## GFF format
        $self->store_feature( $current_key, Data::Bio::Text::Feature::GFF->new( \@tab_delimited ) ) if
          $self->filter($tab_delimited[0],$tab_delimited[6],$tab_delimited[8]);
      } else {                             ## Simple format (chr/start/end/type
        $self->store_feature( $tab_delimited[3], Data::Bio::Text::Feature::generic->new( \@tab_delimited ) ) if
          $self->filter($tab_delimited[0],$tab_delimited[1],$tab_delimited[2]);
      }
    } else {
      my @ws_delimited = split /\s+/, $row;
      if( $ws_delimited[8] =~/^[-+][-+]?$/  ) { ## PSL format
        $self->store_feature( $current_key, Data::Bio::Text::Feature::PSL->new( \@ws_delimited ) ) if
          $self->filter($ws_delimited[13],$ws_delimited[15],$ws_delimited[16]);
      } elsif ($ws_delimited[0] =~/^>/ ) {                             ## Simple format (chr/start/end/type
        $self->store_feature( $ws_delimited[4], Data::Bio::Text::Feature::generic->new( \@ws_delimited ) ) if
          $self->filter($ws_delimited[1],$ws_delimited[2],$ws_delimited[3]);
      } else {                                  ## default format ( BED )
        $current_key ||= $ws_delimited[3];
        $self->store_feature( $current_key, Data::Bio::Text::Feature::BED->new( \@ws_delimited ) ) if
          $self->filter($ws_delimited[0],$ws_delimited[1],$ws_delimited[2]);
      }
    } 
  }
}

sub store_feature {
  my ( $self, $key, $feature ) = @_;
  push @{$self->{'tracks'}{$key}{'features'}}, $feature;
}

sub parse {
  my $self = shift ;
  foreach my $row ( split '\n', shift ) {
     $self->parse_row($row);
  }
}

sub get_all_tracks{$_[0]->{'tracks'}}

sub fetch_features_by_tracktype{
    my ( $self, $type ) = @_;
    return $self->{'tracks'}{ $type }{'features'} ;
}

sub filter {
  my ( $self, $chr, $start, $end) = @_;
  return ( ! $self->{'filter'}{'chr'}   || $chr   eq $self->{'filter'}{'chr'}   ) &&
         ( ! $self->{'filter'}{'end'}   || $start <= $self->{'filter'}{'end'}   ) &&
         ( ! $self->{'filter'}{'start'} || $end   >= $self->{'filter'}{'start'} )  ;
}

1;
