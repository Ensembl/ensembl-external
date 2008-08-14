=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::Source

=head1 SYNOPSIS

  $src = Bio::EnsEMBL::ExternalData::DAS::Source->new(
    -DSN         => 'astd_exon_human_36',
    -URL         => 'http://www.ebi.ac.uk/das-srv/genomicdas/das',
    -COORDS      => [ 'chromosome:NCBI36, 'uniprot_peptide' ],
    #...etc
  );

=head1 DESCRIPTION

An object representation of a DAS source.

=head1 AUTHOR

Andy Jenkinson <aj@ebi.ac.uk>

=cut
package Bio::EnsEMBL::ExternalData::DAS::Source;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

use base qw(Bio::EnsEMBL::Analysis);

=head1 METHODS

=head2 new

  Arg [..]   : List of named arguments:
               -URL         - The URL (excluding source name) for the source.
               -DSN         - The source name.
               -COORDS      - The coordinate systems supported by the source.
                              This is a single or arrayref of
                              Bio::EnsEMBL::CoordSystem objects.
               -LABEL       - (optional) The display name of the source.
               -DESCRIPTION - (optional) The description of the source.
               -HOMEPAGE    - (optional) A URL link to a page with more
                              information about the source.
               -MAINTAINER  - (optional) A contact email address for the source.
  Example    : $src = Bio::EnsEMBL::ExternalData::DAS::Source->new(
                  -DSN         => 'astd_exon_human_36',
                  -URL         => 'http://www.ebi.ac.uk/das-srv/genomicdas/das',
                  -COORDS      => [ 'chromosome:NCBI36', 'uniprot_peptide' ],
                  -LABEL       => 'ASTD transcripts',
                  -DESCRIPTION => 'Transcripts from the ASTD database...',
                  -HOMEPAGE    => 'http://www.ebi.ac.uk/astd',
                  -MAINTAINER  => 'andy.jenkinson@ebi.ac.uk',
                );
  Description: Creates a new Source object representing a DAS source.
  Returntype : Bio::EnsEMBL::ExternalData::DAS::Source
  Exceptions : If the URL or DSN are missing or incorrect
  Caller     : general
  Status     : Stable

=cut
sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_, );
  
  my ($url, $dsn, $coords, $desc, $homepage, $maintainer) =
    rearrange(['URL', 'DSN', 'COORDS', 'DESCRIPTION', 'HOMEPAGE', 'MAINTAINER'], @_);
  
  $url || throw('Source has no configured URL');
  $dsn || throw('Source has no configured DSN');
  
  $self->url           ( $url ); # Applies some formatting
  $self->dsn           ( $dsn );
  $self->description   ( $desc );
  $self->maintainer    ( $maintainer );
  $self->homepage      ( $homepage );
  $self->coord_systems ( $coords );
  
  if (! $self->display_label ) {
    $self->display_label( $self->dsn );
  }
  
  if (! $self->logic_name ) {
    $self->logic_name( $self->full_url );
  }
  
  if (! $self->homepage ) {
    $self->homepage( $self->full_url );
  }
  
  return $self;
}

=head2 full_url

  Arg [1]    : none
  Description: Getter for the source URL (including DSN)
  Returntype : scalar
  Status     : Stable

=cut
sub full_url {
  my $self = shift;
  return $self->url . q(/). $self->dsn;
}

=head2 url

  Arg [1]    : Optional value to set
  Description: Get/Setter for the server URL (excluding DSN)
  Returntype : scalar
  Status     : Stable

=cut
sub url {
  my ($self, $url) = @_;
  if ( defined $url ) {
    my ($goodurl) = $url =~ m!(.+/das1?/?$)!;
    $goodurl || throw("URL is not of correct format: $url");
    $goodurl =~ s!/$!!; # remove trailing slash
    $self->{url} = $goodurl;
  }
  return $self->{url};
}

=head2 dsn

  Arg [1]    : Optional value to set
  Description: Get/Setter for the DSN
  Returntype : scalar
  Status     : Stable

=cut
sub dsn {
  my ($self, $dsn) = @_;
  if ( defined $dsn ) {
    $self->{dsn} = $dsn;
  }
  return $self->{dsn};
}

=head2 coord_systems

  Arg [1]    : Optional value to set (arrayref or scalar)
  Description: Get/Setter for the Ensembl coordinate systems supported by the source
  Returntype : arrayref of URIs (e.g. chromosome:NCBI36; ensembl_gene)
  Status     : Stable

=cut
sub coord_systems {
  my ($self, $coords) = @_;
  if ( defined $coords ) {
    $coords = [$coords] if (!ref $coords);
    $self->{coords} = $coords;
  }
  return $self->{coords};
}

=head2 description

  Arg [1]    : Optional value to set
  Description: Get/Setter for the source description
  Returntype : scalar
  Status     : Stable

=cut
sub description {
  my ($self, $description) = @_;
  if ( defined $description ) {
    $self->{description} = $description;
  }
  return $self->{description} || $self->display_label;
}

=head2 maintainer

  Arg [1]    : Optional value to set
  Description: Get/Setter for the source maintainer email address
  Returntype : scalar
  Status     : Stable

=cut
sub maintainer {
  my ($self, $maintainer) = @_;
  if ( defined $maintainer ) {
    $self->{maintainer} = $maintainer;
  }
  return $self->{maintainer};
}

=head2 homepage

  Arg [1]    : Optional value to set
  Description: Get/Setter for the source homepage URL
  Returntype : scalar
  Status     : Stable

=cut
sub homepage {
  my ($self, $homepage) = @_;
  if ( defined $homepage ) {
    $self->{homepage} = $homepage;
  }
  return $self->{homepage};
}

# TODO: maybe add style-related properties (for overriding a stylesheet)

1;