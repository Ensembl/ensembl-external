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
                  -COORDS      => [ 'chromosome:NCBI36, 'uniprot_peptide' ],
                  -LABEL       => 'ASTD transcripts',
                  -DESCRIPTION => 'Transcripts from the ASTD database...',
                  -HOMEPAGE    => 'http://www.ebi.ac.uk/astd',
                  -MAINTAINER  => 'andy.jenkinson@ebi.ac.uk',
                );
  Description: Creates a new Source object representing a DAS source.
  Returntype : Bio::EnsEMBL::ExternalData::DAS::Source
  Exceptions : If the URL, DSN or coords are missing or incorrect
  Caller     : general
  Status     : Stable

=cut
sub new {
  my $class = shift;
  
  my ($rawurl, $dsn, $coords, $title, $desc, $homepage, $maintainer) =
    rearrange(['URL', 'DSN', 'COORDS', 'LABEL', 'DESCRIPTION', 'HOMEPAGE', 'MAINTAINER'], @_);
  
  $rawurl || throw('Source has no configured URL');
  $dsn    || throw('Source has no configured DSN');
  my ($url) = $rawurl =~ m!(.+/das1?/?$)!;
  $url || throw("URL is not of correct format: $rawurl");
  $url =~ s!/$!!; # remove trailing slash
  $coords = [$coords] if ($coords && !ref $coords);
  ($coords && scalar @{ $coords })|| throw("Source '$dsn' has no configured coordinate systems");
  
  my $self = {
    url        => $url,
    dsn        => $dsn,
    label      => $title,
    description=> $desc,
    maintainer => $maintainer,
    homepage   => $homepage,
    coords     => $coords,
  };
  bless $self, $class;
  
  return $self;
}

=head2 url

  Arg [1]    : none
  Description: Accessor for the server URL (excluding DSN)
  Returntype : scalar
  Status     : Stable

=cut
sub url {
  my $self = shift;
  return $self->{url};
}

=head2 dsn

  Arg [1]    : none
  Description: Accessor for the DSN
  Returntype : scalar
  Status     : Stable

=cut
sub dsn {
  my $self = shift;
  return $self->{dsn};
}

=head2 full_url

  Arg [1]    : none
  Description: Accessor for the source URL (including DSN)
  Returntype : scalar
  Status     : Stable

=cut
sub full_url {
  my $self = shift;
  return $self->url . q(/). $self->dsn;
}

=head2 coord_systems

  Arg [1]    : none
  Description: Accessor for the Ensembl coordinate systems supported by the source
  Returntype : arrayref of URIs (e.g. chromosome:NCBI36; ensembl_gene)
  Status     : Stable

=cut
sub coord_systems {
  my $self = shift;
  return $self->{coords};
}

=head2 label

  Arg [1]    : none
  Description: Accessor for the source label/title
  Returntype : scalar
  Status     : Stable

=cut
sub label {
  my $self = shift;
  return $self->{label} || $self->dsn;
}

=head2 description

  Arg [1]    : none
  Description: Accessor for the source description
  Returntype : scalar
  Status     : Stable

=cut
sub description {
  my $self = shift;
  return $self->{description} || $self->label;
}

=head2 maintainer

  Arg [1]    : none
  Description: Accessor for the source maintainer email address
  Returntype : scalar
  Status     : Stable

=cut
sub maintainer {
  my $self = shift;
  return $self->{maintainer};
}

=head2 homepage

  Arg [1]    : none
  Description: Accessor for the source homepage URL
  Returntype : scalar
  Status     : Stable

=cut
sub homepage {
  my $self = shift;
  return $self->{homepage};
}

1;