
#
# BioPerl module for Bio::EnsEMBL::ExternalData::ESTSQL::EstAdaptor
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME


=head1 SYNOPSIS

   

=head1 DESCRIPTION



=head1 FEEDBACK

=head2 Mailing Lists

=head1 AUTHOR

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::ExternalData::ESTSQL::EstAdaptor;

use Bio::EnsEMBL::DB::ExternalFeatureFactoryI;
use Bio::EnsEMBL::FeaturePair;
use Bio::EnsEMBL::SeqFeature;
use Bio::EnsEMBL::FeatureFactory;
use Bio::EnsEMBL::DBSQL::AnalysisAdaptor;
use Bio::EnsEMBL::Utils::Eprof qw( eprof_start eprof_end);
use Bio::Root::RootI;
use vars qw(@ISA);

@ISA = qw(Bio::Root::RootI Bio::EnsEMBL::DB::ExternalFeatureFactoryI);

my $NO_EXTERNAL = 1;
BEGIN {
        eval {
	    require EnsemblExt;
        };
        if( $@ ) {
           $NO_EXTERNAL = 1;
        } else {
           $NO_EXTERNAL = 0;
        }
};


sub new {
    my($class,$db) = @_;
    my $self;
    $self = {};
    bless $self, $class;
    if( ! defined $db ) {
      $self->throw( "Cant make adaptor without dbadaptor" );
    }
    $self->db( $db );

    return $self; # success - we hope!
}


=head2 get_Ensembl_SeqFeatures_contig

 Title   : get_Ensembl_SeqFeatures_contig
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_Ensembl_SeqFeatures_contig {
   my ($self,$internal_id,$contig) = @_;


   if (!defined($contig)) {
       $self->throw("No contig entered for get_Ensembl_SeqFeatures_contig");
   }
   my @array;

   my $statement = "SELECT feature.id, seq_start, seq_end, strand, score, analysis, name, hstart, hend, hid, evalue, perc_id, phase, end_phase " .
       "FROM   feature WHERE " .
       "feature.contig = " . $internal_id;

   my $sth = $self->db->prepare($statement);
   my $res = $sth->execute;


   # bind the columns
   $sth->bind_columns(undef,\$fid,\$start,\$end,\$strand,\$f_score,\$analysisid,\$name,\$hstart,\$hend,\$hid,\$evalue,\$perc_id,\$phase,\$end_phase);
   
   while($sth->fetch) {
       my $out;
       my $analysis;
       my $anaAdaptor = Bio::EnsEMBL::DBSQL::AnalysisAdaptor->new($self->db);      
       if (!$analhash{$analysisid}) {
	 		$analysis   = $anaAdaptor->fetch_by_dbID($analysisid);     
	 		$analhash{$analysisid} = $analysis;
       } else {
	   		$analysis = $analhash{$analysisid};
       }
       
       if( !defined $name ) {
	   $name = 'no_source';
       }
       
       if( $hid ne '__NONE__' ) {

	   	# is a paired feature
		   # build EnsEMBL features and make the FeaturePair

		   $out = Bio::EnsEMBL::FeatureFactory->new_feature_pair();

		   # hacky temporary fix for web
		   $name = 'est';
		   $source = 'est';	# no longer used - DB
		   $out->set_featurepair_fields($start, $end, $strand,
		     $f_score, $name, $hstart, $hend, 1, $f_score,
		     $name, $analysis);

		   $out->id          ($hid);              # MC This is for Arek - but I don't
	                                        	  #    really know where this method has come from.
		   $out->p_value    ($evalue)    if (defined $evalue);
		   $out->percent_id ($perc_id)   if (defined $perc_id); 
		   $out->phase      ($phase)     if (defined $phase);    
		   $out->end_phase  ($end_phase) if (defined $end_phase);

       } else {
		   $out = new Bio::EnsEMBL::SeqFeature;
		   $out->seqname    ($self->id);
		   $out->start      ($start);
		   $out->end        ($end);
		   $out->strand     ($strand);
		   $out->source_tag ('est');
		   $out->primary_tag('est');
		   $out->id         ($fid);
		   $out->p_value    ($evalue)    if (defined $evalue);
		   $out->percent_id ($perc_id)   if (defined $perc_id); 
		   $out->phase      ($phase)     if (defined $phase);    
		   $out->end_phase  ($end_phase) if (defined $end_phase);

		   if( defined $f_score ) {
	    	   $out->score($f_score);
		   }
		   $out->analysis($analysis);
       }
       # Final check that everything is ok.
       $out->validate();
       
      push(@array,$out);
      
   }
   return @array;


}

=head2 get_Ensembl_SeqFeatures_contig_list

 Title   : get_Ensembl_SeqFeatures_contig_list
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_Ensembl_SeqFeatures_contig_list{
   my ($self,$href,$idlist,$start,$end) = @_;
   my @idlist = @$idlist;

   my %int_ext = %$href;
   my $string;
   foreach my $contig (@idlist) {
       $string .= "$contig,";
   }
   $string =~ s/,$//;
   my $inlist = "($string)";
   
   my @array;

   my $glob = 50;

   my $statement;

   if (defined $start && defined $end) {
      $statement = "SELECT id, contig, seq_start, seq_end, strand, score, analysis, name, hstart, hend, hid, evalue, perc_id, phase, end_phase " .
       "FROM  feature WHERE feature.contig in $inlist and feature.seq_start >= $start and feature.seq_end <= $end order by hid,seq_start";
   } else {
      $statement = "SELECT id, contig, seq_start, seq_end, strand, score, analysis, name, hstart, hend, hid, evalue, perc_id, phase, end_phase " .
       "FROM  feature WHERE feature.contig in $inlist order by hid,seq_start";
   }

   &eprof_start('est-sql');
   my $sth = $self->db->prepare($statement);
   my $res = $sth->execute;
   &eprof_end('est-sql');
   
   # bind the columns
   $sth->bind_columns(undef,\$fid,\$contig,\$start,\$end,\$strand,\$f_score,\$analysisid,\$name,\$hstart,\$hend,\$hid,\$evalue,\$perc_id,\$phase,\$end_phase);
   
   &eprof_start('est-object');
   my $prev;
   my $anaAdaptor = Bio::EnsEMBL::DBSQL::AnalysisAdaptor->new($self->db);      

   while($sth->fetch) {

       if( defined $prev && $prev->hseqname eq $hid && $prev->end+$glob > $start ) {
	   $prev->end($end);
	   next;
       }

       my $out;
       my $analysis;

       if (!$analhash{$analysisid}) {
	 $analysis   = $anaAdaptor->fetch_by_dbID($analysisid);     
	 
	 if(defined($analysis)){
	   $self->throw("$analysis is not a Bio::EnsEMBL::Analysis") unless $analysis->isa("Bio::EnsEMBL::Analysis");
	   $analhash{$analysisid} = $analysis;
	 }
	 else{
	   $self->throw("no analysis fetched for $fid $hid\n");
	 }
       } else {
	   $analysis = $analhash{$analysisid};
       }
              
       if( !defined $name ) {
	   $name = 'no_source';
       }
       
       # is a paired feature
       # build EnsEMBL features and make the FeaturePair
       $out = Bio::EnsEMBL::FeatureFactory->new_feature_pair();
       $out->set_featurepair_fields($start, $end, $strand, $f_score, $name,
			    $hstart, $hend, 1, $f_score, $name, $analysis);
       
       if( !$out->isa("Bio::EnsEMBL::Ext::FeaturePair") ) { 
	   	$out->percent_id  ($perc_id);
       }

       $out->id          ($hid);  
       $out->validate();
       
       push(@array,$out);
   }
   &eprof_end('est-object');
   return @array;
}

=head2 get_Ensembl_SeqFeatures_clone

 Title   : get_Ensembl_SeqFeatures_clone (Abstract)
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_Ensembl_SeqFeatures_clone{
   my ($self) = @_;
   
	#$self->throw("get_Ensembl_SeqFeatures_clone not implemented for est  database");
   return ();
}

=head2 get_Ensembl_Genes_clone

 Title   : get_Ensembl_Genes_clone
 Function: returns Gene objects in clone coordinates from a gene id
 Returns : An array of Gene objects
 Args    : clone id

=cut

sub get_Ensembl_Genes_clone {
    my $self = @_;

	# $self->throw("get_Ensembl_Genes_clone is not valid for the est database");
	# must return an empty list here or else we try to loop over non-existent genes....
   return ();
}

=head2 get_SeqFeature_by_id

 Title   : get_SeqFeature_by_id (Abstract)
 Usage   : 
 Function: Return SeqFeature object for any valid unique id  
 Example :
 Returns : 
 Args    : id as determined by the External Database


=cut

       
sub get_SeqFeature_by_id {
   my ($self,$id) = @_;

   $self->throw("get_SeqFeature_by_id not implmented for the est database");

}


sub db {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	if ($arg->isa("Bio::EnsEMBL::ExternalData::ESTSQL::DBAdaptor")) {
	    $self->{_db} = $arg;
	} else {
	    $self->throw("[$arg] is not a Bio::EnsEMBL::ExternalData::ESTSQL::DBAdaptor");
	}
    }
    return $self->{_db};
}


=head2 get_Ensembl_SeqFeatures_exon

 Title   : get_Ensembl_SeqFeatures_exon
 Usage   :
 Function:Gets all of the ESTs features for a given exon
 Example :
 Returns : array of feature object
 Args    : exon object


=cut

sub get_Ensembl_SeqFeatures_exon {
    my ( $self, $exon )  = @_;
   
    my @features;
 
    # if exon is sticky, get supporting from components
    if( $exon->isa( 'Bio::EnsEMBL::StickyExon' )) {
	# sticky storing. Sticky exons contain normal exons ...
	
	my @componentExons = $exon->each_component_Exon();
	for my $componentExon ( @componentExons ) {
	    my @sticky_features = $self->get_Ensembl_SeqFeatures_exon( $componentExon );
	    push(@features,@sticky_features);
	}
	return;
    }
			
    my $statement = "SELECT contig, seq_start, seq_end, score,
                          strand, analysis, name, hstart, hend,
                          hid, evalue, perc_id, phase, end_phase
                   FROM feature 
                   WHERE contig = ".$exon->contig->internal_id."
                   AND seq_start <= ".$exon->end()."
                   AND seq_end >= ".$exon->start();
    
    my $sth = $self->db->prepare($statement);
    $sth->execute || $self->throw("execute failed for supporting evidence get!");


    my $anaAdaptor = Bio::EnsEMBL::DBSQL::AnalysisAdaptor->new($self->db);
    
    while (my $rowhash = $sth->fetchrow_hashref) {
	my $analysis = $anaAdaptor->fetch_by_dbID( $rowhash->{analysis} );
	
	if( 
	    $analysis->logic_name ne "est"
	    ) {
	    next;
	}
	
	my $f = Bio::EnsEMBL::FeatureFactory->new_feature_pair();
	$f->set_featurepair_fields($rowhash->{'seq_start'},
			           $rowhash->{'seq_end'},
			           $rowhash->{'strand'},
			           $rowhash->{'score'},
			           $rowhash->{'name'},
			           $rowhash->{'hstart'},
			           $rowhash->{'hend'},
			           1, # hstrand
			           $rowhash->{'score'},
			           $rowhash->{'name'},
				   $analysis);

	$f->analysis($analysis);
	
	$f->validate;
	push(@features,$f);

    }
    
    return @features;   
}

1;
