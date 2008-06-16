package Data::Bio::Text::FeatureParser;

=head1 NAME

Data::Bio::Text::FeatureParser;

=head1 SYNOPSIS

This object parses data supplied by the user and identifies sequence locations for use by other Ensembl objects

=head1 DESCRIPTION

    my $parser = Data::Bio::Text::FeatureParser->new();
      
          $parser->parse($data);

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

=cut

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
use Data::Bio::Text::Feature::DAS;
use Data::Bio::Text::Feature::generic;

#----------------------------------------------------------------------

=head2 new

    Arg [1]   : Ensembl Object 
    Function  : creates a new FeatureParser object
    Returntype: Data::Bio::Text::FeatureParser
    Exceptions: 
    Caller    : 
    Example   : 

=cut

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

#----------------------------------------------------------------------

=head2 current_key

    Arg [1]   :  
    Function  : 
    Returntype: 
    Exceptions: 
    Caller    : 
    Example   : 

=cut

sub current_key {
  my $self = shift;
  $self->{'_current_key'} = shift if @_;
  return $self->{'_current_key'};
}

#----------------------------------------------------------------------

=head2 set_filter

    Arg [1]   :  
    Function  : 
    Returntype: 
    Exceptions: 
    Caller    : 
    Example   : 

=cut

sub set_filter {
  my $self = shift;
  $self->{'filter'} = {
       'chr'    => $_[0] eq 'ALL' ? undef : $_[0],
       'start'  => $_[1],
       'end'    => $_[2],
    }
}


#----------------------------------------------------------------------

=head2 analyse

    Arg [1]   :  
    Function  : Analyses a data string (e.g. from a form input), with the intention of identifying file format and other contents
    Returntype: hash reference 
    Exceptions: 
    Caller    : 
    Example   : 

=cut

sub analyse {
  my ($self, $data) = @_;
  return unless $data;
  my %info;
  foreach my $row ( split '\n', $data ) {
    my @analysis = $self->analyse_row($row);
    if ($analysis[2]) {
      $info{$analysis[0]}{$analysis[1]} = $analysis[2];
    }
    else {
      $info{$analysis[0]} = $analysis[1];
    }
    ## Should we halt the analysis once we have a file format? Will any other useful info appear later in the file?
    last if $analysis[0] eq 'format';
  }
  return \%info;
}

#----------------------------------------------------------------------

=head2 analyse_row

    Arg [1]   :  
    Function  : Parses an individual row of data, i.e. a single feature
    Returntype: 
    Exceptions: 
    Caller    : 
    Example   : 

=cut

sub analyse_row {
  my( $self, $row ) = @_;
  $row =~ s/[\t\r\s]+$//g;

  if( $row =~ /^browser\s+(\w+)\s+(.*)/i ) {
    return ('browser_switches', $1, $2);
  }
  else {
    return unless $row =~ /\d+/g ;
    my @tab_delimited = split /(\t|  +)/, $row;
    my $current_key = $self->{'_current_key'} ;
    if( $tab_delimited[12] eq '.' || $tab_delimited[12] eq '+' || $tab_delimited[12] eq '-' ) {
      if( $tab_delimited[6] =~ /[0-9]/ ) { ## GFF format
        return ('format', 'GFF');     
      } 
      else {         ## GTF format
        return ('format', 'GTF');     
      }
    }
    elsif ( $tab_delimited[14] eq '+' || $tab_delimited[14] eq '-' || $tab_delimited[14] eq '.') { # DAS format accepted by Ensembl
      return ('format', 'DAS');     
    } 
    else {
      my @ws_delimited = split /\s+/, $row;
      if( $ws_delimited[8] =~/^[-+][-+]?$/  ) { ## PSL format
        return ('format', 'PSL');     
      } 
      elsif ($ws_delimited[0] =~/^>/ ) {  ## Simple format (chr/start/end/type
        return ('format', 'generic');     
      } 
      else { ## default format ( BED )
        return ('format', 'BED');     
      }
    } 
  }
}
 
#----------------------------------------------------------------------

=head2 parse

    Arg [1]   :  
    Function  : Parses a data string (e.g. from a form input)
    Returntype: 
    Exceptions: 
    Caller    : 
    Example   : 

=cut

sub parse {
  my ($self, $data, $format) = @_;
  return unless $data;
  if (!$format) {
    my $info = $self->analyse($data);
    $format = $info->{'format'};
  }
  foreach my $row ( split '\n', $data ) {
     $self->parse_row($row, $format);
  }
}

#----------------------------------------------------------------------

=head2 parse_file

    Arg [1]   :  
    Function  : 
    Returntype: 
    Exceptions: 
    Caller    : 
    Example   : 

=cut

sub parse_file {
  my( $self, $file ) = @_;

  while( <$file> ) {
    $self->parse_row( $_ );
  }   
}

#----------------------------------------------------------------------

=head2 parse_URL

    Arg [1]   :  
    Function  : 
    Returntype: 
    Exceptions: 
    Caller    : 
    Example   : 

=cut

use EnsEMBL::Web::SpeciesDefs;

sub species_defs {
  my $self = shift;
  return $self->{'_species_defs'} ||= EnsEMBL::Web::SpeciesDefs->new(); 
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

#----------------------------------------------------------------------

=head2 parse_row

    Arg [1]   :  
    Function  : Parses an individual row of data, i.e. a single feature
    Returntype: 
    Exceptions: 
    Caller    : 
    Example   : 

=cut

sub parse_row {
  my( $self, $row, $format ) = @_;
  $row =~ s/[\t\r\s]+$//g;

  if( $row =~ /^browser\s+(\w+)\s+(.*)/i ) {
    $self->{'browser_switches'}{$1}=$2;     
  } 
  elsif ($row =~ s/^track\s+(.*)$/$1/i) {
    my %config;
    while( $row ne '' ) {
      if( $row =~ s/^(\w+)\s*=\s*"([^"]+)"// ) {  
        my $key   = $1;
        my $value = $2;
        while( $value =~ s/\\$// && $row ne '') {
          if( $row =~ s/^([^"]+)"\s*// ) {
             $value .= "\"$1";
          } else {
            $value .= "\"$row"; 
            $row = '';
          }
        }
        $row =~ s/^\s*//;
        $config{$key} = $value;
      } 
      elsif( $row =~ s/(\w+)\s*=\s*(\S+)\s*// ) {
        $config{$1} = $2;
      } 
      else {
        $row ='';
      }
    }
    my $current_key = $config{'name'} || 'default';
    $self->{'tracks'}{ $current_key } = { 'features' => [], 'config' => \%config };
    $self->{'_current_key'} = $current_key;
  } 
  else {
    return unless $row =~ /\d+/g ;
    my @tab_delimited = split /(\t|  +)/, $row;
    my $current_key = $self->{'_current_key'} ;
    if( $format eq 'GFF' ) {
      $self->store_feature( $current_key, Data::Bio::Text::Feature::GFF->new( \@tab_delimited ) ) 
        if $self->filter($tab_delimited[0],$tab_delimited[6],$tab_delimited[8]);
    } 
    elsif ($format eq 'GTF')  { 
      $self->store_feature( $current_key, Data::Bio::Text::Feature::GTF->new( \@tab_delimited ) ) 
        if $self->filter($tab_delimited[0],$tab_delimited[6],$tab_delimited[8]);
    }
    elsif ($format eq 'DAS' ) { 
      $current_key = $tab_delimited[2] if $current_key eq 'default';
      $self->store_feature( $current_key, Data::Bio::Text::Feature::DAS->new( \@tab_delimited ) ) 
        if $self->filter($tab_delimited[4],$tab_delimited[5],$tab_delimited[6]);
    } 
    else {
      my @ws_delimited = split /\s+/, $row; 
      if ($format eq 'PSL' ) {
      $self->store_feature( $current_key, Data::Bio::Text::Feature::PSL->new( \@ws_delimited ) ) 
        if $self->filter($ws_delimited[13],$ws_delimited[15],$ws_delimited[16]);
      } 
      elsif ($format eq 'BED') {                           
        $current_key = $ws_delimited[3] if $current_key eq 'default';
        $self->store_feature( $current_key, Data::Bio::Text::Feature::BED->new( \@ws_delimited ) ) if
        $self->filter($ws_delimited[0],$ws_delimited[1],$ws_delimited[2]);
      }
      else {
        $self->store_feature( $ws_delimited[4], Data::Bio::Text::Feature::generic->new( \@ws_delimited ) ) 
          if $self->filter($ws_delimited[1],$ws_delimited[2],$ws_delimited[3]);
      } 
    } 
  }
}

#----------------------------------------------------------------------

=head2 

    Arg [1]   :  
    Function  : stores a feature in the parser object
    Returntype: 
    Exceptions: 
    Caller    : 
    Example   : 

=cut

sub store_feature {
  my ( $self, $key, $feature ) = @_;
  push @{$self->{'tracks'}{$key}{'features'}}, $feature;
}

#----------------------------------------------------------------------

=head2 

    Arg [1]   :  
    Function  : 
    Returntype: 
    Exceptions: 
    Caller    : 
    Example   : 

=cut

sub get_all_tracks{$_[0]->{'tracks'}}

#----------------------------------------------------------------------

=head2 

    Arg [1]   :  
    Function  : 
    Returntype: 
    Exceptions: 
    Caller    : 
    Example   : 

=cut

sub fetch_features_by_tracktype{
    my ( $self, $type ) = @_;
    return $self->{'tracks'}{ $type }{'features'} ;
}

#----------------------------------------------------------------------

=head2 

    Arg [1]   :  
    Function  : 
    Returntype: 
    Exceptions: 
    Caller    : 
    Example   : 

=cut

sub filter {
  my ( $self, $chr, $start, $end) = @_;
  return ( ! $self->{'filter'}{'chr'}   || $chr eq 'chr'.$self->{'filter'}{'chr'} 
              || $chr eq $self->{'filter'}{'chr'}   ) &&
         ( ! $self->{'filter'}{'end'}   || $start <= $self->{'filter'}{'end'}   ) &&
         ( ! $self->{'filter'}{'start'} || $end   >= $self->{'filter'}{'start'} )  ;
}

1;
