=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::Stylesheet

=head1 SYNOPSIS

  # Build a stylesheet object from the DAS response
  $das = Bio::Das::Lite->new($das_source_url);
  
  while ( ($url, $raw) = each %{ $das->stylesheet() } ) {
    $ss = Bio::EnsEMBL::ExternalData::DAS::Stylesheet->new( $raw );
  }
  
  # Find the glyph type for a feature
  $glyphtype = $ss->find_feature_glyph( $feature->type_category,
                                        $feature->type_id        );
  
  # Find the glyph type for a feature group
  $groups = $feature->groups();
  $glyphtype = $ss->find_group_glyph( $groups->[0]->{type_id} );
  
  # Use with ensembl-draw:
  $symboltype = $glyphtype->{'symbol'};
  $symbol = Bio::EnsEMBL::Glyph::Symbol::$symboltype->new( $feature,
                                                           $glyphtype );

=head1 DESCRIPTION

An object representation of a DAS stylesheet, with methods for assigning glyph
types to features.

=cut
package Bio::EnsEMBL::ExternalData::DAS::Stylesheet;

use strict;
use warnings;

####
# Default stylesheets for use when DAS sources do not provide one
#
our $DEFAULT_STYLESHEET = Bio::EnsEMBL::ExternalData::DAS::Stylesheet->new();

our $DEFAULT_GRADIENT = bless {
  'default' => { 'default' => { 'symbol' => 'gradient',
                                'color1' => 'yellow',
                                'color2' => 'green',
                                'color3' => 'blue'      } }
}, 'Bio::EnsEMBL::ExternalData::DAS::Stylesheet';

our $DEFAULT_HISTOGRAM = bless {
  'default' => { 'default' => { 'symbol' => 'histogram',
                                'color1' => 'black'      } }
}, 'Bio::EnsEMBL::ExternalData::DAS::Stylesheet';

our $DEFAULT_TILING = bless {
  'default' => { 'default' => { 'symbol' => 'tiling',
                                'color1' => 'orange'  } }
}, 'Bio::EnsEMBL::ExternalData::DAS::Stylesheet';

=head1 METHODS

=head2 new

  Arg [1]    : raw Bio::Das::Lite data (hashref or single-element arrayref)
  Example    : for $raw ( values %{ $das->stylesheet() } ) {
                 $ss = Bio::EnsEMBL::ExternalData::DAS::Stylesheet->new( $raw );
               }
  Description: Constructs a Stylesheet object from parsed DAS XML
  Returntype : Bio::EnsEMBL::ExternalData::DAS::Stylesheet
  Exceptions : If raw data is not in the correct format
  Caller     : Bio::EnsEMBL::ExternalData::DAS::Coordinator
  
=cut

sub new {
  my $proto = shift;
  my $class = ref $proto || $proto;
  my $self  = bless {}, $class;
  my $raw   = shift;
  if ( !$raw || !ref $raw ) {
    return $self;
  }
  if ( ref $raw eq 'ARRAY' ) {
    $raw = $raw->[0];
  }
  if ( ref $raw ne 'HASH' ) {
    throw('Raw data not in correct format');
  }
  
  # Raw hash is like:
  # {
  #  'category' => [
  #                 'category_id' => 'transcription',
  #                 'type'        => [
  #                                   {
  #                                    'type_id' => 'exon',
  #                                    'glyph'   => [
  #                                                  {
  #                                                   'box' => [
  #                                                             {
  #                                                              'fgcolor' => 'red',
  #                                                              'bgcolor' => 'black'
  #                                                             }
  #                                                            ]
  #                                                  }
  #                                                 ]
  #                                   }
  #                                  ]
  #                ]
  # }
  
  # We simplify hash into:
  # {
  #  'transcription' => {
  #                      'exon' => {
  #                                 'symbol'  => 'box',
  #                                 'fgcolor' => 'red',
  #                                 'bgcolor' => 'black'
  #                                }
  #                     }
  # }
  for my $category ( @{ $raw->{'category'} || [] } ) {
    
    for my $type ( @{ $category->{'type'} || [] } ) {
      #use Data::Dumper; print Dumper($type);
      my $glyph_hash = $type->{'glyph'}->[0];
      my $glyph_type = ( keys %{ $glyph_hash } )[0];
      my $glyph_attr = $glyph_hash->{$glyph_type}->[0];
      $glyph_attr->{'type'} = $glyph_type;
      
      $self->{ $category->{'category_id'} }{ $type->{'type_id'} } = $glyph_attr;
    }
  }
  
  return $self;
}

# Default glyph, returned by find_feature_glyph when there is no matching style data
our $BOX_GLYPH = {
  'symbol'  => 'box',
  'fgcolor' => 'blue',
  'bgcolor' => 'blue'
};

=head2 find_feature_glyph

  Arg [1]    : string category
  Arg [2]    : string type
  Examples   : $glyph = $stylesheet->find_glyph_type( 'transcription', 'exon' );
  Description: Assigns a glyph type given a feature category and type. If a
               match is not found, will return a default box glyph. The result
               is cached for faster subsequent lookups.
  Returntype : A hashref suitable for use with Bio::EnsEMBL::Glyph::Symbol
  Exceptions : none
  Caller     : ensembl-draw modules

=cut

sub find_feature_glyph {
  my ( $self, $category, $type ) = @_;
  # If not found in the tree, expand the tree to include it so that next
  # feature with same type is found faster
  return $self->{$category}{$type} ||= $self->{$category}{'default'} ||
                                       $self->{'default'}{$type    } ||
                                       $self->{'default'}{'default'} ||
                                       $BOX_GLYPH;
}

our $LINE_GLYPH = {
  'symbol'  => 'line',
  'fgcolor' => 'blue',
  'bgcolor' => 'blue'
};

=head2 find_group_glyph

  Arg [1]    : string type
  Examples   : $glyph = $stylesheet->find_glyph_type( 'transcription', 'exon' );
  Description: Assigns a glyph type given a group type. If a match is not found,
               will return a default line glyph. The result is cached for faster
               subsequent lookups.
  Returntype : A hashref suitable for use with Bio::EnsEMBL::Glyph::Symbol
  Exceptions : none
  Caller     : ensembl-draw modules

=cut

sub find_group_glyph {
  my ( $self, $type ) = @_;
  # If not found in the tree, expand the tree to include it so that next
  # feature with same type is found faster
  return $self->{'group'}{$type} ||= $self->{'group'}{'default'} ||
                                     $LINE_GLYPH;
}


1;