# BioPerl module for DAS
#
# Cared for by Tony Cox <avc@sanger.ac.uk>
#
# Copyright Tony Cox
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

DAS - DESCRIPTION of Object

=head1 SYNOPSIS

use Bio::EnsEMBL::ExternalData::DAS::DASAdaptor;
use Bio::EnsEMBL::ExternalData::DAS::DAS;

$das_adaptor = Bio::EnsEMBL::ExternalData::DAS::DASdaptor->new(
                                             -url   => 'some_server',
                                             -dsn   => 'twiddly-bits',
                                             -ensdb => $ensembl_dbh,
                                            );

my $ext_das = Bio::EnsEMBL::ExternalData::DAS::DAS->new($das_adaptor)

$dbobj->add_ExternalFeatureFactory($ext_das);

This class implements only contig based method:

$dbobj->get_Ensembl_SeqFeatures_contig('AL035659.00001');

Also
my @features = $ext_das->fetch_SeqFeature_by_contig_id("AL035659.00001");

Method get_Ensembl_SeqFeatures_clone returns an empty list.

=head1 DESCRIPTION

Interface to an external DAS data source - lovelingly mangled into the Ensembl database
adaptor scheme.

interface for creating L<Bio::EnsEMBL::ExternalData::DAS::DAS.pm>
objects from an external DAS database. 

The objects returned in a list are
L<Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature> objects which might possibly contain
L<Bio::Annotation::DBLink> objects to give unique IDs in various
DAS databases.

=head1 CONTACT

 Tony Cox <avc@sanger.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::EnsEMBL::ExternalData::DAS::DAS;

use strict;
use vars qw(@ISA);
use Bio::Das; 
use Bio::EnsEMBL::Root;

use Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature;

# Object preamble
@ISA = qw(Bio::EnsEMBL::Root);


sub new {
	my($class,$adaptor) = @_;
	my $self;
	$self = {};
	bless $self, $class;

	$self->_db_handle($adaptor->_db_handle());
    $self->_dsn($adaptor->dsn()); 
    $self->_types($adaptor->types()); 
    $self->_url($adaptor->url()); 

	return $self; # success - we hope!
}


=head2 get_Ensembl_SeqFeatures_DAS

 Title   : get_Ensembl_SeqFeatures_DAS ()
 Usage   : get_Ensembl_SeqFeatures_DAS($chr, $chr_start, $chr_end, $fpccontig_list_ref, $clone_list_ref, $contig_list_ref );
 Function:
 Example :
 Returns :
 Args    :
 Notes   : This function sets the primary tag and source tag fields in the
           features so that higher level code can filter them by their type
           (das) and their data source name (dsn)

=cut

sub get_Ensembl_SeqFeatures_DAS {
    my ($self, $chr_name, $global_start, $global_end, $fpccontig_list_ref, $clone_list_ref, $contig_list_ref, $chr_length) = @_;
	my $dbh 	   = $self->_db_handle();
	my $dsn 	   = $self->_dsn();
	my $types 	   = $self->_types() || [];
	my $url 	   = $self->_url();

    my $DAS_FEATURES = [];
    
    $self->throw("Must give get_Ensembl_SeqFeatures_DAS a chr, global start, global end and other essential stuff. You didn't.")
        unless ( scalar(@_) == 8);

    my @seg_requests = (
                        @$fpccontig_list_ref,
                        @$clone_list_ref, 
                        @$contig_list_ref
                        );
    if($global_end>0 && $global_start<=$chr_length) { # Make sure that we are grabbing a valid section of chromosome...
        $global_start = 1           if $global_start<1;           # Convert start to 1 if non +ve
        $global_end   = $chr_length if $global_end  >$chr_length; # Convert end to chr_length if fallen off end
        #unshift @seg_requests, "chr$chr_name:$global_start,$global_end"; 
        unshift @seg_requests, "$chr_name:$global_start,$global_end";  # support both types of chr ID
    }

    my $callback =  sub {
        my $f = shift;
        my $CURRENT_FEATURE = new Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature;

        $CURRENT_FEATURE->das_feature_id($f->id());
        $CURRENT_FEATURE->das_feature_label($f->label());
        $CURRENT_FEATURE->das_segment_id($f->segment());
        $CURRENT_FEATURE->das_segment_label($f->label());
        $CURRENT_FEATURE->das_id($f->id());
        $CURRENT_FEATURE->das_dsn($dsn);
        $CURRENT_FEATURE->source_tag($dsn);
        $CURRENT_FEATURE->primary_tag('das');
        $CURRENT_FEATURE->das_type_id($f->type());
        $CURRENT_FEATURE->das_type_category($f->category());
        $CURRENT_FEATURE->das_type_reference($f->reference());
        #$CURRENT_FEATURE->das_type_subparts($attr{'subparts'});
        #$CURRENT_FEATURE->das_type_superparts($attr{'superparts'});
        $CURRENT_FEATURE->das_name($f->id());
        $CURRENT_FEATURE->das_method_id($f->method());
        $CURRENT_FEATURE->das_link($f->link());
        #$CURRENT_FEATURE->das_link_href($f->link());
        $CURRENT_FEATURE->das_group_id($f->group());
        #$CURRENT_FEATURE->das_group_label($f->group_label());
        #$CURRENT_FEATURE->das_group_type($attr{'type'});
        $CURRENT_FEATURE->das_target($f->target());
        $CURRENT_FEATURE->das_target_id($f->target());
        #$CURRENT_FEATURE->das_target_start($attr{'start'});
        #$CURRENT_FEATURE->das_target_stop($attr{'stop'});
        $CURRENT_FEATURE->das_type($f->type());
        $CURRENT_FEATURE->das_method($f->method());
        $CURRENT_FEATURE->das_start($f->start());
        $CURRENT_FEATURE->das_end($f->end());
        $CURRENT_FEATURE->das_score($f->score());
        $CURRENT_FEATURE->das_orientation($f->orientation());    
        $CURRENT_FEATURE->das_phase($f->phase());
        $CURRENT_FEATURE->das_note($f->note());

        #print STDERR "adding feature for $dsn....\n";
        push(@{$DAS_FEATURES}, $CURRENT_FEATURE);
    };

    my $response;
	
     # Test POST echo server to request debugging
     print STDERR "URL/DSN: $url/$dsn\n\n";
  #   $response = $dbh->features(
  #                    -dsn    =>  "http://ecs3.internal.sanger.ac.uk:4001/das/$dsn",
  #                    -segment    =>  \@seg_requests,
  #                    -callback   =>  $callback,
  #                    -type   =>  $types,
  #   );

#    if($url=~/servlet\.sanger/) {
#        my $CURRENT_FEATURE = new Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature; 
#        $CURRENT_FEATURE->das_type_id('__ERROR__'); 
#        $CURRENT_FEATURE->id("Hardware failure");
#        $CURRENT_FEATURE->das_dsn($dsn); 
#        unshift @{$DAS_FEATURES}, $CURRENT_FEATURE; 
#        return ($DAS_FEATURES);
#    }
     if(@$types) {
        $response = $dbh->features(
                    -dsn    =>  "$url/$dsn",
                    -segment    =>  \@seg_requests,
                    -callback   =>  $callback,
                    -type   => $types,
        );
     } else {
        $response = $dbh->features(
                    -dsn    =>  "$url/$dsn",
                    -segment    =>  \@seg_requests,
                    -callback   =>  $callback,
        );
     }
    
    unless ($response->success()){
        print STDERR "DAS fetch for $dsn failed\n";
        print STDERR "XX: ", (join "\nXX:", @{$DAS_FEATURES}),"\n";
        my $CURRENT_FEATURE = new Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature; 
        $CURRENT_FEATURE->das_type_id('__ERROR__'); 
        $CURRENT_FEATURE->das_dsn($dsn); 
        unshift @{$DAS_FEATURES}, $CURRENT_FEATURE; 
        return ($DAS_FEATURES);
    }
    
    if(0){
        foreach my $feature (@{$DAS_FEATURES}){
            print STDERR "SEG ID: ",            $feature->seqname(), "\t";
            print STDERR "DSN: ",               $feature->das_dsn(), "\t";
            print STDERR "FEATURE START: ",     $feature->das_start(), "\t";
            print STDERR "FEATURE END: ",       $feature->das_end(), "\t";
            print STDERR "FEATURE STRAND: ",    $feature->das_strand(), "\t";
            print STDERR "FEATURE TYPE: ",      $feature->das_type_id(), "\t";
            print STDERR "FEATURE ID: ",        $feature->das_feature_id(), "\n";
        }
    }
    
	return($DAS_FEATURES);  # _MUST_ return a list here or StaticContig breaks!
}



=head2 get_Ensembl_SeqFeatures_clone

 Title   : get_Ensembl_SeqFeatures_clone (not used)
 Function:
 Example :
 Returns :
 Args    :

=cut

sub get_Ensembl_SeqFeatures_clone{
    my ($self,$contig) = @_;
	$self->throw("get_Ensembl_SeqFeatures_clone is unimplemented!");
 	my @features = ();
	return(@features);
}

=head2 fetch_SeqFeature_by_contig_id

 Title   : fetch_SeqFeature_by_contig_id
 Usage   : $obj->fetch_SeqFeature_by_contig_id("Contig_X")
 Function: return DAS features for a contig
 Returns : 
 Args    : none


=cut

sub fetch_SeqFeature_by_contig_id {
    my ($self,$contig) = @_;
	$self->throw("fetch_SeqFeature_by_contig_id is unimplemented!");
 	my @features = ();
	return(@features);
}


=head2 _db_handle

 Title   : _db_handle
 Usage   : $obj->_db_handle($newval)
 Function:
 Example :
 Returns : value of _db_handle
 Args    : newvalue (optional)

=cut


sub _db_handle{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'_db_handle'} = $value;
    }
    return $self->{'_db_handle'};

}


=head2 _types

 Title   : _types
 Usage   : $obj->_types($newval)
 Function:
 Example :
 Returns : value of _types
 Args    : newvalue [ 'type', 'type', ... ] (optional)

=cut


sub _types {
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'_types'} = $value;
    }
    return $self->{'_types'};

}

=head2 _dsn

 Title   : _dsn
 Usage   : $obj->_dsn($newval)
 Function:
 Example :
 Returns : value of _dsn
 Args    : newvalue (optional)

=cut


sub _dsn{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'_dsn'} = $value;
    }
    return $self->{'_dsn'};

}


=head2 _url

 Title   : _url
 Usage   : $obj->_url($newval)
 Function:
 Example :
 Returns : value of _url
 Args    : newvalue (optional)

=cut


sub _url{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'_url'} = $value;
    }
    return $self->{'_url'};

}


=head2 DESTROY

 Title   : DESTROY
 Usage   :
 Function:
 Example :
 Returns :
 Args    :


=cut


sub DESTROY {
   my ($obj) = @_;

   if( $obj->{'_db_handle'} ) {
       $obj->{'_db_handle'} = undef;
   }
}




1;
