# EnsEMBL Gene reading writing adaptor for mySQL
#
# Copyright EMBL-EBI 2002
#
# Author: Heikki Lehvaslaiho
# 
# Date : 09.08.2002
#

=head1 NAME

Bio::EnsEMBL::ExternalData::SNPSQL::SNPAdaptor

=head1 SYNOPSIS

A SNP adaptor which sits over a SNP database.  Provides a means of getting
SNPs out of a SNP database as Bio::EnsEMBL::ExternalData::Variation objects. 

=head1 CONTACT

  Arne Stabenau: stabenau@ebi.ac.uk
  Heikki Lehvaslaiho: heikki@ebi.ac.uk
  Ewan Birney  : birney@ebi.ac.uk
  Graham McVicker : mcvicker@ebi.ac.uk

=head1 APPENDIX

=cut

use strict;

package Bio::EnsEMBL::ExternalData::SNPSQL::SNPAdaptor;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::ExternalData::Variation;
use Bio::EnsEMBL::Utils::Eprof qw( eprof_start eprof_end);

use vars '@ISA';

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


#use constructor inherited from Bio::EnsEMBL::BaseAdaptor


=head2 fetch_by_SNP_id

 Title   : fetch_by_SNP_id
 Usage   : $snp_adaptor->fetch_by_snp_id($refsnp_id);
 Function:

           Retrieve SNPs using a valid snp id. The ssnp id may be
           a dbSNP id or a snp id for another database. If the
           database contains more than one location for a SNP
           each location will be written into its own object.

 Example :
 Returns : an array of L<Bio::EnsEMBL::ExternalData::Variation.pm> objects
 Args    : id as determined by this database


=cut

sub fetch_by_SNP_id {
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

    return \@variations;
}



=head2 fetch_by_clone_accession_vesion

 Title   : fetch_by_clone_accession_version
 Usage   : fetch_by_clone_accession_version($embl_accession_number,
		  		          $sequence_version,$start,$end);
 Function:

    The semantics of this method is as follows:
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

sub fetch_by_clone_accession_version {
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

	return \@variations;
}



=head2 fetch_between_refsnpids

 Title   : fetch_between_refsnpids
 Usage   :
 Function:
 Example :
 Returns : a list of all snp info between start_refsnpid and end_refsnpid
 Args    : start_refsnpid and end_refsnpid
           
=cut

sub fetch_between_refsnp_ids {
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
  return \@var_objs;
}
 
  

=head2 fetch_by_refsnpid

 Title   : fetch_by_refsnpid
 Usage   :
 Function:
 Example :
 Returns : a list of snp info by given refsnpid
 Args    : refsnpid, mouse_flag
           
=cut

sub fetch_by_refsnpid {

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
  



#=head2 get_Ensembl_SeqFeatures_clone_web

# Title   : get_Ensembl_SeqFeatures_clone_web
# Usage   :
# Function:
# Example :
# Returns : a list of lightweight Variation features.
# Args    : scalar in nucleotides (should default to 50)
#           array of accession.version numbers

#=cut

#sub get_Ensembl_SeqFeatures_clone_web {
#    my ($self,$glob,@acc) = @_;
    
#    if (! defined $glob) {
#        $self->throw("Need to call get_Ensembl_SeqFeatures_clone_web with a globbing parameter and a list of clones");
#    }
#    if (scalar(@acc) == 0) {
#        $self->throw("Calling get_Ensembl_SeqFeatures_clone_web with empty list of clones!\n");
#    }
    
#    #lists of variations to be returned
#    my @variations;
#    my %hash;
#    my $string;
#    foreach my $a (@acc) {
#        $a =~ /(\S+)\.(\d+)/;
#        $string .= "'$1',";
#        $hash{$1}=$2;
#    }
#    $string =~ s/,$//;
#    my $inlist = "($string)";
    
#    # db query to return all variation information in current GoldenPath; confidence attribute is gone!!
#    # data are preprocessed to contain only relevent information (RefSNP.mapweight  is not needed)
#    # denormalized SubSNP in

#    my $query = qq{

#        SELECT   gp.start, gp.end, gp.strand,
#                 gp.acc, gp.version, gp.refsnpid,
#                 gp.tcsid, gp.hgbaseid, rf.observed, rf.het, rf.hetse
#        FROM   	 GPHit gp,RefSNP rf
#        WHERE  	 gp.acc in $inlist and rf.id = gp.refsnpid
#	ORDER BY gp.acc,gp.start    

#              };

#    &eprof_start('snp-sql-query');

#    my $sth = $self->prepare($query);
#    my $res = $sth->execute();

#    &eprof_end('snp-sql-query');

#    my $snp;
#    my $cl;

#    &eprof_start('snp-sql-object');

#  SNP:
#    while( (my $arr = $sth->fetchrow_arrayref()) ) {
        
#        my ($begin, $end, $strand,
#            $acc, $ver, $snpuid,
#            $tscid, $hgbaseid, $alleles, $het, $hetse
#           ) = @{$arr};

#	$alleles =~ s/\//\|/g;

#        my $acc_version="$acc.$ver";
#	if ( defined $snp && $snp->end+$glob >= $begin && $acc_version eq $cl) {
#            #ignore snp within glob area
#            next SNP;
#        }
        
#        next SNP if $hash{$acc} != $ver;
#        #
#        # prepare the output objects
#        #
        
#        ### mega dodginess here: ideally, a Variation should be allowed to
#        ### have several Locations. However, a Variation is-a SeqFeature,
#        ### which can only have one. So instead, we'll return a list of
#        ### Varations, each with a separate single location, but otherwise
#        ### identical. That's clean-room engineering for you :-) 
        
#        my $key=$snpuid.$acc;           # for purpose of filtering duplicates
#        my %seen;                       # likewise
        
        
#        if ( ! $seen{$key} )  {
#            ## we're grabbing all the necessary stuff from the db in one
#            ## SQL statement for speed purposes, so we have to do some
#            ## duplicate filtering here.

#            $seen{$key}++;
            
#            #Variation
#            $snp = new Bio::EnsEMBL::ExternalData::Variation
#              (-start => $begin,
#               -end => $end,
#               -strand => $strand,
#               -original_strand => $strand,
#               -score => 1,
#               -source_tag => 'dbSNP',
#              );


#	    $snp->alleles($alleles);
#	    $snp->het($het);
#	    $snp->hetse($hetse);

            
#            my $link = new Bio::Annotation::DBLink;
#            $link->database('dbSNP');
#            $link->primary_id($snpuid);
#            $link->optional_id($acc_version);
#            #add dbXref to Variation
#            $snp->add_DBLink($link);
#	    if ($hgbaseid) {
#	      my $link2 = new Bio::Annotation::DBLink;
#	      $link2->database('HGBASE');
#	      $link2->primary_id($hgbaseid);
#	      $link2->optional_id($acc_version);
#	      $snp->add_DBLink($link2);
#	    }
#	    if ($tscid) {
#	      my $link3 = new Bio::Annotation::DBLink;
#	      $link3->database('TSC-CSHL');
#	      $link3->primary_id($tscid);
#	      $link3->optional_id($acc_version);
#	      #add dbXref to Variation
#	      $snp->add_DBLink($link3);
#	    }
#            $cl=$acc_version;
#            # set for compatibility to Virtual Contigs
#            $snp->seqname($acc_version);
#            #add SNP to the list
#            push(@variations, $snp);
#        }                               # if ! $seen{$key}
#      }                                    # while a row from select statement

#    &eprof_end('snp-sql-object');
    
#    return @variations;
#}

1;
