=head1 NAME

Bio::EnsEMBL::ExternalData::Glovar::GlovarSTSAdaptor -
GlovarSTSAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

$glodb = Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor->new(
                                         -user   => 'ensro',
                                         -pass   => 'secret',
                                         -dbname => 'snp',
                                         -host   => 'go_host',
                                         -driver => 'Oracle'
);
my $glovar_adaptor = $glodb->get_GlovarSTSAdaptor;
$listref  = $glovar_adaptor->fetch_all_by_Slice($slice);

=head1 DESCRIPTION

This module is an entry point into a Glovar database. It allows you to retrieve
STSs from Glovar.

=head1 AUTHOR

Tony Cox <avc@sanger.ac.uk>
Patrick Meidl <pm2@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::ExternalData::Glovar::GlovarSTSAdaptor;

use strict;

use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor;
use Bio::EnsEMBL::Utils::Eprof('eprof_start','eprof_end','eprof_dump');

use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor);


=head2 fetch_all_by_Slice

  Arg [1]    : Bio::EnsEMBL::Slice
  Arg [2]    : (optional) boolean $is_lite
               Flag indicating if 'light weight' variations should be obtained
  Example    : @list = @{$glovar_adaptor->fetch_all_by_Slice($slice)};
  Description: Retrieves a list of STSs on a slice in slice coordinates 
  Returntype : Listref of Bio::EnsEMBL::DnaDnaAlignFeature objects
  Exceptions : none
  Caller     : Bio::EnsEMBL::Slice::get_all_ExternalFeatures

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

  Arg [1]    : Bio::EnsEMBL::Slice
  Arg [2]    : (optional) boolean $is_lite
               Flag indicating if 'light weight' variations should be obtained
  Example    : @list = @{$glovar_adaptor->fetch_Light_STS_by_chr_start_end($slice)};
  Description: Retrieves a list of STSs on a slice in slice coordinates.
               Returns lightweight objects for drawing purposes.
  Returntype : Listref of Bio::EnsEMBL::DnaDnaAlignFeature objects
  Exceptions : none
  Caller     : $self->fetch_all_by_Slice

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
    ## 2. all code here assumes that ssm.contig_orientation is always 1
    ##    and ms.is_revcomp is always 0

    my $q = qq(
        SELECT 
                ss.id_sts,
                ms.start_coordinate + ssm.start_coordinate - 1
                                                    as start_coord,
                ms.end_coordinate + ssm.start_coordinate - 1
                                                    as end_coord,
                ss.sts_name                         as sts_name,
                length(ss.sense_oligoprimer) as sen_len,
                length(ss.antisense_oligoprimer) as anti_len,
                ss.pass_status                      as pass_status,
                -1 * (ms.is_revcomp * 2 - 1)        as ori,
                ssm.contig_orientation              as contig_ori,
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
        warn("ERROR: SQL failed in " . (caller(0))[3] . "\n$@");
        return([]);
    }

    my @features = ();
    my %passmap = ( 1 => 'pass', 2 => 'fail' );
    while (my $row = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$row};
        #next if $row->{'PRIVATE'};
        
        ## NT_contigs should always be on forward strand
        warn "Contig is in reverse orientation. THIS IS BAD!"
            if ($row->{'CONTIG_ORI'} == -1);
        ## STSs should always be on forward strand
        warn "STS is in reverse orientation. THIS IS BAD!"
            if ($row->{'ORI'} == -1);
        
        my $pass = $passmap{$row->{'PASS_STATUS'}} || "unknown";
        my $sen_start = $row->{'START_COORD'};
        my $sen_end = $row->{'START_COORD'} + $row->{'SEN_LEN'};
        my $anti_start = $row->{'END_COORD'};
        my $anti_end = $row->{'END_COORD'} - $row->{'ANTI_LEN'};
        push @features, Bio::EnsEMBL::DnaDnaAlignFeature->new_fast({
                '_analysis'      =>  'glovar_sts',
                '_gsf_start'    =>    $sen_start - $slice_start + 1,
                '_gsf_end'      =>    $sen_end - $slice_start + 1,
                '_gsf_strand'    =>  1,
                '_seqname'       =>  $slice->name,
                '_hstart'        =>  1,
                '_hend'          =>  $row->{'SEN_LEN'},
                '_hstrand'       =>  1,
                '_hseqname'      =>  $row->{'STS_NAME'},
                '_gsf_seq'       =>  $slice,
                '_cigar_string'  =>  $row->{'SEN_LEN'}."M",
                '_id'            =>  $row->{'ID_STS'},
                '_database_id'   =>  $row->{'ID_STS'},
                '_pass'          =>  $pass,
        });
        push @features, Bio::EnsEMBL::DnaDnaAlignFeature->new_fast({
                '_analysis'      =>  'glovar_sts',
                '_gsf_start'    =>    $anti_start - $slice_start + 1,
                '_gsf_end'      =>    $anti_end - $slice_start + 1,
                '_gsf_strand'    =>  1,
                '_seqname'       =>  $slice->name,
                '_hstart'        =>  1,
                '_hend'          =>  $row->{'ANTI_LEN'},
                '_hstrand'       =>  1,
                '_hseqname'      =>  $row->{'STS_NAME'},
                '_gsf_seq'       =>  $slice,
                '_cigar_string'  =>  $row->{'ANTI_LEN'}."M",
                '_id'            =>  $row->{'ID_STS'},
                '_database_id'   =>  $row->{'ID_STS'},
                '_pass'          =>  $pass,
        });
    }
    
    &eprof_end('glovar_sts1');
    
    return(\@features);
}                                       

=head2 fetch_STS_by_chr_start_end

  Arg [1]    : Bio::EnsEMBL::Slice
  Example    : @list = @{$glovar_adaptor->fetch_STS_by_chr_start_end($slice)};
  Description: Retrieves a list of STSs on a slice in slice coordinates 
  Returntype : Listref of Bio::EnsEMBL::DnaDnaAlignFeature objects
  Exceptions : none
  Caller     : $self->fetch_all_by_Slice

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
  Returntype : Listref of Bio::EnsEMBL::DnaDnaAlignFeature objects
  Exceptions : none
  Caller     : $self

=cut

sub fetch_STS_by_id  {
    my ($self, $id) = @_;
    my @vars = ();
    
    ## to be inplemented ...

    return \@vars;
}


=head2 track_name

  Arg[1]      : none
  Example     : my $track_name = $sts_adaptor->track_name;
  Description : returns the track name
  Return type : String - track name
  Exceptions  : none
  Caller      : Bio::EnsEMBL::Slice,
                Bio::EnsEMBL::ExternalData::ExternalFeatureAdaptor

=cut

sub track_name {
    my ($self) = @_;    
    return("GlovarSTS");
}

1;

