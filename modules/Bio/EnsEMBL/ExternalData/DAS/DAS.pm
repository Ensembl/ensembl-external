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

use Data::Dumper;
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
  my($class, $adaptor) = @_;
  my $self;
  $self = {};
  bless $self, $class;

  $self->adaptor( $adaptor );
    
  return $self; # success - we hope!
}

#----------------------------------------------------------------------

=head2 adaptor

  Arg [1]   : Bio::EnsEMBL::ExternalData::DAS::DASAdaptor (optional)
  Function  : getter/setter for adaptor attribute
  Returntype: Bio::EnsEMBL::ExternalData::DAS::DASAdaptor
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub adaptor{
  my $key = '_adaptor';
  my $self = shift;
  if( @_ ){ $self->{$key} = shift }
  return $self->{$key};
}


=head2 fetch_dsn_info

  Arg [1]   : none
  Function  : Retrieves a list of DSN objects from registered URL
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub fetch_dsn_info {
  my $self = shift;
  
  my @sources = ();
  my $callback = sub{ 
    my $obj = shift;
    $obj->isa('Bio::Das::DSN') || return;
    my $data = {};
    $data->{url}         = $obj->url;
    $data->{base}        = $obj->base;
    $data->{id}          = $obj->id;
    $data->{dsn}         = $obj->id;
    $data->{name}        = $obj->name;
    $data->{description} = $obj->description;
    $data->{master}      = $obj->master;
    push @sources, $data;
  };
  my $dsn = $self->adaptor->url;
  my $das = $self->adaptor->_db_handle;
  $das->dsn( -dsn=>$dsn, -callback=>$callback );
  return [@sources];
}



=head2 fetch_all_by_DBLink_Container

  Arg [1]   : Bio::Ensembl object that implements get_all_DBLinks method
              (e.g. Bio::Ensembl::Protein, Bio::Ensembl::Gene)
  Arg [2]   : DB name for DBLink (default - swissprot)
  Function  : Basic GeneDAS/ProteinDAS adaptor.
  Returntype: Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature (listref)
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub fetch_all_by_DBLink_Container {
   my $self       = shift;
   my $parent_obj = shift;
   my $id_type    = shift || 'swissprot';
   $id_type = lc( $id_type );

   my $url        = $self->adaptor->url;
   my $dsn        = $self->adaptor->dsn;

   $parent_obj->can('get_all_DBLinks') ||
     $self->throw( "Need a Bio::EnsEMBL obj (eg Translation) that can ".
		   "get_all_DBLinks" );

   my $ensembl_id = '';
   if( $parent_obj->can('stable_id') ){
     $ensembl_id = $parent_obj->stable_id();
   }

   my %ids = ();
   foreach my $xref( @{$parent_obj->get_all_DBLinks} ){
       lc( $xref->dbname ) ne $id_type and next;
       my $id = $xref->display_id || $xref->primary_id;
       $ids{ $id } = $xref;
   }

   my @das_features = ();
   my $callback = sub{
       my $f = shift;
       $f->isa('Bio::Das::Feature') || return;
       my $dsf = Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature->new();
       $dsf->id                ( $ensembl_id );
       $dsf->das_feature_id    ( $f->id() );
       $dsf->das_feature_label ( $f->label() );
       $dsf->das_segment_id    ( $f->segment()->ref );
       $dsf->das_segment_label ( $f->label() );
       $dsf->das_id            ( $f->id() );
       $dsf->das_dsn           ( $dsn );
       $dsf->source_tag        ( $dsn );
       $dsf->primary_tag       ( 'das');
       $dsf->das_type_id       ( $f->type() );
       $dsf->das_type_category ( $f->category() );
       $dsf->das_type_reference( $f->reference() );
       $dsf->das_name          ( $f->id() );
       $dsf->das_method_id     ( $f->method() );
       $dsf->das_link          ( $f->link() );
       $dsf->das_link_label    ( $f->link_label() );
       $dsf->das_group_id      ( $f->group() );
       $dsf->das_group_label   ( $f->group_label() );
       $dsf->das_group_type    ( $f->group_type() );
       $dsf->das_target        ( $f->target() );
       $dsf->das_target_id     ( $f->target_id );
       $dsf->das_target_label  ( $f->target_label );
       $dsf->das_target_start  ( $f->target_start );
       $dsf->das_target_stop   ( $f->target_stop );
       $dsf->das_type          ( $f->type() );
       $dsf->das_method        ( $f->method() );
       $dsf->das_start         ( $f->start() );
       $dsf->das_end           ( $f->end() );
       $dsf->das_score         ( $f->score() );
       $dsf->das_orientation   ( $f->orientation() || 0 );
       $dsf->das_phase         ( $f->phase() );
       $dsf->das_note          ( $f->note() );
        $ENV{'ENSEMBL_DAS_WARN'} && warn "adding feat for $dsn: @{[$f->id]}\n";
        push(@das_features, $dsf);
   };

   $self->adaptor->_db_handle->features
     ( -dsn=>"$url/$dsn", 
       -segment=>[keys %ids], 
       -feature_callback=>$callback );

   my @result_list = grep 
     { 
       $self->_map_DASSeqFeature_to_pep( $ids{$_->das_segment_id}, $_ ) == 1 
     } @das_features;

   my $key = join( '_', $dsn, keys(%ids) );
   return( $key, [@result_list] );
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
    return ( $self->{$KEY}, $self->{"_stylesheet_".$KEY} ) if defined $self->{$KEY};

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
    my( $features, $style ) =  $self->get_Ensembl_SeqFeatures_DAS(
         $chr_name, $chr_start, $chr_end,
         \@fpc_contigs, \@clones, \@raw_contig_names,
         $chr_length );
    my @result_list = grep { $self->_map_DASSeqFeature_to_chr(
	                     $mapper, \%contig_name_hash, 
                             $offset,$length,$db->get_CloneAdaptor, $_ ) == 1
    } @$features;
    return ( ($self->{$KEY} = \@result_list), ($self->{"_stylesheet_".$KEY} = $style) );
}

#----------------------------------------------------------------------

sub _map_DASSeqFeature_to_pep{
  my $self = shift;
  my $dblink = shift || die( "Need a DBLink object" ); 
  my $dsf    = shift || die( "Need a DASSeqFeature object" );

  # Check for 'global' feature - mapping not needed 
  if( $dsf->das_feature_id eq $dsf->das_segment_id ){ return 1 }

  # Check that dblink is map-able
  if( ! $dblink->can( 'get_mapper' ) ){ return 0 }

  # Map
  #warn( $dsf->das_type.":".$dsf->das_start."-".$dsf->das_end );
  my $mapper = $dblink->get_mapper;
  #warn Data::Dumper::Dumper( $mapper );
  my @coords = $mapper->map_coordinates( 'TRANSLATION_ID',
					 $dsf->das_start      || 1, 
					 $dsf->das_end        || 1,
					 1, 'ensembl' );

  #my @coords = $dblink->map_feature( $dsf ); Investigate this method

  @coords = grep{ $_->isa('Bio::EnsEMBL::Mapper::Coordinate') } @coords;
  @coords || return 0;
  $dsf->start( $coords[0]->start );
  $dsf->end( $coords[-1]->end );
  #warn( "Ensembl:".$dsf->start."-".$dsf->end );
  return 1;
}

#----------------------------------------------------------------------

sub _map_DASSeqFeature_to_chr {
    my ($self,$mapper,$contig_hash_ref,$offset,$length,$clone_adaptor,$sf) = @_;

    my $type;
    
    ## Ensembl formac...BAC contigs...Celera Anopheles contigs...Rat contigs...Anopheles contigs...
    my $seqname = $sf->seqname;
    if( $contig_hash_ref->{ $seqname } ) { 
      $type = 'contig';
    } elsif( $seqname =~ /chr(\d+|X|Y|I{1,3}|I?V|[23][LR]|_scaffold_\d+|_\w+\d+)/io || # Hs/Mm/Dm/Ag/Fr/Rn/Ce/Dr
             $seqname =~ /^scaffold_\d+$/io ||                            # Pt
             $seqname =~ /^cb\d{2}\.fpc\d{4}$/io ||                            # Cb
             $seqname =~ /^(6_DR5[12]|[0-2]?[0-9]|Un_\w+|I{1,3}|I?V|X|Y|[23][LR])$/io ) {                # Hs/Mm/Dm/Ag/Rn/Ce
	$type = 'chromosome';
    } elsif( $seqname =~ /ctg\d+|NT_\d+/i) {
	$type = 'fpc';
	# This next Regex is for ensembl mouse denormalised contigs - (avc) do we need these any more?
    } elsif( $seqname =~ /^(\w{1,2}\d+)(\.\d+)?$/i) {
	my $clone;
        eval { $clone = $clone_adaptor->fetch_by_accession($1); };
	#we only use finished clones. finished means there is only
	#one contig on the clone and it has an offset of 1
	# Could we have a method on clone saying "is_finished"?
        if( $@ ) { 
          warn( "DAS CLONE error $@" ); return 0;
        }
        return 0 unless $clone;
	my @contigs = @{$clone->get_all_Contigs};
	if(scalar(@contigs) == 1 && ( $contigs[0]->embl_offset == 1 || $contigs[0]->embl_offset==0) ) {
	    # sneaky. Finished clones have one contig - by setting this as the seqname
	    # the contig remapping will work.
            if( $contig_hash_ref->{$contigs[0]->name} ) {
	      $sf->seqname($contigs[0]->name);
	      $type = 'contig';
            }
	}
    } elsif( $sf->das_type_id() eq '__ERROR__') {
#                    Always push errors even if they aren't wholly within the VC
	$type = 'error';
    } elsif( $seqname eq '') {
	#suspicious
	return 0;
    } else {
	warn ("Got a DAS feature with an unrecognized segment type: >$seqname< >", $sf->das_type_id(), "<\n");
	return 0;
    }

    # now switch on type

    if( $type eq 'contig' ) {
	my( $coord ) = $mapper->map_coordinates_to_assembly
	    ($contig_hash_ref->{ $sf->seqname() }->dbID(), 
	     $sf->das_start, 
	     $sf->das_end, 
	     $sf->das_strand||0 );

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
	my $dbh 	   = $self->adaptor->_db_handle();
	my $dsn 	   = $self->adaptor->dsn();
	my $types 	   = $self->adaptor->types() || [];
	my $url 	   = $self->adaptor->url();

    my $DAS_FEATURES = [];
    my $STYLES = [];
    
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

    my $callback_stylesheet =  sub {
     # return if $_[3] eq 'pending';
      push @$STYLES, {
         'category' => $_[0],
         'type'     => $_[1],
         'zoom'     => $_[2],
         'glyph'    => $_[3],
         'attrs'    => $_[4]
      };
    };
    my $callback =  sub {
        my $f = shift;
        return unless $f->isa('Bio::Das::Feature'); ## Bug in call back code means this is called for wrong DAS types
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
        $CURRENT_FEATURE->das_group_label($f->group_label());
        $CURRENT_FEATURE->das_group_type($f->group_type());
        $CURRENT_FEATURE->das_target($f->target());
        $CURRENT_FEATURE->das_target_id($f->target_id);
        $CURRENT_FEATURE->das_target_label($f->target_label);
        $CURRENT_FEATURE->das_target_start($f->target_start);
        $CURRENT_FEATURE->das_target_stop($f->target_stop);
        $CURRENT_FEATURE->das_type($f->type());
        $CURRENT_FEATURE->das_method($f->method());
        $CURRENT_FEATURE->das_start($f->start());
        $CURRENT_FEATURE->das_end($f->end());
        $CURRENT_FEATURE->das_score($f->score());
        $CURRENT_FEATURE->das_orientation($f->orientation()||0);    
        $CURRENT_FEATURE->das_phase($f->phase());
        $CURRENT_FEATURE->das_note($f->note());


        print STDERR "adding feature for $dsn.... @{[$f->id]}\n";
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

     $response = $dbh->stylesheet(
       -dsn => "$url/$dsn",
       -callback => $callback_stylesheet
     );
    # warn $response;
    # warn( Data::Dumper->Dump( [$STYLES] ) );
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
    # warn $response;
    
    unless ($response->success()){
        print STDERR "DAS fetch for $dsn failed\n";
        print STDERR "XX: ", (join "\nXX:", @{$DAS_FEATURES}),"\n";
        my $CURRENT_FEATURE = new Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature; 
        $CURRENT_FEATURE->das_type_id('__ERROR__'); 
        $CURRENT_FEATURE->das_dsn($dsn); 
        unshift @{$DAS_FEATURES}, $CURRENT_FEATURE; 
        return ($DAS_FEATURES,$STYLES);
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
    return ($DAS_FEATURES,$STYLES);  # _MUST_ return a list here or StaticContig breaks!
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


=head2 forwarded_for

 Title   : forwarded_for
 Usage   : $obj->forwarded_for($ENV{'HTTP_X_FORWARDED_FOR'})
 Function: store a DAS data source URL
 Returns : 
 Args    : none


=cut

sub forwarded_for {
    my ($self,$value) = @_;
    if( defined $value) {
        $self->{'_forwarded_for'} = $value;
    }
    return $self->{'_forwarded_for'};
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
  my $caller = join (", ",(caller(0))[1..2] );
  warn "\033[31m DEPRECATED use adaptor->_db_handle instead: \033[0m $caller"; 
  my $self = shift;
  return $self->adaptor->_db_handle(@_);
}


=head2 _types

 Title   :
 Usage   : DEPRECATED
 Function:
 Example :
 Returns :
 Args    :

=cut


sub _types {
  my $caller = join (", ",(caller(0))[1..2] );
  warn "\033[31m DEPRECATED use adaptor->types instead: \033[0m $caller"; 
  my $self = shift;
  return $self->adaptor->types(@_);
}

=head2 _dsn

 Title   :
 Usage   : DEPRECATED
 Function:
 Example :
 Returns :
 Args    :

=cut


sub _dsn{
    my $caller = join (", ",(caller(0))[1..2] );
    warn "\033[31m DEPRECATED use adaptor->dsn instead: \033[0m $caller"; 
    my $self = shift;
    return $self->adaptor->dsn(@_);
}


=head2 _url

 Title   : 
 Usage   : DEPRECATED
 Function:
 Example :
 Returns :
 Args    :

=cut


sub _url{
    my $caller = join (", ",(caller(0))[1..2] );
    warn "\033[31m DEPRECATED use adaptor->url instead: \033[0m $caller"; 
    my $self = shift;
    return $self->adaptor->url(@_);
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
   $obj->adaptor( undef() );
   if( $obj->{'_db_handle'} ) {
       $obj->{'_db_handle'} = undef;
   }
}




1;
