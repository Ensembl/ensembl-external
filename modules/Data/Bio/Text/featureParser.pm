package Data::Bio::Text::featureParser;

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
    'filter'		   => { 'chr'	=> $_[0],
							'start' => $_[1],
							'end'	=> $_[2],},
	'URLs'             => [],
    'browser_switches' => {},
    'tracks'           => {}
  };
  bless $data, $class;
  return $data;
}

sub parse_file {
  my $self = shift;
  my $file = shift;
  while (<$file>){
   	$self->parse_row( $_ );
  }   
}

sub parse_URL {
  my $self = shift;
  my $url = shift;
  my $useragent = LWP::UserAgent->new();  
  $useragent->proxy( 'http', $self->species_defs->ENSEMBL_WWW_PROXY ) if( $self->species_defs->ENSEMBL_WWW_PROXY );   
  foreach my $URL ( $url ) {  
    my $request = new HTTP::Request( 'GET', $URL );
    $request->header( 'Pragma' 		  => 'no-cache' );
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
 	my $self = shift;
	my $row = shift;
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
	  $self->{'_current_key'} =  $current_key || 'default';
    } else {
      my @tab_delimited = split /(\t|  +)/, $row;
      my $current_key = $self->{'_current_key'} ;
	  if( $tab_delimited[12] eq '.' || $tab_delimited[12] eq '+' || $tab_delimited[12] eq '-' ) {
        if( $tab_delimited[16] =~ /[ ;]/ ) {
		  return if $self->filter($tab_delimited[0],$tab_delimited[3],$tab_delimited[4]);
		  push @{$self->{'tracks'}{ $current_key }{'features'}}, 					Data::Bio::Text::Feature::GTF->new( \@tab_delimited );
        } elsif ($tab_delimited[5]){
		  return if $self->filter($tab_delimited[0],$tab_delimited[6],$tab_delimited[8]);
		  push @{$self->{'tracks'}{ $current_key }{'features'}}, 					Data::Bio::Text::Feature::GFF->new( \@tab_delimited );
        } else {
		  return if $self->filter($tab_delimited[0],$tab_delimited[1],$tab_delimited[2]);
		  push @{$self->{'tracks'}{ $tab_delimited[3] }{'features'}}, 							Data::Bio::Text::Feature::generic->new( \@tab_delimited );
		}
      } else {
        my @ws_delimited = split /\s+/, $row;
        if( $ws_delimited[8] =~/^[-+][-+]?$/  ) {
		  return if $self->filter($ws_delimited[13],$ws_delimited[15],$ws_delimited[16]);
		  push @{$self->{'tracks'}{ $current_key }{'features'}}, 					Data::Bio::Text::Feature::PSL->new( \@ws_delimited );
		} else {
			$current_key ||= $ws_delimited[3];
		  return if $self->filter($ws_delimited[0],$ws_delimited[1],$ws_delimited[2]);
		  push @{$self->{'tracks'}{ $current_key }{'features'}}, 					Data::Bio::Text::Feature::BED->new( \@ws_delimited );
		}
      } 
	}
}

sub parse {
  my $self = shift;
  my $current_key = 'default';
  foreach my $row ( split '\n', shift ) {
 	$self->parse_row($row);
  }
}

sub get_all_tracks{$_[0]->{'tracks'}}

sub fetch_features_by_tracktype{
	my $self = shift;
	my $type = shift;
	return $self->{'tracks'}{ $type }{'features'} ;
}

sub filter {
	my $self = shift;
	my ($chr, $start, $end) = @_;
	my $filter_chr	  = $self->{'filter'}{'chr'};
	my $filter_start = $self->{'filter'}{'start'};
	my $filter_end   = $self->{'filter'}{'end'};
	return 1 if ( $filter_chr && $chr ne $filter_chr && $filter_chr ne 'ALL');
	return 1 if ( $filter_start && $filter_start < $start  );
	return 1 if ( $filter_end && $filter_end > $end  );
	return 0;
}

1;
