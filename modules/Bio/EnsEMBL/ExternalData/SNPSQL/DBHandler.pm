
#
# BioPerl module for Bio::EnsEMBL::ExternalData::SNPSQL::DBHandler
#
# Cared for by Heikki Lehvaslaiho <heikki@ebi.ac.uk>
#
# Copyright Heikki Lehvaslaiho
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::SNPSQL::DBHandler - Class for a sequence variation
database providing external features for EnsEMBL

=head1 SYNOPSIS

   # first make an Object which conforms to interface
   # Bio::EnsEMBL::DB::ExternalFeatureFactoryI
   $snpdb = Bio::EnsEMBL::ExternalData::SNPSQL::Obj->new( -dbname => 'snp'
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

   my $snp = $snpdb->get_SeqFeature_by_id("TSC0000002");


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

package Bio::EnsEMBL::ExternalData::SNPSQL::DBHandler;

#use Bio::Root::Object;
#use Bio::EnsEMBL::DB::ExternalFeatureFactoryI;
use DBI;
use vars qw(@ISA);
use strict;
use Bio::EnsEMBL::ExternalData::Variation;

# Object preamble - inherits from Bio::Root:RootI
@ISA = qw(Bio::Root::RootI  Bio::EnsEMBL::DB::ExternalFeatureFactoryI);

#
#my $user = 'root';
#my $password = '';
#my $db = 'tsc';
#
#my $dbh = DBI->connect('DBI:mysql:tsc',$user,$password);


sub new {
    my($class,@args) = @_;
    my $self;
    $self = {};
    bless $self, $class;

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

  return $self; # success - we hope!

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
 Function:

           Return SeqFeature object(s) for any valid unique ID. If the
           database contains more than one location for a SeqFeature,
           each location will be written into its own object.

 Example :
 Returns : an array of L<Bio::EnsEMBL::ExternalData::Variation.pm> objects
 Args    : id as determined by this database


=cut


sub get_SeqFeature_by_id {
    my($self) = shift;
    my ($id) =  @_;

    my $snp = new Bio::EnsEMBL::ExternalData::Variation;
    my ($query);

    #lists of variations to be returned
    my @variations;

    $id = uc $id;
    # if ID given is a TSC id
    if ($id =~ /TSC/) {
       #strip all decorations from the display id: TSC::TSC0000003 -> 3
       #$id) = $id =~ /.*TSC0*(\d+)/;
       #
       # db query to return all variation information except alleles
       #query = qq{
       #
       #select p1.SNP_ID,  p1.SNP_USERID, p1.SNP_CONFIDENCE,
       #       p1.SNP_CONFIRMED, p1.SNP_WITHDRAWN,  p1.CLIQUE_POSITION,
       #       p1.CLIQUE_ID, p1.DBSNP_ID,
       #       p2.Sub_Start, p2.Sub_END,
       #       p2.Qry_Start, p2.Qry_END, p2.Sub_ACC_version
       #from   TBL_SNP_INFO as p1
       #left join  TBL_INSILICO_RESULTS as p2
       #on      p1.CLIQUE_ID = p2.Clique_id
       #where   p1.SNP_ID = "$id"
       #
       #    };
    # else it is a dbSNP id
    } else {
	
	$query = qq{
	
	    SELECT p1.acc, p1.version, p1.start, p1.end, p1.type,
	     	   p2.snpclass,  p2.snptype,
	     	   p2.observed, p2.seq5, p2.seq3,
	     	   p2.het, p2.hetse, p2.validated
	    FROM   Hit as p1, RefSNP as p2
            WHERE  p2.id = "$id"
                   AND p1.refsnpid = p2.id

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
	
	my ($acc, $ver, $begin, $end, $postype, $class, $type,
	    $alleles, $seq5, $seq3, $het, $hetse,  $confirmed
	    ) = @{$arr};
	
        #snp info not valid
	$self->throw("SNP withdrawn. Reason: $type ") if $type ne 'notwithdrawn';

	# use the 'standard' vocabulary for the SNP status
	# use the right vocabulary for the SNP status
	if ($confirmed ) {
	    $confirmed = "proven";
	} else {
	    $confirmed = "suspected";
	}
	
	# the allele separator should be  '|'
	$alleles =~ s/\//\|/g;
	
	#prune flank sequences to 25 nt
	$seq5 = substr($seq5, -25, 25);
	$seq5 = substr($seq5, 0, 25);

	#
	# prepare the output objects
	#

	#Variation
	my $acc_version = '';
	$acc_version .= uc $acc if $acc;
	$acc_version .= ".$ver" if $ver;

	if ($acc_version) {
	        $snp->seqname($acc_version);
		$snp->start($begin);
		$snp->end($end);
		$snp->strand($strand);
	}
	$snp->source_tag('dbSNP');
	$snp->status($confirmed);
	$snp->alleles($alleles);
	$snp->upStreamSeq($seq5);
	$snp->dnStreamSeq($seq3);
	
	#DBLink
	my $link = new Bio::Annotation::DBLink;
	$link->database('dbSNP');
	$link->primary_id($id);

	#add dbXref to Variation
	$snp->add_DBLink($link);

#	 #dbSNP id is given
#	 if ( $dbsnpid ) {
#
#	     my $link2 = new Bio::Annotation::DBLink;
#	     $link2->database('dbSNP');
#	     $link2->primary_id($dbsnpid);
#
#	     $snp->add_DBLink($link2);
#	 }

	#add SNP to the list
	push(@variations, $snp);

	#print STDERR join (" ", $id, $confirmed, $acc_version, $begin, $end,
	#		    #$dbsnpid,
	#		    "|", $strand,
	#		    $seq5, $alleles, $seq3,
	#		    $begin, $end,
	#		    "\n");
    }

    return @variations;
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

    my $acc_version = uc "$acc.$ver";


   # db query to return all variation information ; confidence is gone!!
   my $query = qq{

       SELECT  p1.start, p1.end, p1.type,
  	       p2.id, p2.snpclass,  p2.snptype,
  	       #p2.observed, p2.seq5, p2.seq3,
  	       #p2.het, p2.hetse,
               p2.validated
  	FROM   Hit as p1, RefSNP as p2
  	WHERE  p1.acc = "$acc" and p1.version = "$ver"
  	       AND p1.refsnpid = p2.id
	       };

   my $sth = $self->prepare($query);
   my $res = $sth->execute();

 SNP:
   while( (my $arr = $sth->fetchrow_arrayref()) ) {

       my $allele_pos = 0;
       my $strand = 1;

       my ($begin, $end, $hittype,
	   $snpuid, $class, $type,
	   #$alleles, $seq5, $seq3, $het, $hetse,
	   $confirmed
	   ) = @{$arr};

       #snp info not valid
       next SNP if $type ne 'notwithdrawn';

       #exclude SNPs outside the given $start-$end range
       if (defined $start) {
	   next SNP if $begin < $start;
       }
       if (defined $stop) {
	   next SNP if $end > $stop;
       }

       # use the right vocabulary for the SNP status
       if ($confirmed ) {
	   $confirmed = "proven";
       } else {
	   $confirmed = "suspected";
       }
	
       # the allele separator should be  '|'
       #$alleles =~ s/\//\|/g;

       #
       # prepare the output objects
       #

       #Variation
       my $snp = new Bio::EnsEMBL::ExternalData::Variation
	   (-start => $begin,
	    -end => $end,
	    -strand => $strand,
	    -source_tag => 'dbSNP',
	    #-score  => $confidence,
	    -status => $confirmed,
	    #-alleles => $alleles
	    );

       # set for compatibility to Virtual Contigs
       $snp->seqname($acc_version);

       #DBLink
       my $link = new Bio::Annotation::DBLink;
       $link->database('dbSNP');
       $link->primary_id($snpuid);
       $link->optional_id($acc_version);

       #add dbXref to Variation
       $snp->add_DBLink($link);

#	#if dbSNP id is given
#	if ( $dbsnpid ) {
#
#	    my $link2 = new Bio::Annotation::DBLink;
#	    $link2->database('dbSNP');
#	    $link2->primary_id($dbsnpid);
#
#	    $snp->add_DBLink($link2);
#	}

       #add SNP to the list
       push(@variations, $snp);

       #print join (" ", $snpuid, $confirmed,
       #	    #$dbsnpid,
       #	    "|", $strand,
       #	    #$alleles,
       #	     $begin, $end,
       #	     "\n");
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

