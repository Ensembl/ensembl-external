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
use Bio::EnsEMBL::ExternalData::DAS::DASParser;

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
use URI::URL;
use HTTP::Request::Common;
use LWP::UserAgent;
use Bio::EnsEMBL::DB::ExternalFeatureFactoryI;
use Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature;
use Bio::EnsEMBL::ExternalData::DAS::DASParser;

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




=head2 get_Ensembl_SeqFeatures_DAS

 Title   : get_Ensembl_SeqFeatures_DAS ()
 Usage   : get_Ensembl_SeqFeatures_DAS($listref,
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

sub get_Ensembl_SeqFeatures_DAS {
    my ($self, $chr_name, $global_start, $global_end, $fpccontig_list_ref, $clone_list_ref, $contig_list_ref) = @_;
	my $URL_MAXLEN = 256;	# The longest GET string our DAS servers can handle.....?
	my $dbh 	   = $self->_db_handle();
	my $dsn 	   = $dbh->dsn();
    
    #print STDERR "In get_Ensembl_SeqFeatures_DAS for $dsn\n";

    my @cloneids   = @{$clone_list_ref};
    my @contigids  = @{$contig_list_ref};
    my @fpccontigids  = @{$fpccontig_list_ref};
    # A hash of URL lists keyed on there object type (chr, fpc, clone,contig)
    # This is needed to allow error code to know hat type of object we are dealing
    # with at run time.
    my %URLS = ();
    # The assembly level request URL
    $URLS{'chr'} = ["segment=$chr_name:$global_start,$global_end;"];
    # The FPC contig level request URL
    # needs to be added!
    # The clone level request URL(s)
    if(0){
	     my @clone_urls = ();
	     HOP: while(@cloneids){
		     my $url = "";
		     HOP2: while(@cloneids){
			     my $c = shift (@cloneids);
                 #print STDERR "Clone: $c\n";
			     if ( length($url . "segment=" . $c . ";") < $URL_MAXLEN){
				     $url = $url . "segment=" . $c . ";";
				     next HOP2;
			     } else {
				     push(@clone_urls, $url);
				     next HOP;
			     }
		     }
	         push(@clone_urls, $url);
	     }
         $URLS{'clone'} = \@clone_urls;
     }

    # The contig level request URL(s)
    if(1){
    	my @contig_urls = ();
	    DAS: while(@contigids){
		    my $url = "";
		    DAS2: while(@contigids){
			    my $c = shift (@contigids);
                #print STDERR "Contig: $c\n";
			    if ( length($url . "segment=" . $c . ";") < $URL_MAXLEN){
				    $url = $url . "segment=" . $c . ";";
				    next DAS2;
			    } else {
				    push(@contig_urls, $url);
				    next DAS;
			    }
		    }
	        push(@contig_urls, $url);
	     }
         $URLS{'contig'} = \@contig_urls;
     }

    #foreach my $k (keys %URLS){
    #    print STDERR "$k ====> ", join("\n", @{$URLS{$k}}), "\n";
    #}
    

    my $parser = new Bio::EnsEMBL::ExternalData::DAS::DASParser;
    my %DAS_FEATURES;
    $DAS_FEATURES{'FEATURES'} = [];
    
	my $ua = $dbh->agent;
	$ua->timeout(20);
	my $base = URI::URL->new($dbh->base());

	foreach my $type (keys %URLS){
        # get the list of URLs for this object type....
        my @urls = @{$URLS{$type}};
        #print STDERR "$type: URLS: ", join("\n", @urls), "\n";
        # loop over them requesting the DAS data...
        foreach my $u (@urls){
		    my $url = $base . "/" . "features?" . $u; # . "categorize=yes";
		    my $request = HTTP::Request->new(GET => "$url");
		    my $reply = $ua->request($request);
			# print STDERR "Timeout: ",$ua->timeout(),"\n";
            #print STDERR "BASE: $base\n";
            # print STDERR "FETCHING for $type:\n$url\n";
            #print STDERR "FETCHING $type for $dsn\n";

		    ### Check to see if we got a valid HTTP response - if not
		    ### send back a special seqfeature indicating an error condition that can
		    ### be parsed by the drawing code
		    my $REPLY_CODE = $reply->code();
		    my $DAS_CODE   = $reply->header('X-DAS-Status');
		    my $DAS_VER    = $reply->header('X-DAS-Version');
 		    if ($REPLY_CODE > 399 || $DAS_CODE > 399){
			    my $CODE = "DAS";
			    if ($REPLY_CODE > 399) {
				    $CODE = "HTTP error code: $REPLY_CODE ($DAS_VER)"; 
			    } else {
				    $CODE = "DAS error code:  $DAS_CODE ($DAS_VER)"; 
			    }
                my $ERROR_FEATURE = new Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature;
                $ERROR_FEATURE->id("__ERROR__");
                $ERROR_FEATURE->das_dsn($dsn);
                push (@{$DAS_FEATURES{'FEATURES'}}, $ERROR_FEATURE);
 
                warn "DAS ERROR for $dsn: $CODE\n";
                #warn "$url\n";
                #warn "DAS ERROR for $dsn: $CODE on URL:\n";
                #print STDERR $reply->content();
                next;
		     } else {
			 	#print STDERR "URL: $u $REPLY_CODE $DAS_CODE\n",$reply->content,"\n\n";
                my @features = $parser->parse($reply->content(), $dsn);
				#print STDERR "Features:\n\t", (join"\n\t",@features),"\n\n";
                push (@{$DAS_FEATURES{'FEATURES'}}, @features);
             }
         }
	}

    if(0){
        foreach my $feature (@{$DAS_FEATURES{'FEATURES'}}){
            #next unless $feature;
            print STDERR "SEG ID: ", $feature->seqname(), "\t";
            print STDERR "DSN: ", $feature->das_dsn(), "\t";
            print STDERR "FEATURE START: ", $feature->das_start(), "\t";
            print STDERR "FEATURE END: ", $feature->das_end(), "\t";
            print STDERR "FEATURE STRAND: ", $feature->das_strand(), "\t";
            print STDERR "FEATURE TYPE: ", $feature->das_type_id(), "\t";
            print STDERR "FEATURE ID: ", $feature->das_feature_id(), "\n";
        }
    }
    
	return(@{$DAS_FEATURES{'FEATURES'}});  # _MUST_ return a list or StaticContig breaks!
}









=head2 get_Ensembl_SeqFeatures_contig_list

 Title   : get_Ensembl_SeqFeatures_contig_list ()
 Usage   : get_Ensembl_SeqFeatures_contig_list($listref,
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

sub get_Ensembl_SeqFeatures_contig_list{
    my ($self) = shift;
    my ($contig_listref) = @_;

	## TC
	## This is a temporary fast DAS fetcher tuned for fetching features for a set of contigs
	## It does not use the request part of the DAS perl modules or the XML parser becasue (1) the Das perl API cannot handle 
	## multi-segment feature requests and (2) the XML parser can be slow and (3) [most important] we now
	## only have to do a single DAS request per source, per virtual contig.
	## It should be replaced when the DAS perl modules can handle it.

	my $URL_MAXLEN = 256;	# The longest GET string our DAS servers can handle.....?

	my $dbh 	= $self->_db_handle();
	my $dsn 	= $dbh->dsn();

	my @contig_ids = map { "segment=". $_->id() } @{$contig_listref};
 
	my @urls = ();

	DAS: while(@contig_ids){
		my $url = "features?";
		DAS2: while(@contig_ids){
			my $c = shift (@contig_ids);
			if ( length($url . ";" . $c) < $URL_MAXLEN){
				$url = $url . ";" . $c;
				#print STDERR "Current URL: ",$url, " \n"; 
				next DAS2;
			} else {
				#print STDERR "Saving URL: ",$url, " \n"; 
				push(@urls, $url);
				next DAS;
			}
		}
	push(@urls, $url);
	}

	my $ua = $dbh->agent;
	my $base = URI::URL->new(join '/',$dbh->base());

	my $xml = "";

	foreach my $u (@urls){
		my $url = $base . "/" . $u;
		my $request = HTTP::Request->new(GET => "$url");
		my $reply = $ua->request($request);

		### Check to see if we got a valid HTTP response - if not
		### send back a special seqfeature indicating an error condition that can
		### be parsed by the drawing code

		my $REPLY_CODE = $reply->code();
		my $DAS_CODE = $reply->header('X-DAS-Status');
		if ($REPLY_CODE > 399 || $DAS_CODE > 399){
			my $CODE = "DAS";
			if ($REPLY_CODE > 399) {
				$CODE = "HTTP error code: $REPLY_CODE"; 
			} else {
				$CODE = "DAS error code:  $DAS_CODE"; 
			}
			my @features = ();
			## create a fake contig to return as our "error feature"
			## (but make sure it is on this VC!)
			my $contig = $contig_listref->[0];
			my $out = new Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature;
			$out->seqname($contig->id());
			$out->das_id("$CODE");
			$out->id("__ERROR__");
			$out->das_dsn($dsn);
			$out->primary_tag('das');
			$out->source_tag($dsn);
			push(@features,$out);
			#print STDERR "************ DAS ERROR fetching from $dsn ****************\n";
			#print STDERR "************ DAS ERROR CODE: $CODE        ****************\n";
			return(@features);
		}
		$xml = $xml . "\n" . $reply->content();
	}


	my @lines = split ("\n", $xml);
	
	my $out = undef;
	my $seqname = undef;
	my @features = ();
	foreach my $line (@lines){
		if ($line =~ /<SEGMENT id="(.*?)"/){
			$seqname = $1;
			#print STDERR "seqname $1\n";
		}
		if ($line =~ /<FEATURE id="(.*?)"/){
			#print STDERR "id $1\n";
			$out = new Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature;
			$out->seqname($seqname);
			$out->das_id($1);
			$out->das_dsn($dsn);
			$out->primary_tag('das');
			$out->source_tag($dsn);
		}
		if ($line =~ /<TYPE id="(.*?)">null<\/TYPE>/){
			$out->das_name($1);
			#print STDERR "type $1\n";
		}
		if ($line =~ /<START>(.*?)<\/START>/){
			$out->start($1);
			#print STDERR "start $1\n";
		}
		if ($line =~ /<END>(.*?)<\/END>/){
			$out->end($1);
			#print STDERR "end $1\n";
		}
		if ($line =~ /<ORIENTATION>(.*?)<\/ORIENTATION>/){
			if ($1 eq "+"){
				$out->strand(1);
			} else {	
				$out->strand(-1);
			}		
			#print STDERR "strand $1\n";
		}
		if ($line =~ /<\/FEATURE/){
			push(@features,$out);
			#print STDERR "saved $out\n";
		}
	}

	return(@features);


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
	my @features = ();

    if ( ! defined $id) {
		$self->throw("Contig ID required as argument to get_Ensembl_SeqFeatures_contig!");
    }
	#print STDERR "$id: $start > $stop\n";

	if ($start > $stop){
		print STDERR "ERROR: Bad DAS request on contig $id -> st/ed: $start, $stop\n"; 
		return(@features);
	}

	my $dbh = $self->_db_handle();
	my $dsn = $dbh->dsn();
	my $segment = undef;

	eval {
		$segment = $dbh->segment(-ref=>$id);
	};
	if ($@){
		print STDERR "ERROR: Bad DAS request via DSN $dsn (ignoring)\n"; 
		return(@features);
	}

	my @xml_features = ();
	if($segment){
		eval {
			#print STDERR "Getting segment features from $dsn...\n";
			@xml_features = $segment->features();
			#print STDERR "Done with $dsn\n";
		};
		if ($@){
			print STDERR "ERROR: Bad DAS segment request via DSN $dsn (ignoring)\n"; 
			return(@features);
		}
		foreach my $f (@xml_features){
			next unless($f);	# sometimes get null features here: DAS bug?
			unless (ref($f) && $f->isa("Bio::Das::Segment::Feature")){
				warn qq(Got a bad DAS feature "$f" from DSN: $dsn\n);
				next;
			}
			my $out = new Bio::EnsEMBL::ExternalData::DAS::DASSeqFeature;
			$out->das_name($f->type());
			$out->das_id($f->id());
			$out->das_dsn($dsn);
			$out->start($f->start());
			$out->end($f->end());
			$out->primary_tag('das');
			$out->source_tag($dsn);
			my $ori = $f->orientation();
			if ($ori eq "+"){
				$out->strand(1);
			} elsif ($ori eq "-"){
				$out->strand(-1);
			} else {
				$out->strand(0);	# help!
			}
			$out->phase($f->phase());   
			push(@features,$out);
		}
	}
	return(@features);

}




=head2 get_Ensembl_SeqFeatures_clone_list

 Title   : get_Ensembl_SeqFeatures_clone_list (not used)
 Function:
 Example :
 Returns :
 Args    :

=cut

sub get_Ensembl_SeqFeatures_clone_list {
	my ($self) = @_;
    #$self->warn("DAS external feature factories do not support fetches using clone IDs (use contig IDs)");
	
	my @tmp;
	return @tmp;
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
