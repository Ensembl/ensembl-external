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

use Bio::EnsEMBL::DBDAS::BaseAdaptor;
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

This class implements L<Bio::EnsEMBL::DB::ExternalFeatureFactoryI>
interface for creating L<Bio::EnsEMBL::ExternalData::DAS::DAS.pm>
objects from an external DAS database. See
L<Bio::EnsEMBL::DB::ExternalFeatureFactoryI> for more details on how
to use this class.

The objects returned in a list are
L<Bio::EnsEMBL::DBSQL::SeqFeature> objects which might possibly contain
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
use Bio::EnsEMBL::DB::ExternalFeatureFactoryI;
use Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature;

# Object preamble - inherits from Bio::Root:RootI
@ISA = qw(Bio::Root::RootI Bio::EnsEMBL::DB::ExternalFeatureFactoryI);


sub new {
	my($class,$adaptor) = @_;
	my $self;
	$self = {};
	bless $self, $class;

	$self->_db_handle($adaptor->_db_handle());

	return $self; # success - we hope!

}

=head2 get_Ensembl_SeqFeatures_contig

 Title   : get_Ensembl_SeqFeatures_contig ()
 Usage   : get_Ensembl_SeqFeatures_contig($ensembl_contig_identifier,
 											$sequence_version,
					   						$start,
					   						$end);
 Function:
 Example :
 Returns :
 Args    :
 Notes   : This function sets the primary tag and source tag fields in the
           features so that higher level code can filter them by their type
           (das) and their data source name (dsn)

=cut

sub get_Ensembl_SeqFeatures_contig{
    my($self) = shift;
    my ($id, $ver, $start, $stop) = @_;

    if ( ! defined $id) {
		$self->throw("Contig ID required as argument to get_Ensembl_SeqFeatures_contig!");
    }

	my $dbh = $self->_db_handle();
	my @features = ();
	my $dsn = $dbh->dsn();

	if(my $segment = $dbh->segment(-ref=>$id)){
		foreach my $f ($segment->features()){
			next unless($f);	# sometimes get null features here: DAS bug?

			#print STDERR "Got DAS feature $f\n";
			#print STDERR "Got DAS start ", $f->start(), "\n";
			#print STDERR "Got DAS end ", $f->stop(), "\n";
			#print STDERR "Got DAS label ", $f->label, "\n";
			#print STDERR "Got DAS id ", $f->id, "\n";
			#print STDERR "Got DAS link ", $f->link, "\n";

			########################################################
			## Should do clipping here!
			########################################################

			my $type = $f->type();
			#print STDERR "Got DAS $type \n";
			unless (ref($f) && $f->isa("Bio::Das::Segment::Feature")){
				warn qq(Got a bad DAS feature "$f" from DSN: $dsn\n);
				next;
			}
			my $out = new Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature;
			$out->das_name($type);
			$out->das_id($f->id);
			$out->das_dsn($dsn);
			$out->start($f->start);
			$out->end($f->stop);
			$out->primary_tag('das');
			$out->source_tag($dsn);
			$out->strand($f->orientation);
			$out->phase($f->phase);   
			push(@features,$out);
		}
	}
	return(@features);

}




=head2 get_Ensembl_SeqFeatures_clone

 Title   : get_Ensembl_SeqFeatures_clone (not used)
 Function:
 Example :
 Returns :
 Args    :

=cut

sub get_Ensembl_SeqFeatures_clone{
	my ($self) = @_;
    #$self->warn("DAS external feature factories do not support fetches using clone IDs (use contig IDs)");
	my @tmp;
	return @tmp;
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
	
	$self->throw("Must give a contig ID to fetch_contig_Features!") unless defined $contig;
 	my @features = ();

    my $dbh = $self->{'_db_handle'};

	if(my $segment = $dbh->segment(-ref=>$contig)){
		foreach my $f ($segment->features()){
			my $out = new Bio::EnsEMBL::SeqFeature;
			my($c, $s, $e ) = $f =~ /(.*?)\/(\d+)\,(\d+)/io;
			$out->seqname    ($f->id);
			$out->start      ($s);
			$out->end        ($e);
			$out->strand     ($f->orientation);
			$out->phase      ($f->phase);   
			$out->primary_tag('das');

			push(@features,$out);
		}
	}
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
