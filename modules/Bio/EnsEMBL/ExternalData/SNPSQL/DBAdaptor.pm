#$Id$
#
# BioPerl module for Bio::EnsEMBL::ExternalData::SNPSQL::DBAdaptor
#
# Cared for by Heikki Lehvaslaiho <heikki@ebi.ac.uk>
#
# Copyright Heikki Lehvaslaiho
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::SNPSQL::DBAdaptor - Class for a sequence
variation database providing external features for EnsEMBL

=head1 SYNOPSIS

   # first make an Object which conforms to interface
   # Bio::EnsEMBL::DB::ExternalFeatureFactoryI

    $snpdb = Bio::EnsEMBL::ExternalData::SNPSQL::DBAdaptor->new( -dbname => 'snp'
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
   # the method call returns an array of Variation objects; one for each location
   my @snps = $snpdb->get_SeqFeature_by_id("578");
   my $snp = pop @snps;


=head1 DESCRIPTION


This class implements L<Bio::EnsEMBL::DB::ExternalFeatureFactoryI> and
L<Bio::EnsEMBL::DB::WebExternalFeatureFactoryI> interfaces for
creating L<Bio::EnsEMBL::ExternalData::Variation.pm> objects from a
relational sequence variation database. See the interface files for
more details on how to use this class.

The method get_Ensembl_SeqFeatures_clone_web() is now in the derived
class WebAdaptor.

The objects returned in a list are
L<Bio::EnsEMBL::ExternalData::Variation> objects which contain
L<Bio::Annotation::DBLink> objects to give unique IDs in various
Variation databases.

=head1 FEEDBACK

=head2 Mailing Lists

  User feedback is an integral part of the evolution of this
  and other Ensebl modules. Send your comments and suggestions preferably
  to one of the Bioperl mailing lists.
  Your participation is much appreciated.

  vsns-bcd-perl@lists.uni-bielefeld.de          - General discussion
  vsns-bcd-perl-guts@lists.uni-bielefeld.de     - Technically-oriented discussion
  http://bio.perl.org/MailList.html             - About the mailing lists

=head2 Reporting Bugs

  Report bugs to the Bioperl bug tracking system to help us keep track
  the bugs and their resolution.
  Bug reports can be submitted via email or the web:

  ensembl-dev@ebi.ac.uk                        - General discussion

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

package Bio::EnsEMBL::ExternalData::SNPSQL::DBAdaptor;

use strict;
use vars qw(@ISA);
use DBI;
use Bio::EnsEMBL::DB::WebExternalFeatureFactoryI;
use Bio::EnsEMBL::ExternalData::Variation;
use Bio::EnsEMBL::Utils::Eprof qw( eprof_start eprof_end);

# Object preamble - inherits from Bio::Root:RootI
@ISA = qw(Bio::Root::RootI Bio::EnsEMBL::DB::WebExternalFeatureFactoryI);

sub new {
    my($class,@args) = @_;
    my $self;
    $self = {};
    bless $self, $class;

    my ($db,$host,$port,$driver,$user,$password) =
	$self->_rearrange([qw(DBNAME
			      HOST
			      PORT
			      DRIVER
			      USER
			      PASS
			      )],@args);
    
    $db   || $self->throw("Database object must have a database name");
    $user || $self->throw("Database object must have a user");
    
    $driver ||= 'mysql';
    $host ||= 'localhost';
    $port ||= 3306;
    
    my $dsn = "DBI:$driver:database=$db;host=$host;port=$port";
    my $dbh = DBI->connect("$dsn","$user",$password);
    
    $dbh || $self->throw("Could not connect to database $db user $user using [$dsn] as a locator");
    
    $self->_db_handle($dbh);
    
    return $self; # success - we hope!
    
}

=head2 get_Ensembl_SeqFeatures_contig

 Title   : get_Ensembl_SeqFeatures_contig (not used)
 Usage   : get_External_SeqFeatures_contig($ensembl_contig_identifier,
                                           $sequence_version,
					   $start,
					   $end);
 Function: Here only to return an empty list
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
    my $main_id;
    my ($query);

    #lists of variations to be returned
    my @variations;

    $id = uc $id;
    # if ID given is not dbSNP ref id (has other than number characters)
    if ($id =~ /\D/) {
	$query = qq{
	
	    SELECT p2.id, p1.acc, p1.version, p1.start, p1.end, p1.type,
	     	   p1.strand, p2.snpclass,  p2.snptype,
	     	   p2.observed, p2.seq5, p2.seq3,
	     	   p2.het, p2.hetse, p2.validated, p2.mapweight
	    FROM   Hit as p1, RefSNP as p2, SubSNP as p3
            WHERE  p3.altid = "$id"
                   AND p1.refsnpid = p2.id
                   AND p1.refsnpid = p3.refsnpid

		   };

    # else it is a dbSNP id
    } else {
	
	$query = qq{
	
	    SELECT p2.id, p1.acc, p1.version, p1.start, p1.end, p1.type,
	     	   p1.strand, p2.snpclass,  p2.snptype,
	     	   p2.observed, p2.seq5, p2.seq3,
	     	   p2.het, p2.hetse, p2.validated, p2.mapweight
	    FROM   Hit as p1, RefSNP as p2
            WHERE  p2.id = "$id"
                   AND p1.refsnpid = p2.id

		   };
    }

    #print STDERR "$query\n";
    my $sth = $self->prepare($query);
    my $res = $sth->execute();
    my $rows = $sth->rows();
    $rows || $self->throw("SNP not found or not mapped to a clone!");

  SNP:
    while( (my $arr = $sth->fetchrow_arrayref()) ) {
       
	my $allele_pos = '0';
	
	my ($dbsnp_id, $acc, $ver, $begin, $end, $postype, $strand, $class, $type,
	    $alleles, $seq5, $seq3, $het, $hetse,  $confirmed, $mapweight
	    ) = @{$arr};
	$main_id = $dbsnp_id;

        #snp info not valid
	$self->throw("SNP withdrawn. Reason: $type ") if $type ne 'notwithdrawn';

        # use the right vocabulary for the SNP status
        if ($confirmed eq 'no-info') {
	    $confirmed = "suspected";
        } else {
	    $confirmed =~ s/-/ /;
	    $confirmed = "proven $confirmed";
	}
	
	# the allele separator should be  '|'
	$alleles =~ s/\//\|/g;
	
	#prune flank sequences to 25 nt
	$seq5 = substr($seq5, -25, 25);
	$seq3 = substr($seq3, 0, 25);

	#add Ns to length of 25;
	$seq3 .= 'N' x ( 25 - length $seq3 ) if length($seq3) < 25 ;
	$seq5 = ('N' x ( 25 - length $seq5 ) ). $seq5 if length($seq5) < 25 ;

	#
	# prepare the output objects
	#

	#Variation
	my $acc_version = '';
	$acc_version .= uc $acc if $acc;
	$acc_version .= ".$ver" if $ver;

	my $snp = new Bio::EnsEMBL::ExternalData::Variation;
	if ($acc_version) {
	        $snp->seqname($acc_version);
		$snp->start($begin);
		$snp->end($end);
		$snp->strand($strand);
		$snp->original_strand($strand);
	}
	$snp->source_tag('dbSNP');
	$snp->status($confirmed);
	$snp->alleles($alleles);
	$snp->upStreamSeq($seq5);
	$snp->dnStreamSeq($seq3);
	$snp->score($mapweight); 
        $snp->het($het);
        $snp->hetse($hetse);

	#add SNP to the list
	push(@variations, $snp);

	#DBLink
	my $link = new Bio::Annotation::DBLink;
	$link->database('dbSNP');
	$link->primary_id($dbsnp_id);

	#add dbXref to Variation
	$snp->add_DBLink($link);

	#get alternative IDs
	my $primid = $snp->id;
	my $query2 = qq{
	    
	    SELECT p1.handle, p1.altid 
	    FROM   SubSNP as p1
            WHERE  p1.refsnpid = "$primid"

	    };

	my $sth2 = $self->prepare($query2);
	my $res2 = $sth2->execute();
	while( (my $arr2 = $sth2->fetchrow_arrayref()) ) {
	        
	    my ($handle, $altid
		) = @{$arr2};

	    my $link = new Bio::Annotation::DBLink;
	    $link->database($handle);
	    $link->primary_id($altid);
	    
	    #add dbXref to Variation
	    $snp->add_DBLink($link);
	}
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

    if ( ! defined $acc) {
		$self->throw("Two arguments are requided: embl_accession number and version_number!");
    }
    if ( ! defined $ver) {
		$self->throw("Two arguments are required: embl_accession number and version_number!");
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
	    	$self->throw("$stop is not a valid stop");
		}
    }
    if (defined $start and defined $stop) {
		if ($stop < $start) {
	    	$self->throw("$stop is smaller than $start not a valid start");
		}
    }

    my $acc_version = uc "$acc.$ver";


   # db query to return all variation information ; confidence attribute is gone!!
   my $query = qq{

       	SELECT  p1.start, p1.end, p1.type, p1.strand,
  	       p2.id, p2.snpclass,  p2.snptype,
  	       p2.observed, p2.seq5, p2.seq3,
  	       p2.het, p2.hetse,
               p2.validated, p2.mapweight
  		FROM   Hit as p1, RefSNP as p2
  		WHERE  p1.acc = "$acc" and p1.version = "$ver"
  	       AND p1.refsnpid = p2.id
	       };

   my $sth = $self->prepare($query);
   my $res = $sth->execute();

   SNP:
   while( (my $arr = $sth->fetchrow_arrayref()) ) {

		my $allele_pos = 0;

		my ($begin, $end, $hittype, $strand,
		$snpuid, $class, $type,
		$alleles, $seq5, $seq3, $het, $hetse,
		$confirmed, $mapweight,
		$subsnpid, $handle 
		) = @{$arr};

		#snp info not valid
		next SNP if $type ne 'notwithdrawn';
		next SNP if $mapweight > 2;


		#exclude SNPs outside the given $start-$end range
		if (defined $start) {
			next SNP if $begin < $start;
		}
		if (defined $stop) {
			next SNP if $end > $stop;
		}

		# use the right vocabulary for the SNP status
		if ($confirmed eq 'no-info') {
			$confirmed = "suspected";
		} else {
			$confirmed =~ s/-/ /;
			$confirmed = "proven $confirmed";
		}

		# the allele separator should be  '|'
		$alleles =~ s/\//\|/g;

		#prune flank sequences to 25 nt
		$seq5 = substr($seq5, -25, 25);
		$seq3 = substr($seq3, 0, 25);

		#add Ns to length of 25;
		$seq3 .= 'N' x ( 25 - length $seq3 ) if length($seq3) < 25 ;
		$seq5 = ('N' x ( 25 - length $seq5 ) ). $seq5 if length($seq5) < 25 ;

		#
		# prepare the output objects
		#

		#Variation
		my $snp = new Bio::EnsEMBL::ExternalData::Variation
			   (-start => $begin,
	    		-end => $end,
	    		-strand => $strand,
	    		-original_strand => $strand,
	    		-source_tag => 'dbSNP',
	    		-score  => $mapweight,
	    		-status => $confirmed,
	    		-alleles => $alleles,
            		-subsnpid => $subsnpid,
	    		);
		$snp->upStreamSeq($seq5);
		$snp->dnStreamSeq($seq3);
		$snp->het($het);
		$snp->hetse($hetse); 

		# set for compatibility to Virtual Contigs
		$snp->seqname($acc_version);

		#DBLink
		my $link = new Bio::Annotation::DBLink;
		$link->database('dbSNP');
		$link->primary_id($snpuid);
		$link->optional_id($acc_version);
		#add dbXref to Variation
		$snp->add_DBLink($link);

		#get alternative IDs
		my $primid = $snp->id;
		my $query2 = qq{ 
			SELECT p1.handle, p1.altid 
			FROM   SubSNP as p1
			WHERE  p1.refsnpid = "$primid"
		};

		my $sth2 = $self->prepare($query2);
		my $res2 = $sth2->execute();
		while( (my $arr2 = $sth2->fetchrow_arrayref()) ) {
			my ($handle, $altid) = @{$arr2};

			my $link = new Bio::Annotation::DBLink;

			print STDERR "Adding DBLink for $altid\n";

			$link->database($handle);
			$link->primary_id($altid);

			#add dbXref to Variation
			$snp->add_DBLink($link);
		}
		#add SNP to the list
		push(@variations, $snp);
	}

	return @variations;
}



=head2 get_Ensembl_SeqFeatures_clone_web

 Title   : get_Ensembl_SeqFeatures_clone_web
 Usage   :
 Function:
 Example :
 Returns : a list of lightweight Variation features.
 Args    : scalar in nucleotides (should default to 50)
           array of accession.version numbers

=cut

sub get_Ensembl_SeqFeatures_clone_web {
    my ($self,$glob,@acc) = @_;
    
    if (! defined $glob) {
        $self->throw("Need to call get_Ensembl_SeqFeatures_clone_web with a globbing parameter and a list of clones");
    }
    if (scalar(@acc) == 0) {
        $self->throw("Calling get_Ensembl_SeqFeatures_clone_web with empty list of clones!\n");
    }
    
    #lists of variations to be returned
    my @variations;
    my %hash;
    my $string;
    foreach my $a (@acc) {
        $a =~ /(\S+)\.(\d+)/;
        $string .= "'$1',";
        $hash{$1}=$2;
    }
    $string =~ s/,$//;
    my $inlist = "($string)";
    
    # db query to return all variation information in current GoldenPath; confidence attribute is gone!!
    # data are preprocessed to contain only relevent information (RefSNP.mapweight  is not needed)
    # denormalized SubSNP in

    my $query = qq{

        SELECT   gp.start, gp.end, gp.strand,
                 gp.acc, gp.version, gp.refsnpid,
                 gp.tcsid, gp.hgbaseid, rf.observed, rf.het, rf.hetse
        FROM   	 GPHit gp,RefSNP rf
        WHERE  	 gp.acc in $inlist and rf.id = gp.refsnpid
	ORDER BY gp.acc,gp.start    

              };

    &eprof_start('snp-sql-query');

    my $sth = $self->prepare($query);
    my $res = $sth->execute();

    &eprof_end('snp-sql-query');

    my $snp;
    my $cl;

    &eprof_start('snp-sql-object');

  SNP:
    while( (my $arr = $sth->fetchrow_arrayref()) ) {
        
        my ($begin, $end, $strand,
            $acc, $ver, $snpuid,
            $tscid, $hgbaseid, $alleles, $het, $hetse
           ) = @{$arr};

	$alleles =~ s/\//\|/g;

        my $acc_version="$acc.$ver";
	if ( defined $snp && $snp->end+$glob >= $begin && $acc_version eq $cl) {
            #ignore snp within glob area
            next SNP;
        }
        
        next SNP if $hash{$acc} != $ver;
        #
        # prepare the output objects
        #
        
        ### mega dodginess here: ideally, a Variation should be allowed to
        ### have several Locations. However, a Variation is-a SeqFeature,
        ### which can only have one. So instead, we'll return a list of
        ### Varations, each with a separate single location, but otherwise
        ### identical. That's clean-room engineering for you :-) 
        
        my $key=$snpuid.$acc;           # for purpose of filtering duplicates
        my %seen;                       # likewise
        
        
        if ( ! $seen{$key} )  {
            ## we're grabbing all the necessary stuff from the db in one
            ## SQL statement for speed purposes, so we have to do some
            ## duplicate filtering here.

            $seen{$key}++;
            
            #Variation
            $snp = new Bio::EnsEMBL::ExternalData::Variation
              (-start => $begin,
               -end => $end,
               -strand => $strand,
               -original_strand => $strand,
               -score => 1,
               -source_tag => 'dbSNP',
              );


	    $snp->alleles($alleles);
	    $snp->het($het);
	    $snp->hetse($hetse);

            
            my $link = new Bio::Annotation::DBLink;
            $link->database('dbSNP');
            $link->primary_id($snpuid);
            $link->optional_id($acc_version);
            #add dbXref to Variation
            $snp->add_DBLink($link);
	    if ($hgbaseid) {
	      my $link2 = new Bio::Annotation::DBLink;
	      $link2->database('HGBASE');
	      $link2->primary_id($hgbaseid);
	      $link2->optional_id($acc_version);
	      $snp->add_DBLink($link2);
	    }
	    if ($tscid) {
	      my $link3 = new Bio::Annotation::DBLink;
	      $link3->database('TSC-CSHL');
	      $link3->primary_id($tscid);
	      $link3->optional_id($acc_version);
	      #add dbXref to Variation
	      $snp->add_DBLink($link3);
	    }
            $cl=$acc_version;
            # set for compatibility to Virtual Contigs
            $snp->seqname($acc_version);
            #add SNP to the list
            push(@variations, $snp);
        }                               # if ! $seen{$key}
      }                                    # while a row from select statement

    &eprof_end('snp-sql-object');
    
    return @variations;
}

=head2 get_snp_info_between_two_refsnpids

 Title   : get_snp_info_between_two_refsnpids
 Usage   :
 Function:
 Example :
 Returns : a list of all snp info between start_refsnpid and end_refsnpid
 Args    : start_refsnpid and end_refsnpid
           
=cut

sub get_snp_info_between_two_internalids {

  my ($self,$start_intnum,$end_intnum) = @_;
  my ($query, @var_objs, %var_objs);
  if (!$end_intnum) {
    $end_intnum = $start_intnum;
  }
  
    $query = qq{
      SELECT r.id, r.snpclass, r.mapweight, r.observed, r.seq5, r.seq3, 
      h.acc, h.version, h.start, h.end, h.strand
	FROM   RefSNP as r, Hit as h
	  WHERE  r.id = h.refsnpid and snptype = "notwithdrawn" 
	    and r.internal_id between $start_intnum and $end_intnum
	  };
  
  my $sth=$self->prepare($query);
  
  my $res=$sth->execute();
  while (my $info = $sth->fetchrow_hashref()) {
    if ($info) {
      my $var_obj = $self->_objFromHashref($info);
      #$var_objs{$var_obj->snpid}=$var_obj;
      push (@var_objs, $var_obj);
    }
  }
  return @var_objs;
}
 
  

=head2 get_snp_info_by_refsnpid

 Title   : get_snp_info_by_refsnpid
 Usage   :
 Function:
 Example :
 Returns : a list of snp info by given refsnpid
 Args    : refsnpid
           
=cut

sub get_snp_info_by_refsnpid {

  my ($self,$refsnpid,$mouse) = @_;
  my (@infos,$query,%var_objs);
  
  if ($mouse) {
    $query = qq{
      SELECT t1.id, t1.snpclass, t1.snptype, t1.observed, t1.seq5, t1.seq3
	FROM   RefSNP as t1
	  WHERE  t1.id = "$refsnpid"
	};
  }
  else {
    $query = qq{
      SELECT t1.id, t1.snpclass, t1.snptype, t1.observed, t1.seq5, t1.seq3, 
      t2.acc, t2.version, t2.start, t2.end, t2.strand
	FROM   RefSNP as t1, Hit as t2 
	  WHERE  t1.id = t2.refsnpid and t1.mapweight <=2 and t1.id = "$refsnpid"
	};
  }
  
  my $sth=$self->prepare($query);
  
  my $res=$sth->execute();
  while (my $info = $sth->fetchrow_hashref()) {
    if ($info) {
      my $var_obj = $self->_objFromHashref($info);
      return $var_obj if $var_obj;
      
      #$var_objs{$var_obj->snpid}=$var_obj;
      #return values %var_objs;
    }
  }
}

sub _objFromHashref {
  my ($self,$info) = @_;
  
  my $acc_version = '';
  my $acc = $info->{acc};
  my $ver = $info->{version};
  $acc_version .= uc $acc if $acc;
  $acc_version .= ".$ver" if $ver;
  
  my $snp = new Bio::EnsEMBL::ExternalData::Variation;
  
  $snp->acc($info->{acc});
  $snp->version($info->{version});
  $snp->seqname($acc_version);
  $snp->start($info->{start});
  $snp->end($info->{end});
  $snp->strand($info->{strand});
  $snp->source_tag('dbSNP');
  #$snp->status($info->{confirmed});
  $snp->alleles($info->{observed});
  $snp->upStreamSeq($info->{seq5});
  $snp->dnStreamSeq($info->{seq3});
  $snp->score($info->{mapweight}); 
  #$snp->het($info->{het});
  #$snp->hetse($info->{hetse});
  $snp->snpid($info->{id});
  $snp->snpclass($info->{snpclass});

  #DBLink
  my $link = new Bio::Annotation::DBLink;
  $link->database('dbSNP');
  $link->primary_id($info->{id});
  
  #add dbXref to Variation
  $snp->add_DBLink($link);
  
  return $snp;
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

   return $self->_db_handle->prepare($string) if defined $self->_db_handle;
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

sub get_Hitcount {
    my ($self) = @_;
    my $sth=$self->prepare("select count(*) from RefSNP");
    my $res=$sth->execute();

    my ($count) = $sth->fetchrow_array();
   
    return $count;
}

sub get_max_refsnpid {
    my ($self) = @_;
    my $sth=$self->prepare("select max(id) from RefSNP");
    my $res=$sth->execute();

    my ($count) = $sth->fetchrow_array();
   
    return $count;
}

=head2 _lock_tables

 Title   : _lock_tables
 Usage   :
 Function:
 Example :
 Returns :
 Args    :


=cut

sub _lock_tables{
   my ($self,@tables) = @_;

   my $state;
   foreach my $table ( @tables ) {
       if( $self->{'_lock_table_hash'}->{$table} == 1 ) {
	   $self->warn("$table already locked. Relock request ignored");
       } else {
	   if( $state ) { $state .= ","; }
	   $state .= "$table write";
	   $self->{'_lock_table_hash'}->{$table} = 1;
       }
   }

   my $sth = $self->prepare("lock tables $state");
   my $rv = $sth->execute();
   $self->throw("Failed to lock tables $state") unless $rv;

}

=head2 _unlock_tables

 Title   : _unlock_tables
 Usage   :
 Function:
 Example :
 Returns :
 Args    :


=cut

sub _unlock_tables{
   my ($self,@tables) = @_;
   my $rv;
   my $sth = $self->prepare("unlock tables");
   $rv  = $sth->execute();
   $self->throw("Failed to unlock tables") unless $rv;
   %{$self->{'_lock_table_hash'}} = ();
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

   $obj->_unlock_tables();

   if( $obj->{'_db_handle'} ) {
       $obj->{'_db_handle'}->disconnect;
       $obj->{'_db_handle'} = undef;
   }
}

1;
