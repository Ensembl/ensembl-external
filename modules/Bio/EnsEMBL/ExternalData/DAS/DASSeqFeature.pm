#
# BioPerl module for Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature
#
# Cared for by Tony Cox <avc@sanger.ac.uk>
#
# Copyright Tony Cox
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature - DAS specific sequence feature.

=head1 SYNOPSIS

    my $feat = new Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature(
						-das_dsn => 'foo',
						-das_name => 'bla',
						-das_id => 'blick',
					    );


=head1 DESCRIPTION

This is an extension of the ensembl Bio::EnsEMBL::SeqFeature.  Extra
methods are to store details of the DAS source used to create this object.
All elements of the DAS 1.01 spec are supported

=head1 CONTACT

avc@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature;
	       		
use vars qw(@ISA $ENSEMBL_EXT_LOADED $ENSEMBL_EXT_USED );
use strict;


use Bio::EnsEMBL::SeqFeature;
use Bio::EnsEMBL::Root;

@ISA = qw(Bio::EnsEMBL::SeqFeature Bio::EnsEMBL::Root);

## Why not use AUTOLOAD?
## Becasue I want to tie the API calls to a version of the DAS spec (1.01)
## Only these calls should be valid for this version of the spec. The call
## names are analogous the the XML tags and their attributes. Autoload
## and you could make any old call....

# The <SEGMENT> tag

sub das_shift {
  my( $self, $shift) = @_;
  $self->{'das_start'}  += $shift;
  $self->{'_gsf_start'} += $shift;
  $self->{'das_end'}    += $shift;
  $self->{'_gsf_end'}   += $shift;
}
sub das_move {
  my( $self, $start, $end, $strand) = @_;
  $self->{'das_start'}   = $start;
  $self->{'_gsf_start'}  = $start;
  $self->{'das_end'}     = $end;
  $self->{'_gsf_end'}    = $end;
  $self->{'das_strand'}  = $strand;
  $self->{'_gsf_strand'} = $strand;
}

sub das_segment{
  my $self = shift;
  if( @_ ){
    my $segment = shift;
    $segment->isa('Bio::Das::Segment') || 
      $self->throw( "Need a Bio::Das::Segment" );
    $self->{'das_segment'} = $segment;
    $self->seqname( $segment->ref );
  }
  return $self->{'das_segment'};
}
sub das_segment_id {
  my $self = shift;
  if( @_ and $_[0]->isa('Bio::Das::Segment') ){
    $self->deprecated( "Use das_segment instead" ); # whs 25/03/2004
    return $self->das_segment(@_);
  }
  $self->deprecated( "Use das_segment->ref instead" );
  return $self->das_segment->ref(@_);
}
sub das_segment_start {
  my $self = shift;
  $self->deprecated( "Use das_segment->start instead" );# whs 25/03/2004
  return $self->das_segment->start(@_);
}
sub das_segment_stop {
  my $self = shift;
  $self->deprecated( "Use das_segment->end instead" ); # whs 25/03/2004
  return $self->das_segment->end(@_);
}
sub das_segment_version {
  my $self = shift;
  $self->deprecated( "Use das_segment->version instead" ); # whs 25/03/2004
  return $self->das_segment->version(@_);
}
sub das_segment_label {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_segment_label'} = $arg;
  }
  return $self->{'das_segment_label'};
}

# The <FEATURE> tag

sub das_feature_id {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_feature_id'} = $arg;
  }
  return $self->{'das_feature_id'};
}
sub das_feature_label {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_feature_label'} = $arg;
  }
  return $self->{'das_feature_label'};
}

# The <TYPE> tag

sub das_type {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_type'} = $arg;
  }
  return $self->{'das_type'};
}

sub das_type_id {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_type_id'} = $arg;
  }
  return $self->{'das_type_id'};
}

sub das_type_category {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_type_category'} = $arg;
  }
  return $self->{'das_type_category'};
}
sub das_type_reference {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_type_reference'} = $arg;
  }
  return $self->{'das_type_reference'};
}
sub das_type_subparts {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_type_subparts'} = $arg;
  }
  return $self->{'das_type_subparts'};
}
sub das_type_superparts {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_type_superparts'} = $arg;
  }
  return $self->{'das_type_superparts'};
}

# The <METHOD> tag

sub das_method {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_method'} = $arg;
  }
  return $self->{'das_method'};
}

sub das_method_id {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_method_id'} = $arg;
  }
  return $self->{'das_method_id'};
}

# The <START> tag

sub das_start {
  my ($self,$arg) = @_;
  if( defined($arg) ) {
    $self->{'das_start'} = $arg;
    $self->{'_gsf_start'} = $arg;
  }
  return $self->{'das_start'};
}

sub start {
  my $self = shift;
  return $self->das_start(@_);
}

# The <END> tag

sub das_end {
  my ($self,$arg) = @_;
  if( defined($arg)) {
    $self->{'das_end'} = $arg;
    $self->{'_gsf_end'} = $arg;
  }
 return  $self->{'das_end'};
}

sub end {
  my $self = shift;
  return $self->das_end(@_);
}

# The <SCORE> tag

sub das_score {
  my ($self,$arg) = @_;

  if (defined $arg){ 
    $arg += 0;    # force a cast of the input into numeric context
    $self->{'das_score'} = $arg;
    $self->{'_gsf_score'} = $arg;
  }
  return $self->{'das_score'};
}

sub score {
  my $self = shift;
  return $self->das_score(@_);
}

# The <ORIENTATION> tag

sub das_orientation {
  my $self = shift;
  if( @_ && defined $_[0] ) {
    my $arg = shift;
    my $ori = $arg eq '+' ? 1 : ( $arg eq '-' ? -1 : $arg );
    $self->{'das_strand'}  = $ori;
    $self->{'_gsf_strand'} = $ori;
  }
  return $self->{'das_strand'};
}

sub das_strand {
  my $self = shift;
  return $self->das_orientation(@_);
}

sub strand {
  my $self = shift;
  return $self->das_orientation(@_);
}

# The <PHASE> tag

sub das_phase {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_phase'} = $arg;
    $self->{'_gsf_phase'} = $arg;
  }
  return $self->{'das_phase'};
}

sub phase {
  my $self = shift;
  return $self->das_phase(@_);
}

# The <NOTE> tag

sub das_note {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_note'} = $arg;
  }
  return $self->{'das_note'};
}

# The <LINK> tag

sub das_link {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_link'} = $arg;
  }
  if (ref($self->{'das_link'}) eq 'ARRAY') {
      return $self->{'das_link'}->[0];
  }
  return $self->{'das_link'};
}

sub das_links {
  my $self = shift;
  if( @_) {
    push @{$self->{'das_link'}}, @_;
  }
  return () if (! defined($self->{'das_link'}));
  return ($self->{'das_link'}) if (ref($self->{'das_link'}) ne 'ARRAY');
  return @{$self->{'das_link'}} ;

}

sub das_link_labels {
  my $self = shift;
  if( @_) {
    push @{$self->{'das_link_label'}}, @_;
  }
  return [] if (! defined($self->{'das_link_label'}));
  return [$self->{'das_link_label'}] if ref($self->{'das_link_label'}) ne 'ARRAY';
  return @{$self->{'das_link_label'}};
}

sub das_link_label {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_link_label'} = $arg;
  }
  return $self->{'das_link_label'};
}

sub das_link_href {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_link_href'} = $arg;
  }
  return $self->{'das_link_href'};
}

# The <GROUP> tag

sub das_group_id {
  my ($self,$arg) = @_;

  if( $arg) {
    $self->{'das_group_id'} = $arg;
  }
  return $self->{'das_group_id'};
}

sub das_group_label {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_group_label'} = $arg;
  }
  return $self->{'das_group_label'};
}

sub das_group_type {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_group_type'} = $arg;
  }
  return $self->{'das_group_type'};
}

sub das_groups {
  my $self = shift;
  if( @_) {
    push @{$self->{'das_group'}}, @_;
  }
  return () if (! defined($self->{'das_group'}));
  return ($self->{'das_group'}) if (ref($self->{'das_group'}) ne 'ARRAY');
  return @{$self->{'das_group'}} ;

}

# The <TARGET> tag

sub das_target {
   my ($self,$arg) = @_;
   if( $arg) {
      $self->{'das_target'} = $arg;
   }
    return $self->{'das_target'};
}
sub das_target_label {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_target_label'} = $arg;
  }
  return $self->{'das_target_label'};
}
sub das_target_id {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_target_id'} = $arg;
  }
  return $self->{'das_target_id'};
}
sub das_target_start {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_target_start'} = $arg;
  }
  return $self->{'das_target_start'};
}
sub das_target_stop {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_target_stop'} = $arg;
  }
  return $self->{'das_target_stop'};
}


#### keep these for backwards compatibility #####

sub das_dsn {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_dsn'} = $arg; 
  }
  return $self->{'das_dsn'};
}

sub das_name {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_name'} = $arg;
  }
  return $self->{'das_name'};
}

sub das_id {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'das_id'} = $arg;
  }
  return $self->{'das_id'};
}

sub id {
  my ($self,$arg) = @_;
  if( $arg) {
    $self->{'_id'} = $arg;
  }
  return $self->{'_id'};
}

=head2 primary_tag

 Title   : primary_tag
 Usage   : $tag = $feat->primary_tag()
           $feat->primary_tag('exon')
 Function: get/set on the primary tag for a feature,
           overriding SeqFeature's read-only method
 Returns : a string 
 Args    : none


=cut

sub primary_tag{
  my ($self,$arg) = @_;

  if( defined($arg)) {
    $self->{'_primary_tag'} = $arg;
  }
  return $self->{'_primary_tag'};
}

=head2 source_tag

 Title   : source_tag
 Usage   : $tag = $feat->source_tag()
           $feat->source_tag('genscan');
 Function: get/set for the source tag for a feature,
           overriding SeqFeature's read-only method
 Returns : a string 
 Args    : none


=cut

sub source_tag{
  my ($self,$arg) = @_;

  if( defined($arg) ) {
    $self->{'_source_tag'} = $arg;
  }

  return $self->{'_source_tag'};
}


1;
