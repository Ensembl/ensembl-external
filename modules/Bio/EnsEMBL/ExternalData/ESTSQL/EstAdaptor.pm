
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
use Bio::EnsEMBL::DBSQL::Feature_Obj;
use Bio::EnsEMBL::FeatureFactory;
use Bio::Root::RootI;
use vars qw(@ISA);

@ISA = qw(Bio::Root::RootI Bio::EnsEMBL::DB::ExternalFeatureFactoryI);


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
   my ($self,$internal_id,$version,$dum,$length,$contig) = @_;

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
              
       if (!$analhash{$analysisid}) {
	   
	   my $feature_obj=Bio::EnsEMBL::DBSQL::Feature_Obj->new($self->db);
	   $analysis = $feature_obj->get_Analysis($analysisid);
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


	   $out->set_all_fields($start,$end,$strand,$f_score,$name,'similarity',$contig,
				$hstart,$hend,1,$f_score,$name,'similarity',$hid);

	   $out->analysis    ($analysis);
	   $out->id          ($hid);              # MC This is for Arek - but I don't
	                                          #    really know where this method has come from.
       } else {
	   $out = new Bio::EnsEMBL::SeqFeature;
	   $out->seqname    ($self->id);
	   $out->start      ($start);
	   $out->end        ($end);
	   $out->strand     ($strand);
	   $out->source_tag ($name);
	   $out->primary_tag('similarity');
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

1;











