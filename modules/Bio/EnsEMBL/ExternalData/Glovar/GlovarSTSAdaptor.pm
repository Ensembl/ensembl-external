# 
# BioPerl module for Bio::EnsEMBL::ExternalData::Glovar::GlovarSTSAdaptor
# 
# Cared for by Tony Cox <avc@sanger.ac.uk>
#
# Copyright EnsEMBL
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

GlovarSTSAdaptor - DESCRIPTION of Object

  Database adaptor for getting STSs from Glovar.

=head1 SYNOPSIS

$glodb = Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor->new(
                                         -user   => 'ensro',
                                         -dbname => 'snp',
                                         -host   => 'go_host',
                                         -driver => 'Oracle');

my $glovar_adaptor = $glodb->get_GlovarSTSAdaptor;

$var_listref  = $glovar_adaptor->fetch_all_by_Slice($slice);  # grab the lot!


=head1 DESCRIPTION

This module is an entry point into a glovar database,

Objects can only be read from the database, not written. (They are
loaded using a separate system).

=head1 CONTACT

 Tony Cox <avc@sanger.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal
methods are usually preceded with a _

=cut

package Bio::EnsEMBL::ExternalData::Glovar::GlovarSTSAdaptor;

use strict;

use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor;
use Bio::EnsEMBL::Utils::Eprof('eprof_start','eprof_end','eprof_dump');

use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor);


=head2 fetch_all_by_Slice

  Arg [1]    : Bio::EnsEMBL::Slice $slice
  Arg [2]    : (optional) boolean $is_lite
               Flag indicating if 'light weight' variations should be obtained
  Example    : svars = @{$glovar_adaptor->fetch_all_by_Slice($slice)};
  Description: Retrieves a list of variations on a slice in slice coordinates 
  Returntype : Listref of Bio::EnsEMBL::Variation objects
  Exceptions : none
  Caller     : Bio::EnsEMBL::Slice::get_all_ExternalVariations

=cut

sub fetch_all_by_Slice {
    my ($self, $slice, $is_light) = @_;

    unless($slice->assembly_name() && $slice->assembly_version()){
        warn("Cannot determine assembly name and version from Slice in GlovarAdaptor!\n");
        return([]);
    }

    my @f = ();
    if($is_light){
        push @f, @{$self->fetch_Light_STS_by_chr_start_end($slice)};
    } else {
        push @f, @{$self->fetch_STS_by_chr_start_end($slice)};
    } 
    return(\@f); 
}


=head2 fetch_Light_STS_by_chr_start_end

 Title   : fetch_Light_STS_by_chr_start_end
 Usage   : $db->fetch_Light_STS_by_chr_start_end($slice);
 Function: find lightweight variations by chromosomal location.
 Example :
 Returns : a list ref of very light SNP objects - designed for drawing only.
 Args    : slice

=cut

sub fetch_Light_STS_by_chr_start_end  {
    my ($self, $slice) = @_; 
    my $slice_chr    = $slice->chr_name();
    my $slice_start  = $slice->chr_start();
    my $slice_end    = $slice->chr_end();
    my $ass_name     = $slice->assembly_name();
    my $ass_version  = $slice->assembly_version();

    &eprof_start('glovar_sts1');

    ## NOTES:
    ## 1. this query only gets ExoSeq STSs (sts_summary.assay_type = 8)
    ## 2. the query is not speed-optimized, since it uses ms.end_coordinate in
    ##    the WHERE clause which is not indexed (but there is no other easy
    ##    way to get the data
    my $q = qq(
        SELECT 
                ss.id_sts,
                (ssm.contig_orientation * ms.start_coordinate)
                    + ssm.start_coordinate - 1 as start_coord,
                (ssm.contig_orientation * ms.end_coordinate)
                    + ssm.start_coordinate - 1 as end_coord,
                ss.sts_name,
                length(ss.sense_oligoprimer) as sen_len,
                length(ss.antisense_oligoprimer) as anti_len,
                ss.pass_status,
                ms.is_revcomp as ori,
                ssm.contig_orientation as chr_strand,
                ss.is_private as private
        FROM    chrom_seq cs,
                database_dict dd,
                seq_seq_map ssm,
                mapped_sts ms,
                sts_summary ss
        WHERE   cs.database_seqname = '$slice_chr'
        AND     dd.database_name = '$ass_name'
        AND     dd.database_version = '$ass_version'
        AND     dd.id_dict = cs.database_source
        AND     ssm.id_chromseq = cs.id_chromseq
        AND     ms.id_sequence = ssm.sub_sequence
        AND     ss.id_sts = ms.id_sts
        AND     ss.assay_type = 8
        AND     ms.start_coordinate < ('$slice_end' - ssm.start_coordinate + 1)
        AND     ms.end_coordinate > ('$slice_start' - ssm.start_coordinate + 1)
        ORDER BY 
                start_coord
    );
    
    my $sth;
    eval {
        $sth = $self->prepare($q);
        $sth->execute();
    }; 
    if ($@){
        warn("ERROR: SQL failed in GlovarAdaptor->fetch_Light_STS_by_chr_start_end()!\n$@");
        return([]);
    }

    my @features = ();
    my %passmap = ( 1 => 'pass', 2 => 'fail' );
    while (my $row = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$row};
        next if $row->{'PRIVATE'};
        my $sen_start = $row->{'START_COORD'};
        my $sen_end = $row->{'START_COORD'} + $row->{'SEN_LEN'};
        my $sen_len = $sen_end - $sen_start;
        my $anti_start = $row->{'END_COORD'};
        my $anti_end = $row->{'END_COORD'} + $row->{'ANTI_LEN'};
        my $anti_len = $anti_end - $anti_start;
        my $pass = $passmap{$row->{'PASS_STATUS'}} || "unknown";
        push @features, Bio::EnsEMBL::DnaDnaAlignFeature->new_fast({
                '_analysis'      =>  'glovar_sts',
                '_gsf_start'    =>    $sen_start - $slice_start + 1,
                '_gsf_end'      =>    $sen_end - $slice_start + 1,
                '_gsf_strand'   =>    $row->{'CHR_STRAND'},
                '_seqname'       =>  $slice->name,
                '_hstart'        =>  1,
                '_hend'          =>  $sen_len,
                '_hstrand'       =>  1, # fix
                '_hseqname'      =>  $row->{'STS_NAME'},
                '_gsf_seq'       =>  $slice,
                '_cigar_string'  =>  $sen_len."M",
                '_id'            =>  $row->{'ID_STS'},
                '_database_id'   =>  $row->{'ID_STS'},
                '_pass'          =>  $pass,
        });
        push @features, Bio::EnsEMBL::DnaDnaAlignFeature->new_fast({
                '_analysis'      =>  'glovar_sts',
                '_gsf_start'    =>    $anti_start - $slice_start + 1,
                '_gsf_end'      =>    $anti_end - $slice_start + 1,
                '_gsf_strand'   =>    $row->{'CHR_STRAND'},
                '_seqname'       =>  $slice->name,
                '_hstart'        =>  1,
                '_hend'          =>  $anti_len,
                '_hstrand'       =>  1, # fix
                '_hseqname'      =>  $row->{'STS_NAME'},
                '_gsf_seq'       =>  $slice,
                '_cigar_string'  =>  $anti_len."M",
                '_id'            =>  $row->{'ID_STS'},
                '_database_id'   =>  $row->{'ID_STS'},
                '_pass'          =>  $pass,
        });
    }
    
    &eprof_end('glovar_sts1');
    #&eprof_dump(\*STDERR);
    
    return(\@features);
}                                       

=head2 fetch_STS_by_chr_start_end

 Title   : fetch_STS_by_chr_start_end
 Usage   : $db->fetch_STS_by_chr_start_end($slice);
 Function: find full variations by chromosomal location.
 Example :
 Returns : a list ref SNP objects.
 Args    : slice

=cut

sub fetch_STS_by_chr_start_end  {
    my ($self,$slice) = @_; 
    my @vars = ();

    ## to be inplemented ...
    
    return(\@vars);
}                                       

=head2 fetch_STS_by_id

  Arg[1]      : String - STS ID
  Example     : my $sts = $glovar_adaptor->fetch_STS_by_id($id);
  Description : retrieve STSs from Glovar by ID
  Return type : List of Bio::EnsEMBL::ExternalData::Variation

=cut

sub fetch_STS_by_id  {
    my ($self, $id) = @_;
    my @vars = ();
    
    ## to be inplemented ...

    return \@vars;
}


sub track_name {
    my ($self) = @_;    
    return("GlovarSTS");
}

1;

