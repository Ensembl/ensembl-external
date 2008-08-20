package Bio::EnsEMBL::ExternalData::DAS::CoordSystem;

use Bio::EnsEMBL::Utils::Argument  qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

# This object does NOT inherit from Bio::EnsEMBL::CoordSystem, because DAS
# coordinate systems are not storable.

=head2 new

  Arg [..]   : List of named arguments:
               -NAME      - The name of the coordinate system
               -VERSION   - (optional) The version of the coordinate system.
                            Note that if the version passed in is undefined,
                            it will be set to the empty string in the
                            resulting CoordSystem object.
  Example    : $cs = Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new(
                 -NAME    => 'chromosome',
                 -VERSION => 'NCBI33'
               );
  Description: Creates a new CoordSystem object representing a coordinate
               system.
  Returntype : Bio::EnsEMBL::ExternalData::DAS::CoordSystem
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
  my $caller = shift;
  my $class = ref($caller) || $caller;
  my ($name, $version, $species) = rearrange(['NAME','VERSION','SPECIES'], @_);

  $name    || throw('The NAME argument is required');
  $version ||= '';
  $species ||= '';
  
  my $self = {
              'name'    => $name,
              'version' => $version,
              'species' => $species,
             };
  bless $self, $class;

  return $self;
}

=head2 name

  Arg [1]    : (optional) string $name
  Example    : print $coord_system->name();
  Description: Getter for the name of this coordinate system
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub name {
  my $self = shift;
  return $self->{'name'};
}

=head2 version

  Arg [1]    : none
  Example    : print $coord->version();
  Description: Getter for the version of this coordinate system.  This
               will return an empty string if no version is defined for this
               coordinate system.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub version {
  my $self = shift;
  return $self->{'version'};
}

=head2 species

  Arg [1]    : none
  Example    : print $coord->species();
  Description: Getter for the species of this coordinate system.  This
               will return an empty string if no species is defined for this
               coordinate system (i.e. it is not species-specific).
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub species {
  my $self = shift;
  return $self->{'species'};
}


=head2 equals

  Arg [1]    : Bio::EnsEMBL::CoordSystem
               OR
               Bio::EnsEMBL::ExternalData::DAS::CoordSystem
               The coord system to compare to for equality.
  Example    : if($coord_sys->equals($other_coord_sys)) { ... }
  Description: Compares 2 coordinate systems and returns true if they are
               equivalent.  The definition of equivalent is sharing the same
               name, version and species. If either coordinate system has no
               species (i.e. is not species-specific) and they are otherwise
               equivalent, the coordinate systems match.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub equals {
  my $self = shift;
  my $cs = shift;

  if (! ($cs && ref($cs) && ( $cs->isa('Bio::EnsEMBL::CoordSystem') || $cs->isa('Bio::EnsEMBL::ExternalData::DAS::CoordSystem') ) ) ) {
    throw('Argument must be a Bio::EnsEMBL::CoordSystem or ');
  }

  if ($self->{'version'} eq $cs->version() && $self->{'name'} eq $cs->name()) {
    if (my $me_species = $self->{'species'}) {
      if (my $cs_species = $cs->isa('Bio::EnsEMBL::CoordSystem') ? $cs->adaptor->species() : $cs->species()) {
        return $me_species eq $cs_species ? 1 : 0;
      }
    }
    return 1;
  }

  return 0;
}



1;