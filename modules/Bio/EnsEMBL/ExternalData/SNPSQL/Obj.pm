
#
# BioPerl module for Bio::EnsEMBL::ExternalData::SNPSQL::Obj
#
# Cared for by Heikki Lehvaslaiho <heikki@ebi.ac.uk>
#
# Copyright Heikki Lehvaslaiho
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::SNPSQL::Obj - Class for a sequence variation
database providing external features for EnsEMBL

=head1 SYNOPSIS

   # first make an Object which conforms to interface
   # Bio::EnsEMBL::DB::ExternalFeatureFactoryI
   $snpdb = Bio::EnsEMBL::ExternalData::SNPSQL::Obj->new( -dbname => 'tsc'
							  -user => 'root'
							  ); 

   # you can make an obj with external databases
   $dbobj = Bio::EnsEMBL::DBSQL::Obj->new( -host => 'localhost',
					   -dbname => 'ensembl',
					   -external => [ $snpdb ] );

   # alternatively, you can add external databases to an obj once made
   # if you do not use the '-external' attribute above
   $dbobj->add_ExternalFeatureFactory($mydb);

   # This class implements only clone based method 
   # get_Ensembl_SeqFeatures_clone
   #
   # Method get_Ensembl_SeqFeatures_contig return an empty list.

   # accessing sequence variations by id
   # $snp is a Bio::EnsEMBL::ExternalData::Variation object

   my $snp = $snpdb->get_SeqFeature_by_id("TSC::TSC0000002");
   

=head1 DESCRIPTION


This class implements L<Bio::EnsEMBL::DB::ExternalFeatureFactoryI>
interface for creating L<Bio::EnsEMBL::ExternalData::Variation.pm>
objects from a relational sequence variation database. See
L<Bio::EnsEMBL::DB::ExternalFeatureFactoryI> for more details on how
to use this class.

The objects returned in a list are
L<Bio::EnsEMBL::ExternalData::Variation> objects which contain
L<Bio::Annotation::DBLink> objects to give unique IDs in various
Variation databases.

This first implementation uses The SNP Consortium database, TSC, with
mySQL engine.


=head1 FEEDBACK

=head2 Mailing Lists

  User feedback is an integral part of the evolution of this
  and other Bioperl modules. Send your comments and suggestions preferably
  to one of the Bioperl mailing lists.
  Your participation is much appreciated.

  vsns-bcd-perl@lists.uni-bielefeld.de          - General discussion
  vsns-bcd-perl-guts@lists.uni-bielefeld.de     - Technically-oriented discussion
  http://bio.perl.org/MailList.html             - About the mailing lists

=head2 Reporting Bugs

  Report bugs to the Bioperl bug tracking system to help us keep track
  the bugs and their resolution.
  Bug reports can be submitted via email or the web:

  bioperl-bugs@bio.perl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Heikki Lehvaslaiho

  Email heikki@ebi.ac.uk


Address: 

     EMBL Outstation, European Bioinformatics Institute
     Wellcome Trust Genome Campus, Hinxton
     Cambs. CB10 1SD, United Kingdom 


=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...

package Bio::EnsEMBL::ExternalData::SNPSQL::Obj;

use Bio::Root::Object;
use Bio::EnsEMBL::DB::ExternalFeatureFactoryI;
use Bio::EnsEMBL::ExternalData::Variation;
use Bio::Annotation::DBLink;
use DBI; 
use vars qw(@ISA);
use strict;

# Object preamble - inherits from Bio::Root::Object

@ISA = qw(Bio::Root::Object Bio::EnsEMBL::DB::ExternalFeatureFactoryI);

#
## 
#
#my $user = 'root';
#my $password = '';
#my $db = 'tsc';
#
## 
#
#my $dbh = DBI->connect('DBI:mysql:tsc',$user,$password); 


sub _initialize {
  my($self,@args) = @_;
 
  my $make = $self->SUPER::_initialize;
 
  my ($db,$host,$driver,$user,$password) =
      $self->_rearrange([qw(DBNAME
                            HOST
                            DRIVER
                            USER
                            PASS
                            )],@args);
 
  $db   || $self->throw("Database object must have a database name");
  $user || $self->throw("Database object must have a user");
               
  if( ! $driver ) {
      $driver = 'mysql';
  } 
  if( ! $host ) {
      $host = 'localhost';
  }



  my $dsn = "DBI:$driver:database=$db;host=$host";
  my $dbh = DBI->connect("$dsn","$user",$password);
 
  $dbh || $self->throw("Could not connect to database $db user $user using [$dsn] as a locator");

  $self->_db_handle($dbh);     

  return $make; # success - we hope!

}

=head2 get_Ensembl_SeqFeatures_contig

 Title   : get_Ensembl_SeqFeatures_contig (not used)
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_Ensembl_SeqFeatures_contig{
   my ($self) = @_;
   my @tmp;
   
   return @tmp;

}
       

=head2 get_SeqFeature_by_id

 Title   : get_SeqFeature_by_id
 Usage   : $db->get_SeqFeature_by_id($id_from_seqfeature);
 Function: Return SeqFeature object for any valid unique ID
  
 Example :
 Returns : a L<Bio::EnsEMBL::ExternalData::Variation.pm> object
 Args    : id as determined by this database
              
              
=cut
              
       
sub get_SeqFeature_by_id {
    my($self) = shift;
    my ($id) =  @_;

    my $snp = new Bio::EnsEMBL::ExternalData::Variation;
    my ($query);

    $id = uc $id;
    # if ID given is a TSC id
    if ($id =~ /TSC/) {
       #strip all decorations from the display id: TSC::TSC0000003 -> 3
       ($id) = $id =~ /.*TSC0*(\d+)/;

       # db query to return all variation information except alleles
       $query = qq{

	select p1.SNP_ID,  p1.SNP_USERID, p1.SNP_CONFIDENCE, 
 	       p1.SNP_CONFIRMED, p1.SNP_WITHDRAWN,  p1.CLIQUE_POSITION,
	       p1.DBSNP_ID,
               p2.Sub_Start, p2.Sub_END,
               p2.Qry_Start, p2.Qry_END, p2.Sub_ACC_version
        from   TBL_SNP_INFO as p1 
        left join  TBL_INSILICO_RESULTS as p2
	on      p1.CLIQUE_ID = p2.Clique_id
        where   p1.SNP_ID = "$id" 
		
	    };  
    # else it is a dbSNP id
    } else { 

       $query = qq{
 	        
        select p1.SNP_ID, p1.SNP_USERID, p1.SNP_CONFIDENCE,
               p1.SNP_CONFIRMED, p1.SNP_WITHDRAWN, p1.CLIQUE_POSITION,
               p1.DBSNP_ID,
               p2.Sub_Start, p2.Sub_END,
               p2.Qry_Start, p2.Qry_END, p2.Sub_ACC_version
        from TBL_SNP_INFO as p1
        left join  TBL_INSILICO_RESULTS as p2
        on       p1.CLIQUE_ID = p2.Clique_id
        where  p1.DBSNP_ID = "$id" 

              };
   }

    my $sth = $self->prepare($query);
    my $res = $sth->execute();
    my $rows = $sth->rows();
    $rows || $self->throw("SNP not found or not mapped to a clone!");


  SNP:
    while( (my $arr = $sth->fetchrow_arrayref()) ) {

	my $allele_pos = '0'; 
	my $strand = '1';

	my ($snpid,  $snpuid, $confidence, $confirmed, 
	    $snp_withdrawn, $q_pos, $dbsnpid,
	    $t_start, $t_end, $q_start, $q_end, $acc_version
	    ) = @{$arr};

        #snp info not valid
	$self->throw("SNP withdrawn!") if $snp_withdrawn eq 'Y';

        #coordinate system change from clique -> clone
        if ($acc_version) {
           if ($q_start < $q_end) {
              $allele_pos = $t_start + $q_start + $q_pos - 2;
              $strand = 1;
           } else {
              $allele_pos = $t_start + $q_start - $q_pos;
              $strand = -1;
 	   }
	}

	# use the right vocabulary for the SNP status
	if ($confirmed eq 'N') {
	    $confirmed = "suspected";
	}
	else {
	    $confirmed = "proven";
	}
	
	#
	# get the alleles
	# & put them in a string separated by '|'
	# 
	
	my $query2 = qq{
	    
	    select p2.ALLELE
		from  TBL_ALLELE_INFO  as p2
		    where p2.SNP_ID = "$snpid"
			
		    };  

	my $sth2 = $self->prepare($query2);
	my $res2 = $sth2->execute();

	my ($alleles) = ''; 
	while( (my $arr2 = $sth2->fetchrow_arrayref()) ) {
	    
	    my ($allele) = @{$arr2};
	    $alleles .= "$allele\|";
	    
	}
	chop $alleles;
	$alleles = lc $alleles;
	
	#
	# get the flanking sequences
	#
	my ($leftFlank) = '';
	my ($rightFlank) = '';

	my $query3 = qq{

            select p3.FLANK_SEQ, p3.IS_LEFT
	    from TBL_FLANK_INFO as p3
	    where p3.SNP_ID = "$snpid"

		};

        my $sth3 = $self->prepare($query3);
        my $res3 = $sth3->execute();
        while( (my $arr3 = $sth3->fetchrow_arrayref()) ) {

	    my ($seq, $is_left) = @{$arr3};
	    if ($is_left eq 'Y') {
		$leftFlank = substr($seq, -25, 25);
	    } else {
		$rightFlank = substr($seq, 0, 25);
	    }
		
	}

	#
	# prepare the output objects
	#

	#Variation

	if ($acc_version) {
	        $snp->seqname($acc_version);
		$snp->start($allele_pos);
		$snp->end($allele_pos);
		$snp->strand($strand);
	}
	$snp->source_tag('The SNP Consortium');
	$snp->score($confidence);    
	$snp->status($confirmed);
	$snp->alleles($alleles);
	$snp->upStreamSeq($leftFlank);
	$snp->dnStreamSeq($rightFlank);

	
	#DBLink
	my $link = new Bio::Annotation::DBLink;
	$link->database('TSC');
	$link->primary_id($snpuid);

	#add dbXref to Variation
	$snp->add_DBLink($link);

	#dbSNP id is given
	if ( $dbsnpid ) {

	    my $link2 = new Bio::Annotation::DBLink;
	    $link2->database('dbSNP');
	    $link2->primary_id($dbsnpid);

	    $snp->add_DBLink($link2);
	}
	
#	print "---------\nID: ", $snpuid, "\nConfidence: ", $confidence, 
# 	      "\nStatus: ", $confirmed, 
#	      "\ndbSNP: ", $dbsnpid,  
#	      "\nAlleles: ", $alleles, "\nAcc_version:", "$acc_version", 
#              "\nAllelepos:", $allele_pos, 
#    	      "\nFlanks: ", $snp->upStreamSeq, '/', $snp->dnStreamSeq,
#	      "\n------------\n";

    }
    
    return $snp;
}



=head2 get_Ensembl_SeqFeatures_clone

 Title   : get_Ensembl_SeqFeatures_clone
 Usage   : get_Ensembl_SeqFeatures_clone($embl_accession_number,
		  		          $sequence_version,$start,$end);
 Function:
    
    The semantics of this method is as follows:
    
    	$ensembl_contig_identifier - the ensembl contig id (external id).
    	$sequence_version - embl/genbank sequence version
    	$embl_accession_number - the embl/genbank accession number
    
    The $start/$end can be ignored, but methods can take advantage of it.
    This is so that ensembl can ask for features only on a region of DNA,
    and if desired, the external database can respond with features only
    in this region, rather than the entire sequence.
    
    The hope is that the second method could potentially have a very
    complex set of mappings of other embl_accession numbers to one
    embl_accession number and provide the complex mapping.
    
 Example :
 Returns : list of Bio::SeqFeature::Variation objects
 Args    : $embl_accession_number,
           $sequence_version,
           $start of range, optional
           $end of range, optional


=cut

sub get_Ensembl_SeqFeatures_clone {
   my($self) = shift;
   my ($acc, $ver, $start, $stop) = @_;

   #my $dbh = DBI->connect('DBI:mysql:tsc',$user,$password);

   #lists of variations to be returned
   my @variations;

   #sanity checks
   if ( ! defined $ver) {
       $self->throw("Two arguments are requided: embl_accession number and version_number!");
   }
   
   if (defined $start) {
       $start = 1 if $start eq "";
       if ( $start !~ /^\d+$/  and $start > 0) {
	   $self->throw("$start is not a valid start");
       }
   }
   if (defined $stop) {
       $start = 1 if not defined $start; 
       if ( $stop !~ /^\d+$/ and $stop > 0 ) {
	   $self->throw("$stop is not a valid start");
       }
   }
   if (defined $start and defined $stop) {
       if ($stop < $start) {
	   $self->throw("$stop is smaller than  $start not a valid start");
       }
   }

   my $embl_ver = uc "$acc.$ver";


   # db query to return all variation information except alleles
   my $query = qq{
       
       select p2.SNP_ID,  p2.SNP_USERID, p2.SNP_CONFIDENCE, 
              p2.SNP_CONFIRMED, p2.SNP_WITHDRAWN,  p2.CLIQUE_POSITION,
      	      p2.DBSNP_ID,
      	      p1.Sub_Start, p1.Sub_END, 
      	      p1.Qry_Start, p1.Qry_END
       from   TBL_INSILICO_RESULTS as p1,
       	      TBL_SNP_INFO as p2
       where  p1.Sub_ACC_version = "$embl_ver" and
      	      p1.Clique_id = p2.CLIQUE_ID
      
	       };  

   my $sth = $self->prepare($query);
   my $res = $sth->execute();

 SNP:
   while( (my $arr = $sth->fetchrow_arrayref()) ) {

       my $allele_pos = 0;
       my $strand = 1;
       
       my ($snpid,  $snpuid, $confidence, $confirmed, 
	   $snp_withdrawn, $q_pos, $dbsnpid,
	   $t_start, $t_end, 
	   $q_start, $q_end
	   ) = @{$arr};

       #snp info not valid or in-silico result not valid
       next SNP if $snp_withdrawn eq 'Y';

       #coordinate system change from clique -> clone
       if ($q_start < $q_end) {
	   $allele_pos = $t_start + $q_start + $q_pos - 2;
       }
       else {
	   $allele_pos = $t_start + $q_start - $q_pos;
	   $strand = -1;
       }
       
       #exclude SNPs outside the given $start-$end range
       if (defined $start) {
	   next SNP if $allele_pos < $start;

       }
       if (defined $stop) {
	   next SNP if $allele_pos > $stop;
       }

       # use the right vocabulary for the SNP status
       if ($confirmed eq 'N') {
	   $confirmed = "suspected";
       }
       else {
	   $confirmed = "proven";
       }
	
       #
       # get the alleles
       # & put them in a string separated by '|'
       # 
       
       my $query2 = qq{
	   
	   select p2.ALLELE
	   from  TBL_ALLELE_INFO  as p2
	   where p2.SNP_ID = "$snpid"
		    
	   };  

       my $sth2 = $self->prepare($query2);
       my $res2 = $sth2->execute();

       my ($alleles) = ''; 
       while( (my $arr2 = $sth2->fetchrow_arrayref()) ) {
	   
	   my ($allele) = @{$arr2};
	   $alleles .= "$allele\|";
	   
       }
       chop $alleles;
       $alleles = lc $alleles;
       
       #
       # prepare the output objects
       #

       #Variation
       my $snp = new Bio::EnsEMBL::ExternalData::Variation
	   (-start => $allele_pos, 
	    -end => $allele_pos,
	    -strand => $strand, 
	    -source_tag => 'The SNP Consortium', 
	    -score  => $confidence,                
	    -status => $confirmed,
	    -alleles => $alleles   
	    );
       
       #DBLink
       my $link = new Bio::Annotation::DBLink;
       $link->database('TSC');
       $link->primary_id($snpuid);

       #add dbXref to Variation
       $snp->add_DBLink($link);

       #dbSNP id is given
       if ( $dbsnpid ) {

	   my $link2 = new Bio::Annotation::DBLink;
	   $link2->database('dbSNP');
	   $link2->primary_id($dbsnpid);

	   $snp->add_DBLink($link2);
       }
       
       #add SNP to the list
       push(@variations, $snp);

       #print join (" ", $snpuid, $confidence, $confirmed, 
       #		    $dbsnpid, "|", $strand,
       #		    $allele_pos, $alleles,
       #		    #$t_start, $t_end, $q_start, $q_end
       #		    "\n");

   }
   
   return @variations;
}

=head2 prepare

 Title   : prepare
 Usage   : $sth = $dbobj->prepare("select seq_start,seq_end from feature where analysis = \" \" ");
 Function: prepares a SQL statement on the DBI handle

           If the debug level is greater than 10, provides information into the
           DummyStatement object

 Example :
 Returns : A DBI statement handle object
 Args    : a SQL string

=cut

sub prepare {
    my ($self,$string) = @_;
 
   if( ! $string ) {
       $self->throw("Attempting to prepare an empty SQL query!");
   }
 
   return $self->_db_handle->prepare($string);
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


1;

