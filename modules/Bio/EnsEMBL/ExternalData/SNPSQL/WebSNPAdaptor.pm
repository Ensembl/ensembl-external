#$Id$
#
# BioPerl module for Bio::EnsEMBL::ExternalData::SNPSQL::DBAdapter
#
# Cared for by Heikki Lehvaslaiho <heikki@ebi.ac.uk>
#
# Copyright Heikki Lehvaslaiho
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::SNPSQL::WebSNP - Class for a sequence variation
database providing external features for EnsEMBL

=head1 SYNOPSIS

   # first make an Object which conforms to interface
   # Bio::EnsEMBL::DB::ExternalFeatureFactoryI
   $snpdb = Bio::EnsEMBL::ExternalData::SNPSQL::WebSNPAdaptor->new( -dbname => 'snp'
							  -user => 'root'
							  );

   # you can make an obj with external databases
   $dbobj = Bio::EnsEMBL::DBSQL::WebSNPAdaptor->new( -host => 'localhost',
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


This class implements L<Bio::EnsEMBL::DB::ExternalFeatureFactoryI>
interface for creating L<Bio::EnsEMBL::ExternalData::Variation.pm>
objects from a relational sequence variation database. See
L<Bio::EnsEMBL::DB::ExternalFeatureFactoryI> for more details on how
to use this class.

The objects returned in a list are
L<Bio::EnsEMBL::ExternalData::Variation> objects which contain
L<Bio::Annotation::DBLink> objects to give unique IDs in various
Variation databases.

This version uses the relational mySQL representation of the
dbSNP exchange XML for build 89.

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

package Bio::EnsEMBL::ExternalData::SNPSQL::WebSNPAdaptor;

use strict;
use vars qw(@ISA);
use DBI;
use Bio::EnsEMBL::ExternalData::Variation;
use Bio::EnsEMBL::ExternalData::SNPSQL::CoreSNPAdaptor;

# Object preamble - inherits from Bio::Root:RootI
@ISA = qw(Bio::Root::RootI Bio::EnsEMBL::ExternalData::SNPSQL::CoreSNPAdaptor);

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





=head2 get_Ensembl_SeqFeatures_clone_web

 Title   : get_Ensembl_SeqFeatures_clone_web
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_Ensembl_SeqFeatures_clone_web{
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

   # db query to return all variation information ; confidence attribute is gone!!

   my $query = qq{

   		SELECT	p1.start, p1.end, p1.strand,
  	       		p1.acc,p1.version,p2.id,
           		p2.snptype,p2.mapweight  
		FROM   	Hit as p1, RefSNP as p2
  		WHERE  	acc in $inlist
        AND 	p1.refsnpid = p2.id
  	    order by start
	};


   my $sth = $self->prepare($query);
   my $res = $sth->execute();
   my $snp;
   my $cl;
 SNP:
   while( (my $arr = $sth->fetchrow_arrayref()) ) {
       
       my ($begin, $end,$strand,
	   $acc,$ver,$snpuid,$type,$mapweight 
	   ) = @{$arr};
       
       my $acc_version="$acc.$ver";

       #snp info not valid
       next SNP if $type ne 'notwithdrawn';
       next SNP if $mapweight > 2;

       if ( defined $snp && $snp->end+$glob >= $begin && $acc_version eq $cl) {
	   #ignore snp within glob area
	   next SNP;
       }
       
       next SNP if $hash{$acc} != $ver;
       #
       # prepare the output objects
       #
       
       #Variation
       $snp = new Bio::EnsEMBL::ExternalData::Variation(-start => $begin,
	    												-end => $end,
	    												-score => $mapweight,
	    												-strand => $strand,
	    												-source_tag => 'dbSNP',
	    												);

       my $link = new Bio::Annotation::DBLink;
       $link->database('dbSNP');
       $link->primary_id($snpuid);
       $link->optional_id($acc_version);
       #add dbXref to Variation
       $snp->add_DBLink($link);

	   my $altquery = qq{
		   SELECT p1.handle, p1.altid 
		   FROM   SubSNP as p1
		   WHERE  p1.refsnpid = "$snpuid"
	   };
	   
       my $sth2 = $self->prepare($altquery);
       my $res2 = $sth2->execute();
       while(my ($handle, $altid) = $sth2->fetchrow_array()){	    
		   my $link = new Bio::Annotation::DBLink;
		   $link->database($handle);
		   $link->primary_id($altid);
		   #add dbXref to Variation
		   $snp->add_DBLink($link);
       }
	   

       $cl=$acc_version;
       # set for compatibility to Virtual Contigs
       $snp->seqname($acc_version);
       #add SNP to the list
       push(@variations, $snp);
   }

   return @variations;
}


