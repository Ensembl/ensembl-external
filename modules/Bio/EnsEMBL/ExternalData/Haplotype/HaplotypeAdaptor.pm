# 
# BioPerl module for Bio::EnsEMBL::ExternalData::Haplotype::HaplotypeAdaptor
# 
# Cared for by Tony Cox <avc@sanger.ac.uk>
#
# Copyright EnsEMBL
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

HaplotypeAdaptor - DESCRIPTION of Object

  This object represents a database of haplotypes.

=head1 SYNOPSIS

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::ExternalData::Haplotype::HaplotypeAdaptor;
use Bio::EnsEMBL::ExternalData::Haplotype::Haplotype;

$hapdb = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
                                             -user   => 'ensro',
                                             -dbname => 'haplotype_5_28',
                                             -host   => 'ecs3d',
                                             -driver => 'mysql',
                                            );
my $hap_adtor = Bio::EnsEMBL::ExternalData::Haplotype::HaplotypeAdaptor->new($hapdb);

$hap  = $hap_adtor->get_Haplotype_by_id('B10045');  # Haplotype id

### You can add the HaplotypeAdaptor as an 'external adaptor' to the 'main'
### Ensembl database object, then use it as:

$ensdb = Bio::EnsEMBL::DBSQL::DBAdaptor->new( ... );

$ensdb->add_ExternalAdaptor('haplotype', $hap_adtor);

# then later on, elsewhere: 
$hap_adtor = $ensdb->get_ExternalAdaptor('haplotype');
# also available:
$ensdb->list_ExternalAdaptors();
$ensdb->remove_ExternalAdaptor('haplotype');

=head1 DESCRIPTION

This module is an entry point into a database of haplotypes,

The objects can only be read from the database, not written. (They are
loaded ussing a separate perl script).

For more info, see Haplotype.pm

=head1 CONTACT

 Tony Cox <Lavc@sanger.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::ExternalData::Haplotype::HaplotypeAdaptor;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::Object

use Bio::Root::Object;
use DBI;

use Bio::DBLinkContainerI;
use Bio::Annotation::DBLink;
use Bio::EnsEMBL::ExternalData::Haplotype::Haplotype;
use Bio::EnsEMBL::ExternalData::Haplotype::Pattern;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


=head2 fetch_Haplotype_by_chr_start_end

 Title   : fetch_Haplotype_by_chr_start_end
 Usage   : $db->fetch_Haplotype_by_chr_start_end('B10045');
 Function: find haplotypes based on chromosomeal position.
 Example :
 Returns : a list of Haplotype objects, undef otherwise
 Args    : chr start, chr end

=cut

sub fetch_Haplotype_by_chr_start_end  {
    my ($self, $chr, $s, $e, $is_lite) = @_; 
    
    my $q = qq(
        select 
			block_id
        from 
			block
        where
        	chr_end>= $s
        and
        	chr_start<= $e
        and
        	chr_name = $chr
        group by block_id
    );
    
    my $sth = $self->prepare($q);
    $sth->execute();

    my $rowhash = undef;
    my @haps = ();

    while ($rowhash = $sth->fetchrow_hashref()) {
        return() unless keys %{$rowhash};
		if($is_lite){
	        my $hap = $self->fetch_lite_Haplotype_by_id($rowhash->{'block_id'});
        	push (@haps,$hap); 
		} else {
	        my $hap = $self->fetch_Haplotype_by_id($rowhash->{'block_id'});
        	push (@haps,$hap); 
		}
    }
    
    return(@haps);
}                                       


=head2 fetch_lite_Haplotype_by_id

 Title   : fetch_lite_Haplotype_by_id
 Usage   : $db->fetch_lite_Haplotype_by_id('B10045');
 Function: fetch "shallow" haplotype object based on an ID.
 Example :
 Returns : a list of Haplotype objects, undef otherwise
 Args    : chr start, chr end

=cut

sub fetch_lite_Haplotype_by_id {
    my ($self, $id) = @_; 

    my $q = qq(
        select 
            chr_start,chr_end,chr_name
        from 
			block
        where
            block_id = "$id"
        group by 
            block_id
    );

    my $sth = $self->prepare($q);
    $sth->execute();
    my $rowhash = $sth->fetchrow_hashref;
    return() unless keys %{$rowhash};
    
    my $hap = undef;
    $hap = new Bio::EnsEMBL::ExternalData::Haplotype::Haplotype($self);
    $hap->start($rowhash->{'chr_start'});
    $hap->end($rowhash->{'chr_end'});
    $hap->chr_name($rowhash->{'chr_name'});
    $hap->id($id);
	
    return($hap);
}

=head2 fetch_Haplotype_by_id

 Title   : fetch_Haplotype_by_id
 Usage   : $db->fetch_Haplotype_by_id('B10045');
 Function: fetch haplotype object based on an ID.
 Example :
 Returns : a list of Haplotype objects, undef otherwise
 Args    : chr start, chr end

=cut

sub fetch_Haplotype_by_id {
    my ($self, $id) = @_; 

    my $q = qq(
        select 
            block_id, sequence_id, snp_required, 
            first_reference_position, last_reference_position,
            first_polymorphism_index, last_polymorphism_index,
            chr_start,chr_end,chr_name
        from 
			block
        where
            block_id = "$id"
        group by 
            block_id
    );


    my $sth = $self->prepare($q);
    $sth->execute();

    my $rowhash = undef;
    my @pats = ();
    my $hap = undef;
    
    #first we get the high level haplotype block info....
    $rowhash = $sth->fetchrow_hashref;
    return() unless keys %{$rowhash};
    
    $hap = new Bio::EnsEMBL::ExternalData::Haplotype::Haplotype($self);
    $hap->contig_id($rowhash->{'sequence_id'});
    $hap->start($rowhash->{'chr_start'});
    $hap->end($rowhash->{'chr_end'});
    $hap->snp_req($rowhash->{'snp_required'});
    $hap->chr_name($rowhash->{'chr_name'});    
    my $bid = $hap->id($rowhash->{'block_id'});
        
    # ....next we get the SNP IDs via their chromosomal index
    my $q1 = qq(
        select 
            polymorphism_id 
        from 
            polymorphism_block_map 
        where 
            block_id = "$bid"
		and 
			ld_status = "1"
        );
    
    my $sth1 = $self->prepare($q1);
    $sth1->execute();
    my @ids = ();
    while (my $s = $sth1->fetchrow_array){
        push (@ids, $s);
    }
    $hap->snps(\@ids);
    
    # ....next we get the consensus patterns for this haplotype block
    my $q2 = qq(
        select pattern_id, sample_count, haplotype_pattern 
        from pattern 
        where block_id = "$bid");

    my $sth2 = $self->prepare($q2);
    $sth2->execute();

    HOP: while (my($pattern_id, $count, $pattern) = $sth2->fetchrow_array) {
		
		#if ($pattern =~ /\-/){
		#	print STDERR "Skipping pattern: $pattern\n";
		#	next HOP;
		#}
		
        my $pat = new Bio::EnsEMBL::ExternalData::Haplotype::Pattern($self->adaptor, $pattern_id, $count, $pattern);
        # ....next we get the classified  patterns for this consensus block
        $pat->block_id($bid);
        my $q3 = qq( select sample_id, pattern_id, haplotype_string 
                    from haplotype 
                    where pattern_id = "$pattern_id"
                );
        my $sth3 = $self->prepare($q3);
        $sth3->execute();

        my %samples = ();
        my $sample_count = 0;

        while (my($sample_id, $pattern_id, $haplotype_string) = $sth3->fetchrow_array) {

                $samples{$sample_id} = uc($haplotype_string);
                $sample_count++;
                #print STDERR "saving classified sample ($sample_count) $sample_id as  $pattern\n"; 
        }
        
        $pat->samples(\%samples);
        $hap->samples_count($sample_count);
        
         

        # ....next we get the unclassified patterns for this consensus block
        my $unclassified_sample_count = 0;
        my %unclassified_samples = ();
        my $q4 = qq( select sample_id, haplotype_string 
                    from haplotype 
                    where pattern_id = ""
                    and block_id = "$bid"
                );
        my $sth4 = $self->prepare($q4);
        $sth4->execute();

        while (my($sample_id, $haplotype_string) = $sth4->fetchrow_array) {
                $unclassified_samples{$sample_id} = $haplotype_string;     
                $unclassified_sample_count++;
                #print STDERR "saving unclassified sample $sample_id as  $pattern\n"; 
        }
        $pat->unclassified_samples(\%unclassified_samples);
        $hap->unclassified_samples_count($unclassified_sample_count);


        push (@pats,$pat); 
    }
    
    $hap->patterns(\@pats);
    return($hap);
}

# set/get handle on ensembl database
sub _ensdb {

  my ($self,$value) = @_;
  if( defined $value) {$self->{'_ensdb'} = $value;}
  
  return $self->{'_ensdb'};
}


# get/set handle on haplotype database
sub _hapdb {

  my ($self,$value) = @_;
  if( defined $value) {$self->{'_hapdb'} = $value;}
  
  return $self->{'_hapdb'};
}

# get/set handle on haplotype database
sub adaptor {

  my ($self,$value) = @_;
  if( defined $value) {
    $self->{'_adaptor'} = $value;
  }
  return $self->{'_adaptor'};
}

# set/get handle on haplotype database
sub _db_handle {

  my ($self,$value) = @_;
  if( defined $value) {$self->{'_db_handle'} = $value;}
  return $self->{'_db_handle'};
}

sub DESTROY {

   my ($self) = @_;
   if( $self->{'_db_handle'} ) {
       $self->{'_db_handle'}->disconnect;
       $self->{'_db_handle'} = undef;
   }
}
