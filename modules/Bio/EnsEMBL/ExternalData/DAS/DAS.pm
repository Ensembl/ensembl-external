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


=head2  fetch_all_by_Slice

  Arg[1]  : Slice 
  Example : $features = $adaptor->fetch_all_by_Slice($slice);
  Description : fetches DAS features for this DAS Adaptor and maps to 
                slice coordinates
  ReturnType: arrayref of Bio::Ensembl::External::DAS::DASSeqFeature
  Exceptions: ?
  Caller  : mainly Slice.pm

=cut

sub fetch_all_by_Slice {
    my ($self,$slice) = @_;

    #
    # IGNORE Caching for now
    #

    my $chr_name   = $slice->chr_name();
    my $chr_start  = $slice->chr_start();
    my $chr_end    = $slice->chr_end();
    my $KEY = "_slice_cache_${chr_name}_${chr_start}_${chr_end}";
    return $self->{$KEY} if defined $self->{$KEY};

    my $chr_length = $slice->get_Chromosome()->length();
    my $offset     = 1 - $chr_start;
    my $length     = $chr_end + $offset;
    my $db         = $slice->adaptor->db;


    my $mapper = $db->get_AssemblyMapperAdaptor()->fetch_by_type($slice->assembly_type());
    my @raw_contig_ids = $mapper->list_contig_ids( $chr_name, $chr_start, $chr_end );
    my $raw_Contig_Hash = $db->get_RawContigAdaptor->fetch_filled_by_dbIDs( @raw_contig_ids );
    my %clone_hash  = map {( $_->clone->embl_id(), 1 ) } values %$raw_Contig_Hash;

    # provide mapping from contig names to internal ids

## The following are used by _map_DASSeqFeature_to_chr and get_Ensembl_SeqFeature_DAS
    my %contig_name_hash = map { ( $_->name(), $_) } values %$raw_Contig_Hash;
    my @fpc_contigs = ();
    my @raw_contig_names = keys %contig_name_hash;
    my @clones = keys %clone_hash; # retrieve all embl clone accessions

    # As DAS features come back from a Call Back system, we need to loop
    # again over the list of features, decide what to do with them and map
    # them all to chromosome coordinates
    my @result_list = grep { $self->_map_DASSeqFeature_to_chr(
	                     $mapper, \%contig_name_hash, 
                             $offset,$length,$db->get_CloneAdaptor, $_ ) == 1
    } @{ $self->get_Ensembl_SeqFeatures_DAS(
         $chr_name, $chr_start, $chr_end,
         \@fpc_contigs, \@clones, \@raw_contig_names,
         $chr_length )
    };
    return $self->{$KEY} = \@result_list;
}


sub _map_DASSeqFeature_to_chr {
    my ($self,$mapper,$contig_hash_ref,$offset,$length,$clone_adaptor,$sf) = @_;

    my $type;
    
    ## Ensembl formac...BAC contigs...Celera Anopheles contigs...Rat contigs...Anopheles contigs...
    my $seqname = $sf->seqname;
    if( $seqname =~ /(scaffold_\d+|(1?[0-9]|X)\.\d+\-\d+|^\w+\.\d+\.\d+.\d+|c\d+\.\d+\.\d+|[23][LR]_\d+|[4XU]_\d+|BAC.*_C)|CRA_.*|RNOR\d+|\w{4}\d+\_\d+/iox ) {
	$type = 'contig';
    } elsif( $seqname =~ /chr(\d+|X|Y|I{1,3}|I?V|[23][LR]|_scaffold_\d+|_\w+\d+)/io || # Hs/Mm/Dm/Ag/Fr/Rn/Ce/Dr
             $seqname =~ /^cb\d{2}\.fpc\d{4}$/io ||                            # Cb
             $seqname =~ /^([0-2]?[0-9]|I{1,3}|I?V|X|Y|[23][LR])$/io ) {                # Hs/Mm/Dm/Ag/Rn/Ce
	$type = 'chromosome';
    } elsif( $seqname =~ /ctg\d+|NT_\d+/i) {
	$type = 'fpc';
	# This next Regex is for ensembl mouse denormalised contigs
    } elsif( $seqname =~ /\w{1,2}\d+/i) {
	my $clone = $clone_adaptor->fetch_by_accession($seqname);
	#we only use finished clones. finished means there is only
	#one contig on the clone and it has an offset of 1
	# Could we have a method on clone saying "is_finished"?
	my @contigs = @{$clone->get_all_Contigs};
	if(scalar(@contigs) == 1 && $contigs[0]->embl_offset == 1) {
	    # sneaky. Finished clones have one contig - by setting this as the seqname
	    # the contig remapping will work.
	    $sf->seqname($contigs[0]->name);
	    $type = 'contig';
	}
    } elsif( $sf->das_type_id() eq '__ERROR__') {
#                    Always push errors even if they aren't wholly within the VC
	$type = 'error';
    } elsif( $seqname eq '') {
	#suspicious
	warn ("Got a DAS feature with an empty seqname! (discarding it)\n");
	return 0;
    } else {
	warn ("Got a DAS feature with an unrecognized segment type: >$seqname< >", $sf->das_type_id(), "<\n");
	return 0;
    }
    #warn( "$type: $seqname" );

    # now switch on type

    if( $type eq 'contig' ) {
	my( $coord ) = $mapper->map_coordinates_to_assembly
	    ($contig_hash_ref->{ $sf->seqname() }->dbID(), 
	     $sf->das_start, 
	     $sf->das_end, 
	     $sf->das_strand );

	# if its not mappable than ignore the feature
	
	if( $coord->isa( "Bio::EnsEMBL::Mapper::Gap" ) ) {
	    return 0;
	}

	$sf->das_move( $coord->{'start'}+$offset, $coord->{'end'}+$offset, $coord->{'strand'} );

	if ( $sf->das_start > $length || $sf->das_end < 1 ) {
	    return 0;
	} else {
	    return 1;
	}

	return 1;

    } elsif( $type eq 'chromosome' ) {
	$sf->das_shift( $offset );
	# trim features off slice
	if ( $sf->das_start > $length || $sf->das_end < 1 ) {
	    return 0;
	} else {
	    return 1;
	}
    } elsif ( $type eq 'error' ) {
	return 1;
    } elsif ( $type eq 'fpc' ) {
	# don't handle FPC's currently
	return 0;
    } else {
	return 0;
    }

    # should not get here. Throw

    $self->throw("Impossible statement reached. Bad DAS SeqFeature coordinate error");
    
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
        $CURRENT_FEATURE->das_link_label($f->link_label());
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
     if($ENV{'ENSEMBL_DAS_WARN'}) { 
           print STDERR "URL/DSN: $url/$dsn\n\n";
           $response = $dbh->features( 
               -dsn        =>  "$ENV{'ENSEMBL_DAS_WARN'}/das/$dsn", 
               -segment    =>  \@seg_requests, 
               -callback   =>  $callback, 
               #-category   =>  'all', 
           ); 
     } 

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
