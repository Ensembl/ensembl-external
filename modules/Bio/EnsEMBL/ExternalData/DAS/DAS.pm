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
  Function  : Basic GeneDAS/ProteinDAS adaptor.
  Returntype: Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature (listref)
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub fetch_all_by_DBLink_Container {
   my $self       = shift;
   my $parent_obj = shift;
   my $id_method  = shift || 'display_id';

   my $id_type    = $self->adaptor->type || 'swissprot';
   my $url        = $self->adaptor->url;
   my $dsn        = $self->adaptor->dsn;

   $parent_obj->can('get_all_DBLinks') || $self->throw( "Need a Bio::EnsEMBL obj (eg Translation) that can get_all_DBLinks" );

   my $ensembl_id = $parent_obj->stable_id() ? $parent_obj->can('stable_id') : '';

   my %ids = ();

   # If $id_type is prefixed with 'ensembl_', then ensembl id type
   if( $id_type =~ m/ensembl_(.+)/o ){
     my $type = $1;
     my @gene_ids;
     my @tscr_ids;
     my @tran_ids;
     if( $parent_obj->isa("Bio::EnsEMBL::Gene") ){
       push( @gene_ids, $parent_obj->stable_id );
       foreach my $tscr( @{$parent_obj->get_all_Transcripts} ){
         push( @tscr_ids, $tscr->stable_id );
         my $tran = $tscr->translation || next;
         push( @tran_ids, $tran->stable_id );
       }
     } elsif( $parent_obj->isa("Bio::EnsEMBL::Transcript" ) ){
       push( @tscr_ids, $parent_obj->stable_id );
       my $tran = $parent_obj->translation || next;
       push( @tran_ids, $tran->stable_id );
     } elsif( $parent_obj->isa("Bio::EnsEMBL::Translation" ) ){
       push( @tran_ids, $parent_obj->stable_id );
     } else{ # Assume protein
       warn( "??? - ", $parent_obj->transcript->translation->stable_id );
       push( @tran_ids, $parent_obj->transcript->translation->stable_id );
     }
     if(   $type eq 'gene'       ){ map{ $ids{$_}='gene'       } @gene_ids }
     elsif($type eq 'transcript' ){ map{ $ids{$_}='transcript' } @tscr_ids }
     elsif($type eq 'peptide'    ){ map{ $ids{$_}='peptide'    } @tran_ids }
   } else { 
       # If no 'ensembl_' prefix, then DBLink ID
       # If $id_type is suffixed with '_acc', use primary_id call 
       # rather than display_id
     my $id_method = $id_type =~ s/_acc$// ? 'primary_id' : 'display_id';
     foreach my $xref( @{$parent_obj->get_all_DBLinks} ){
       lc( $xref->dbname ) ne lc( $id_type ) and next;
       my $id = $xref->$id_method || next;
       $ids{$id} = $xref;
     }
   }

   warn "DAS - $id_type - @{[keys %ids]}";
   # Return empty if no ids found
   if( ! scalar keys(%ids) ){ return( $dsn, [] ) }

   my @das_features = ();
   my $callback = sub{
       my $f = shift;
       $f->isa('Bio::Das::Feature') || return;
       my $dsf = Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature->new();
       $dsf->id                ( $ensembl_id );
       $dsf->das_feature_id    ( $f->id() );
       $dsf->das_feature_label ( $f->label() );
       $dsf->das_segment       ( $f->segment );
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
       my $note = ref($f->note()) eq 'ARRAY' ? join(' ', @{$f->note}) : $f->note;
       $dsf->das_note          ( $note );
       $ENV{'ENSEMBL_DAS_WARN'} && warn "adding feat for $dsn: @{[$f->id]}\n";
        push(@das_features, $dsf);
   };

   #$self->adaptor->_db_handle->debug(1);
   $self->adaptor->_db_handle->features
     ( -dsn=>"$url/$dsn", 
       -segment=>[keys %ids], 
       -feature_callback=>$callback );

   my @result_list = grep 
     {
       $self->_map_DASSeqFeature_to_pep
	 ( $ids{$_->das_segment->ref}, $_ ) == 1
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

  # Examine cache
  my $CACHE_KEY = $slice->name;
  if( $self->{$CACHE_KEY} ){
    return ( $self->{$CACHE_KEY}, $self->{"_stylesheet_$CACHE_KEY"} );
  }

  # Get all coord systems this Ensembl DB knows about
  my $csa = $slice->coord_system->adaptor;
  my %coord_systems = map{ $_->name, $_ } @{ $csa->fetch_all || [] };

  # Get the slice representation for each coord system. 
  my @segments_to_request; # The DAS segments to query
  my %slice_by_segment;    # tally of which slice belongs to segment
  foreach my $system( keys %coord_systems ){
    foreach my $segment( @{ $slice->project($system) || [] } ){
      my $slice = $segment->to_Slice;
      my $slice_name  = $slice->name;
      my $slice_start = $slice->start;
      my $slice_end   = $slice->end;
      my $region_name = $slice->seq_region_name;
      my $coord_system= $slice->coord_system;
      if( $slice_name =~ /^clone/ ){ # Clone-specific hack for embl versions
	my( $id, $version ) = split( /\./, $region_name );
	if( $version ){
	  push( @segments_to_request, "$id:$slice_start,$slice_end" );
	  $slice_by_segment{$id} = $slice;
	}
      }
      push( @segments_to_request, "$region_name:$slice_start,$slice_end" );
      $slice_by_segment{$region_name} = $slice;
    }
  }

  # Run the DAS query
  my( $features, $style ) = $self->get_Ensembl_SeqFeatures_DAS
    ( [ @segments_to_request ] );


  # Map the DAS results into the coord system of the original slice
  my @result_list;
  foreach my $das_sf( @$features ){
    my $segment = $das_sf->das_segment ||
      ( warn( "No das_segment for $das_sf" ) && next );
    my $das_slice = $slice_by_segment{$segment->ref} ||
      ( warn( "No Slice for ", $segment->ref ) && next );
    $self->_map_DASSeqFeature_to_slice( $das_sf, $das_slice, $slice ) &&
      push @result_list, $das_sf;
  }

  # Return the mapped features
  return ( ($self->{$slice->name} = \@result_list), 
	   ($self->{"_stylesheet_".$slice->name} = $style) );
}

#----------------------------------------------------------------------

sub _map_DASSeqFeature_to_pep{
  my $self = shift;
  my $dblink = shift || die( "Need a DBLink object" ); 
  my $dsf    = shift || die( "Need a DASSeqFeature object" );

  if( ! ref( $dblink ) ){ return 1 } # Ensembl id_type - mapping not needed

  # Check for 'global' feature - mapping not needed 
  if( $dsf->das_feature_id eq $dsf->das_segment->ref or
      ! $dsf->das_start or
      ! $dsf->das_end ){
    $dsf->start( 0 );
    $dsf->end( 0 );
    return 1
  }

  # Check that dblink is map-able
  if( ! $dblink->can( 'get_mapper' ) ){ return 0 }

  # Map
  my @coords = ();
  eval{ @coords = $dblink->map_feature( $dsf ) };
  if( $@ ){ warn( $@ ) }

  @coords = grep{ $_->isa('Bio::EnsEMBL::Mapper::Coordinate') } @coords;
  @coords || return 0;
  $dsf->start( $coords[0]->start );
  $dsf->end( $coords[-1]->end );
  #warn( "Ensembl:".$dsf->start."-".$dsf->end );
  return 1;
}

#----------------------------------------------------------------------

=head2 _map_DASSeqFeature_to_slice

  Arg [1]   : DASSeqFeature object
  Arg [2]   : Slice with CoordSystem and seq_region_name for DASSeqFeature
  Arg [3]   : Slice with offsets and CoordSystem to map DASSeqFeature to
  Function  : Maps DASSeqFeature in one CoordSystem to Slice coords in 
              another CoordSystem
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub _map_DASSeqFeature_to_slice {
  my $self       = shift;
  my $das_sf     = shift;
  my $das_slice  = shift;
  my $usr_slice  = shift;

  my $fr_csystem = $das_slice->coord_system;
  my $to_csystem = $usr_slice->coord_system;

  my $db = $usr_slice->adaptor->db;
  my $ma = $db->get_AssemblyMapperAdaptor;

  # Map
  my( $slice_start, $slice_end, $slice_strand );
  unless( $fr_csystem->equals( $to_csystem ) ){
    my $mapper = $ma->fetch_by_CoordSystems( $fr_csystem, $to_csystem );
    my @coords = ();
    eval{ @coords = $mapper->map( $das_slice->seq_region_name, 
				  $das_sf->das_start,
				  $das_sf->das_end,
				  $das_sf->das_orientation,
				  $fr_csystem ) };
    if( $@ ){ warn( $@ ) }
    @coords = grep{ $_->isa('Bio::EnsEMBL::Mapper::Coordinate') } @coords;
    scalar( @coords ) || return 0;
    $slice_start = $coords[0]->start - $usr_slice->start + 1;
    $slice_end   = $coords[-1]->end  - $usr_slice->start + 1;
    $slice_strand= $coords[0]->strand;
  }
  else{ # No mapping needed
    $slice_start = $das_sf->das_start - $usr_slice->start + 1;
    $slice_end   = $das_sf->das_end   - $usr_slice->start + 1;
    $slice_strand= $das_sf->das_orientation;
  }
  $das_sf->seqname( $usr_slice->seq_region_name );
  $das_sf->start ( $slice_start );
  $das_sf->end   ( $slice_end );
  $das_sf->strand( $slice_strand );

  #warn( "Ensembl:".$das_sf->seqname.":".$das_sf->start."-".$das_sf->end );
  return 1;

}

    



=head2 get_Ensembl_SeqFeatures_DAS

 Title   : get_Ensembl_SeqFeatures_DAS ()
 Usage   : get_Ensembl_SeqFeatures_DAS(['AL12345','13']);
 Function:
 Example :
 Returns :
 Args    :
 Notes   : This function sets the primary tag and source tag fields in the
           features so that higher level code can filter them by their type
           (das) and their data source name (dsn)

=cut

sub get_Ensembl_SeqFeatures_DAS {
    my $self = shift;
    my $segments = shift || [];
    my $dbh 	   = $self->adaptor->_db_handle();
    my $dsn 	   = $self->adaptor->dsn();
    my $types 	   = $self->adaptor->types() || [];
    my $url 	   = $self->adaptor->url();
    my $DAS_FEATURES = [];
    my $STYLES = [];
    #$dbh->debug(1); # Useful debug flag

    @$segments || $self->throw("Need some segment IDs to query against");
    my @seg_requests = @$segments;

    my $callback_stylesheet = sub {
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
        my $das_sf = new Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature;
        $das_sf->das_feature_id   ($f->id      );
        $das_sf->das_feature_label($f->label   );
        $das_sf->das_segment      ($f->segment );
        $das_sf->das_segment_label($f->label   );
        $das_sf->das_id($f->id());
        $das_sf->das_dsn($dsn);
        $das_sf->source_tag($dsn);
        $das_sf->primary_tag('das');
        $das_sf->das_type_id($f->type());
        $das_sf->das_type_category($f->category());
        $das_sf->das_type_reference($f->reference());
        #$das_sf->das_type_subparts($attr{'subparts'});
        #$das_sf->das_type_superparts($attr{'superparts'});
        $das_sf->das_name($f->id());
        $das_sf->das_method_id($f->method());
        $das_sf->das_link($f->link());
        $das_sf->das_link_label($f->link_label());
        #$das_sf->das_link_href($f->link());
        $das_sf->das_group_id($f->group());
        $das_sf->das_group_label($f->group_label());
        $das_sf->das_group_type($f->group_type());
        $das_sf->das_target($f->target());
        $das_sf->das_target_id($f->target_id);
        $das_sf->das_target_label($f->target_label);
        $das_sf->das_target_start($f->target_start);
        $das_sf->das_target_stop($f->target_stop);
        $das_sf->das_type($f->type());
        $das_sf->das_method($f->method());
        $das_sf->das_start($f->start());
        $das_sf->das_end($f->end());
        $das_sf->das_score($f->score());
        $das_sf->das_orientation($f->orientation()||0);    
        $das_sf->das_phase($f->phase());
        $das_sf->das_note($f->note());


        0 && warn("adding feature for $dsn.... @{[$f->id]}");
        push(@{$DAS_FEATURES}, $das_sf);
    };

    my $response;
    # Test POST echo server to request debugging
    if( 0 ){ 
           warn "URL/DSN: $url/$dsn";
           $response = $dbh->features(
               -dsn        =>  "$ENV{'ENSEMBL_DAS_WARN'}/das/$dsn", 
               -segment    =>  \@seg_requests, 
               -callback   =>  $callback, 
               #-category   =>  'all', 
           ); 
     } 


#     warn "GRABBING STYLE SHEET FOR $dsn";
     $response = $dbh->stylesheet(
       -dsn => "$url/$dsn",
       -callback => $callback_stylesheet
     );
#     warn $response;
#     warn( Data::Dumper->Dump( [$STYLES] ) );
#     warn "STYLESHEET STORED @{$STYLES}";
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
      #warn Data::Dumper::Dumper( $response );
        $self->warn( "DAS fetch for $url/$dsn failed" );
        #print STDERR "XX: ", (join "\nXX:", @{$DAS_FEATURES}),"\n";
        my $das_sf = new Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature; 
        $das_sf->das_type_id('__ERROR__'); 
        $das_sf->das_dsn($dsn);
        unshift @{$DAS_FEATURES}, $das_sf;
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
    return ($DAS_FEATURES,$STYLES); 
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
