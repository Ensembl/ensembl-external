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
use Bio::Root::RootI;

@ISA = qw( Bio::EnsEMBL::SeqFeature  Bio::Root::RootI);

## Why not use AUTOLOAD?
## Becasue I want to tie the API calls to a version of the DAS spec (1.01)
## Only these calls should be valid for this version of the spec. The call
## names are analogous the the XML tags and their attributes. Autoload
## and you could make any old call....

# The <SEGMENT> tag

sub das_segment_id {
   my ($self,$arg) = @_;
   if( $arg) {
      $self->{'das_segment_id'} = $arg;
      # we need to set the feature seqname here so that we can translate
      # raw contig to VC coordinates later. So here we trim the segment name
      # to give the contig ID:
      my ($seqname) = $self->{'das_segment_id'} =~ /(.*?):(\d+)\,(\d+)/;
      $self->seqname($seqname);
      $self->das_segment_start($2);
      $self->das_segment_stop($3);
   }
    return $self->{'das_segment_id'};
}
sub das_segment_start {
   my ($self,$arg) = @_;
   if( $arg) {
      $self->{'das_segment_start'} = $arg;
   }
    return $self->{'das_segment_start'};
}
sub das_segment_stop {
   my ($self,$arg) = @_;
   if( $arg) {
      $self->{'das_segment_stop'} = $arg;
   }
    return $self->{'das_segment_stop'};
}
sub das_segment_version {
   my ($self,$arg) = @_;
   if( $arg) {
      $self->{'das_segment_version'} = $arg;
   }
    return $self->{'das_segment_version'};
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
   if( $arg) {
      $self->{'das_start'} = $arg;
      $self->{'_gsf_start'} = $arg;
   }
   return $self->{'das_start'};
}

sub start {
   my ($self,$arg) = @_;
    return($self->das_start($arg));
}

# The <END> tag

sub das_end {
   my ($self,$arg) = @_;
   if( $arg) {
      $self->{'das_end'} = $arg;
      $self->{'_gsf_end'} = $arg;
   }
   return  $self->{'das_end'};
}

sub end {
   my ($self,$arg) = @_;
    return($self->das_end($arg));
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
   my ($self,$arg) = @_;
    return($self->das_score($arg));
}

# The <ORIENTATION> tag

sub das_orientation {
   my ($self,$arg) = @_;
   #print STDERR "Setting STRAND from $arg ";
   my $ori;
   if ($arg eq "+"){
	   $ori = 1;
   } elsif ($arg eq "-") {	
	   $ori = -1;
   } else {	
	   $ori = $arg;
   }  
   if( $arg) {
      $self->{'das_strand'} = $ori;
      $self->{'_gsf_strand'} = $ori;
      #print STDERR "to $ori\n";
   }
    return $self->{'das_strand'};
}

sub das_strand {
   my ($self,$arg) = @_;
   return($self->das_orientation($arg));
}

sub strand {
   my ($self,$arg) = @_;
   return($self->das_orientation($arg));
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
   my ($self,$arg) = @_;
   return($self->das_phase($arg));
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
    return $self->{'das_link'};
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

# The <TARGET> tag

sub das_target {
   my ($self,$arg) = @_;
   if( $arg) {
      $self->{'das_target'} = $arg;
   }
    return $self->{'das_target'};
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

    if (defined($arg)) {
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

    if (defined($arg)) {
	$self->{'_source_tag'} = $arg;
    }

   return $self->{'_source_tag'};
}


1;
