=head1 NAME

GlovarHaplotypeAdaptor -
Database adaptor for Glovar haplotypes

=head1 SYNOPSIS

$glodb = Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor->new(
                                         -user   => 'ensro',
                                         -pass   => 'secret',
                                         -dbname => 'snp',
                                         -host   => 'go_host',
                                         -driver => 'Oracle');
my $glovar_adaptor = $glodb->get_GlovarHaplotypeAdaptor;
$var_listref  = $glovar_adaptor->fetch_all_by_Slice($slice);

=head1 DESCRIPTION

This module is an entry point into a Glovar database. It allows you to retrieve
haplotype data from the database.

=head1 AUTHOR

Patrick Meidl <pm2@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::ExternalData::Glovar::GlovarHaplotypeAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor;
use Bio::EnsEMBL::Utils::Eprof('eprof_start','eprof_end','eprof_dump');

@ISA = qw(Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor);


=head2 fetch_all_by_Slice

  Arg [1]    : Bio::EnsEMBL::Slice
  Arg [2]    : (optional) boolean $is_lite
               Flag indicating if 'light weight' objects should be obtained
  Example    : @list = @{$glovar_adaptor->fetch_all_by_Slice($slice)};
  Description: Retrieves a list of haplotypes on a slice in slice coordinates 
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
    push @f, @{$self->fetch_Light_Haplotype_by_chr_start_end($slice)};
  } else {
    push @f, @{$self->fetch_Haplotype_by_chr_start_end($slice)};
  } 
  return(\@f); 
}


=head2 fetch_Light_Haplotype_by_chr_start_end

  Arg [1]    : Bio::EnsEMBL::Slice
  Example    : @list = @{$glovar_adaptor->fetch_Light_Haplotype_by_chr_start_end($slice)};
  Description: Retrieves a list of haplotypes on a slice in slice coordinates.
               Returns lightweight objects for drawing purposes.
  Returntype : Listref of Bio::EnsEMBL::DnaDnaAlignFeature objects
  Exceptions : none
  Caller     : $self->fetch_all_by_Slice

=cut

sub fetch_Light_Haplotype_by_chr_start_end  {
    my ($self,$slice) = @_; 

    my $slice_chr    = $slice->chr_name();
    my $slice_start  = $slice->chr_start();
    my $slice_end    = $slice->chr_end();
    my $slice_strand = $slice->strand();
    my $ass_name     = $slice->assembly_name();
    my $ass_version  = $slice->assembly_version();

    ## return traces from cache if available
    my $key = join(":", $slice_chr, $slice_start, $slice_end);
    if ($self->{'_cache'}->{$key}) {
        return $self->{'_cache'}->{$key};
    }

    &eprof_start('glovar_haplotype');

    ## NOTE:
    ## all code here assumes that ssm.contig_orientation is always 1!

    my $q = qq(
        SELECT
                ms.position + ssm.start_coordinate - 1
                                    as start_coord,
                ms.end_position + ssm.start_coordinate - 1
                                    as end_coord,
                ms.id_snp           as id_snp,
                sb.id_block         as block,
                b.length            as block_length,
                b.num_snps          as num_snps,
                p.description       as population,
                p.id_pop            as id_pop,
                ssum.is_private     as private_snp,
                bs.is_private       as private_block
        FROM    chrom_seq cs,
                database_dict dd,
                seq_seq_map ssm,
                mapped_snp ms,
                snp_summary ssum,
                snp_block sb,
                block b,
                block_set bs,
                population p
        WHERE   cs.database_seqname = '$slice_chr'
        AND     dd.database_name = '$ass_name'
        AND     dd.database_version = '$ass_version'
        AND     dd.id_dict = cs.database_source
        AND     ssm.id_chromseq = cs.id_chromseq
        AND     ms.id_sequence = ssm.sub_sequence
        AND     ssum.id_snp = ms.id_snp
        AND     ssum.id_snp = sb.id_snp
        AND     sb.id_block = b.id_block
        AND     b.id_block_set = bs.id_block_set
        AND     bs.id_pop = p.id_pop
        AND     ms.position
                BETWEEN
                ($slice_start - ssm.start_coordinate - 99)
                AND 
                ($slice_end - ssm.start_coordinate + 1)
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

    my @haplotypes = ();
    while (my $row = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$row};
        #next if ($row->{'PRIVATE_SNP'} || $row->{'PRIVATE_BLOCK'});
        my $length = $row->{'END_COORD'} - $row->{'START_COORD'};
        push @haplotypes, Bio::EnsEMBL::DnaDnaAlignFeature->new_fast({
                '_analysis'     => 'glovar_haplotype',
                '_gsf_start'    => $row->{'START_COORD'} - $slice_start + 1,
                '_gsf_end'      => $row->{'END_COORD'} - $slice_start + 1,
                '_gsf_strand'   => $row->{'CHR_STRAND'},
                '_seqname'      => $slice->name,
                '_hstart'       => 1,
                '_hend'         => $length,
                '_hstrand'      => 1,
                '_hseqname'     => $row->{'BLOCK'},
                '_gsf_seq'      => $slice,
                '_cigar_string' => $length."M",
                '_id'           => $row->{'BLOCK'},
                '_database_id'  => $row->{'ID_SNP'},
                '_population'   => $row->{'POPULATION'},
                '_pop_id'       => $row->{'ID_POP'},
                '_block_length' => $row->{'BLOCK_LENGTH'},
                '_num_snps'     => $row->{'NUM_SNPS'},
        });
    }
    
    &eprof_end('glovar_haplotype');
    
    return $self->{'_cache'}->{$key} = \@haplotypes;
}                                       

=head2 fetch_Haplotype_by_chr_start_end
  
  Arg [1]    : Bio::EnsEMBL::Slice
  Example    : @list = @{$glovar_adaptor->fetch_Haplotype_by_chr_start_end($slice)};
  Description: Retrieves a list of haplotypes on a slice in slice coordinates 
  Returntype : Listref of Bio::EnsEMBL::DnaDnaAlignFeature objects
  Exceptions : none
  Caller     : $self->fetch_all_by_Slice

=cut

sub fetch_Haplotype_by_chr_start_end  {
    my ($self, $slice) = @_;
    
    ## to be implemented
    
    return(1);
}

=head2 track_name

  Arg[1]      : none
  Example     : my $track_name = $haplotype_adaptor->track_name;
  Description : returns the track name
  Return type : String - track name
  Exceptions  : none
  Caller      : Bio::EnsEMBL::Slice,
                Bio::EnsEMBL::ExternalData::ExternalFeatureAdaptor

=cut

sub track_name {
    my ($self) = @_;    
    return("GlovarHaplotype");
}

1;
