=head1 NAME

Bio::EnsEMBL::ExternalData::Glovar::GlovarSNPAdaptor -
Object adaptor for Glovar SNPs

=head1 SYNOPSIS

$glodb = Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor->new(
                                         -user   => 'ensro',
                                         -pass   => 'secret',
                                         -dbname => 'snp',
                                         -host   => 'go_host',
                                         -driver => 'Oracle'
);
my $glovar_adaptor = $glodb->get_GlovarSNPAdaptor;
$listref  = $glovar_adaptor->fetch_all_by_Slice($slice);

=head1 DESCRIPTION

This module is an entry point into a glovar database. It allows you to retrieve
SNPs from Glovar.

=head1 AUTHOR

Tony Cox <avc@sanger.ac.uk>
Patrick Meidl <pm2@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::ExternalData::Glovar::GlovarSNPAdaptor;

use strict;

use Bio::EnsEMBL::SNP;
use Bio::Annotation::DBLink;
use Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor);

=head2 fetch_all_by_Slice

  Arg [1]    : Bio::EnsEMBL::Slice $slice
  Arg [2]    : (optional) boolean $is_lite
               Flag indicating if 'light weight' variations should be obtained
  Example    : @list = @{$glovar_adaptor->fetch_all_by_Slice($slice)};
  Description: Retrieves a list of variations on a slice in slice coordinates 
  Returntype : Listref of Bio::EnsEMBL::SNP objects
  Exceptions : none
  Caller     : Bio::EnsEMBL::Slice::get_all_ExternalFeatures

=cut

sub XX_fetch_all_by_Slice {
  my ($self, $slice, $is_light) = @_;

  unless($slice->assembly_name() && $slice->assembly_version()){
      warn("Cannot determine assembly name and version from Slice in GlovarAdaptor!\n");
      return([]);
  }

  return $self->fetch_SNP_by_chr_start_end($slice);
}

=head2 fetch_SNP_by_chr_start_end

  Arg [1]    : Bio::EnsEMBL::Slice
  Example    : @list = @{$glovar_adaptor->fetch_SNP_by_chr_start_end($slice)};
  Description: Retrieves a list of SNPs on a slice in slice coordinates.
  Returntype : Listref of Bio::EnsEMBL::SNP objects
  Exceptions : none
  Caller     : $self->fetch_all_by_Slice

=cut

sub fetch_SNP_by_chr_start_end  {
    my ($self, $slice) = @_; 
    my $slice_chr    = $slice->chr_name();
    my $slice_start  = $slice->chr_start();
    my $slice_end    = $slice->chr_end();
    my $slice_strand = $slice->strand();
    my $ass_name     = $slice->assembly_name();
    my $ass_version  = $slice->assembly_version();

    &eprof_start('glovar_snp');

    my $q = qq(
        SELECT
                ss.ID_SNP                       as INTERNAL_ID,
                ss.DEFAULT_NAME                 as ID_DEFAULT,
                mapped_snp.POSITION + seq_seq_map.START_COORDINATE - 1
                                                as CHR_START,
                mapped_snp.END_POSITION + seq_seq_map.START_COORDINATE - 1
                                                as CHR_END,
                seq_seq_map.CONTIG_ORIENTATION  as CHR_STRAND,
                scd.DESCRIPTION                 as VALIDATED,
                ss.ALLELES                      as ALLELES,
                svd.DESCRIPTION                 as SNPCLASS,
                seq_seq_map.CONTIG_ORIENTATION  as CONTIG_ORI,
                ss.IS_PRIVATE                   as PRIVATE
        FROM    chrom_seq,
                database_dict,
                seq_seq_map,
                mapped_snp,
                snp,
                snpvartypedict svd,
                snp_confirmation_dict scd,
                snp_summary ss
        WHERE   chrom_seq.DATABASE_SEQNAME= '$slice_chr'
        AND     database_dict.DATABASE_NAME = '$ass_name'
        AND     database_dict.DATABASE_VERSION = '$ass_version'
        AND     database_dict.ID_DICT = chrom_seq.DATABASE_SOURCE
        AND     chrom_seq.ID_CHROMSEQ = seq_seq_map.ID_CHROMSEQ
        AND     seq_seq_map.SUB_SEQUENCE = mapped_snp.ID_SEQUENCE
        AND     mapped_snp.ID_SNP = ss.ID_SNP
        AND     ss.ID_SNP = snp.ID_SNP
        AND     snp.VAR_TYPE = svd.ID_DICT
        AND     ss.CONFIRMATION_STATUS = scd.ID_DICT
        AND     mapped_snp.POSITION
        BETWEEN
                ($slice_start - seq_seq_map.START_COORDINATE - 99)
                AND 
                ($slice_end - seq_seq_map.START_COORDINATE + 1)
        ORDER BY
                CHR_START

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

    my @snps = ();
    while (my $row = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$row};
        #next if $row->{'PRIVATE'};

        ## NT_contigs should always be on forward strand
        warn "Contig is in reverse orientation. THIS IS BAD!"
            if ($row->{'CONTIG_ORI'} == -1);
        
        $row->{'CHR_END'} ||= $row->{'CHR_START'};
        my $snp = Bio::EnsEMBL::SNP->new_fast(
            {
                '_snpid'        =>    $row->{'ID_DEFAULT'},
                'dbID'          =>    $row->{'INTERNAL_ID'},
                '_gsf_start'    =>    $row->{'CHR_START'} - $slice_start + 1,
                '_gsf_end'      =>    $row->{'CHR_END'} - $slice_start + 1,
                '_snp_strand'   =>    $row->{'CHR_STRAND'},
                '_validated'    =>    $row->{'VALIDATED'},
                '_raw_status'   =>    $row->{'VALIDATED'},
                '_ambiguity_code' =>  $self->_ambiguity_code($row->{'ALLELES'}),
                'alleles'       =>    $row->{'ALLELES'},
                '_snpclass'     =>    $row->{'SNPCLASS'},
                '_source'       =>    'Glovar',
                '_source_tag'   =>    'glovar',
                '_consequence'  =>    $row->{'CONSEQUENCE'},
                '_type'         =>    $row->{'POS_TYPE'},
            });

        ## DBLinks and consequences
        $self->_get_DBLinks($snp, $row->{'INTERNAL_ID'});
        $self->_get_consequences($snp, $row->{'INTERNAL_ID'}, $self->consequences_exp);
        
        push (@snps, $snp); 
    }

    &eprof_end('glovar_snp');
    
    return(\@snps);
}                                       

=head2 fetch_all_by_clone_accession

  Arg[1]      : clone internal ID
  Arg[2]      : clone embl accession
  Arg[3]      : clone start coordinate
  Arg[4]      : clone end coordinate
  Example    : @list = @{$glovar_adaptor->fetch_all_by_clone_accession('AL100005', 'AL100005', 1, 10000)};
  Description: Retrieves a list of SNPs on a clone in clone coordinates.
  Returntype : Listref of Bio::EnsEMBL::SNP objects
  Exceptions : none
  Caller     : $self->fetch_all_by_Clone

=cut

sub fetch_all_by_clone_accession {
    my ($self, $internal_id, $embl_acc, $cl_start, $cl_end) = @_;

    &eprof_start('clone_sql');

    my $dnadb;
    eval { $dnadb = $self->ensembl_db; };
    if ($@) {
        warn "ERROR: No dnadb attached to Glovar: $@";
        return;
    }
    
    ## get info on clone
    my $q1 = qq(
        SELECT
                csm.id_sequence,
                csm.start_coordinate,
                csm.end_coordinate,
                csm.contig_orientation
        FROM    clone_seq cs,
                clone_seq_map csm
        WHERE   cs.database_seqname = '$embl_acc'
        AND     cs.id_cloneseq = csm.id_cloneseq
    );
    my $sth;
    eval {
        $sth = $self->prepare($q1);
        $sth->execute();
    }; 
    if ($@){
        warn("ERROR: SQL failed in " . (caller(0))[3] . "\n$@");
        return([]);
    }
    my ($id_seq, $clone_start, $clone_end, $clone_strand) = $sth->fetchrow_array();

    ## now get the SNPs on this clone
    # get only features in the desired region of the clone
    my ($q_start, $q_end);
    if ($clone_strand == 1) {
        $q_start = $clone_start + $cl_start - 1;
        $q_end = $clone_start + $cl_end + 1;
    } else{
        $q_start = $clone_end - $cl_end - 1;
        $q_end = $clone_end - $cl_start + 1;
    }
    #warn join("|", $clone_start, $clone_end, $cl_start, $cl_end, $q_start, $q_end, "\n");
    my $q2 = qq(
        SELECT
                distinct(sgc.id_snp)    as id_snp,
                ss.id_snp               as internal_id,
                ss.default_name         as id_default,
                ms.position             as snp_start,
                ms.end_position         as snp_end,
                ms.is_revcomp           as snp_strand,
                scd.description         as validated,
                ss.alleles              as alleles,
                svd.description         as snpclass,
                ss.is_private           as private,
                ptd.description         as pos_type,
                sgc_dict.description    as consequence
        FROM    
                mapped_snp ms,
                snp,
                snpvartypedict svd,
                snp_confirmation_dict scd,
                snp_summary ss
        LEFT JOIN
                snp_gene_consequence sgc on sgc.id_snp = ss.id_snp
        LEFT JOIN
                coding_sequence cs on sgc.id_codingseq = cs.id_codingseq
                AND cs.design_entry = ?
        LEFT JOIN
                position_type_dict ptd on sgc.position_description = ptd.id_dict
        LEFT JOIN
                sgc_dict on sgc.consequence = sgc_dict.id_dict
        WHERE   ms.id_sequence = ?
        AND     ms.id_snp = ss.id_snp
        AND     ss.id_snp = snp.id_snp
        AND     snp.var_type = svd.id_dict
        AND     ss.confirmation_status = scd.id_dict
        AND     ms.position BETWEEN $q_start AND $q_end
    );

    eval {
        $sth = $self->prepare($q2);
        $sth->execute($self->consequence_exp, $id_seq);
    }; 
    if ($@){
        warn("ERROR: SQL failed in " . (caller(0))[3] . "\n$@");
        return([]);
    }

    my @snps = ();
    while (my $row = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$row};
        warn "WARNING: private data!" if $row->{'PRIVATE'};

        ## filter SNPs without strand (this is gruft in mapped_snp)
        next unless $row->{'SNP_STRAND'};

        ## calculate coords depending on clone orientation
        my ($start, $end);
        $row->{'SNP_END'} ||= $row->{'SNP_START'};
        if ($clone_strand == 1) {
            $start = $row->{'SNP_START'} - $clone_start + 1;
            $end = $row->{'SNP_END'} - $clone_start + 1;
        } else {
            $start = $clone_end -$row->{'SNP_START'} + 1;
            $end = $clone_end - $row->{'SNP_END'} + 1;
        }
        
        my $snp = Bio::EnsEMBL::SNP->new_fast(
            {
                '_snpid'        =>    $row->{'ID_DEFAULT'},
                'dbID'          =>    $row->{'INTERNAL_ID'},
                '_gsf_start'    =>    $start,
                '_gsf_end'      =>    $end,
                '_snp_strand'   =>    $row->{'SNP_STRAND'},
                '_validated'    =>    $row->{'VALIDATED'},
                '_raw_status'   =>    $row->{'VALIDATED'},
                '_ambiguity_code' =>  $self->_ambiguity_code($row->{'ALLELES'}),
                'alleles'       =>    $row->{'ALLELES'},
                '_snpclass'     =>    $row->{'SNPCLASS'},
                '_source'       =>    'Glovar',
                '_source_tag'   =>    'glovar',
                '_consequence'  =>    $row->{'CONSEQUENCE'},
                '_type'         =>    $self->_map_position_type($row->{'POS_TYPE'}),
            });

        ## DBLinks and consequences
        $self->_get_DBLinks($snp, $row->{'INTERNAL_ID'});
        
        push (@snps, $snp); 
    }

    &eprof_end('clone_sql');
    #&eprof_dump(\*STDERR);
    
    return \@snps;
}                                       

=head2 fetch_SNP_by_id

  Arg[1]      : String - Variation ID
  Example     : my $variation = $glovar_adaptor->fetch_SNP_by_id($id);
  Description : retrieve variations from Glovar by ID
  Return type : Listref of Bio::EnsEMBL::SNP objects.
  Exceptions  : none
  Caller      : $self

=cut

sub fetch_SNP_by_id  {
    my ($self, $id) = @_;
    
    &eprof_start('fetch_snp_by_id');
    
    my $dnadb;
    eval { $dnadb = $self->ensembl_db; };
    if ($@) {
        warn "ERROR: No dnadb attached to Glovar: $@";
        return;
    }
    
    my $q1 = qq(
        SELECT
                distinct(sgc.id_snp)        as id_snp,
                ss.id_snp                   as internal_id,
                ss.default_name             as id_default,
                ms.position                 as snp_start,
                ms.end_position             as snp_end,
                ms.is_revcomp               as snp_strand,
                scd.description             as validated,
                ss.alleles                  as alleles,
                svd.description             as snpclass,
                sseq.database_seqnname      as seqname,
                sseq.database_seqversion    as seqversion,
                sseq.chromosome             as chr_name,
                ss.is_private               as private,
                sseq.id_sequence            as nt_id,
                ptd.description             as pos_type,
                sgc_dict.description        as consequence
        FROM    
                snp_sequence sseq,
                mapped_snp ms,
                snp,
                snpvartypedict svd,
                snp_confirmation_dict scd,
                snp_summary ss
        LEFT JOIN
                snp_gene_consequence sgc on sgc.id_snp = ss.id_snp
        LEFT JOIN
                coding_sequence cs on sgc.id_codingseq = cs.id_codingseq
                AND cs.design_entry = ?
        LEFT JOIN
                position_type_dict ptd on sgc.position_description = ptd.id_dict
        LEFT JOIN
                sgc_dict on sgc.consequence = sgc_dict.id_dict
        WHERE   ss.default_name = ?
        AND     sseq.id_sequence = ms.id_sequence
        AND     ms.id_snp = ss.id_snp
        AND     ss.id_snp = snp.id_snp
        AND     snp.var_type = svd.id_dict
        AND     ss.confirmation_status = scd.id_dict
    );

    my @snps = ();
    my $sth1;

    eval {
        $sth1 = $self->prepare($q1);
        $sth1->execute($self->consequence_exp, $id);
    }; 
    if ($@){
        warn("ERROR: SQL failed in " . (caller(0))[3] . "\n$@");
        return([]);
    }

    while (my $row = $sth1->fetchrow_hashref()) {
        return([]) unless keys %{$row};

        $row->{'SNP_END'} ||= $row->{'SNP_START'};
        my $snp_start = $row->{'SNP_START'};
        my $id_seq = $row->{'NT_ID'};
        my $q2 = qq(
            SELECT
                    cs.database_seqname     as embl_acc,
                    csm.start_coordinate    as clone_start,
                    csm.end_coordinate      as clone_end,
                    csm.contig_orientation  as clone_strand
            FROM    clone_seq cs,
                    clone_seq_map csm
            WHERE   csm.id_sequence = '$id_seq'
            AND     cs.id_cloneseq = csm.id_cloneseq
            AND     (csm.start_coordinate < $snp_start)
            AND     (csm.end_coordinate > $snp_start)
        );
        my $sth2;
        eval {
            $sth2 = $self->prepare($q2);
            $sth2->execute();
        }; 
        if ($@){
            warn("ERROR: SQL failed in " . (caller(0))[3] . "\n$@");
            return([]);
        }
        my @mapped;
        while (my ($embl_acc, $clone_start, $clone_end, $clone_strand) = $sth2->fetchrow_array()) {
            #warn join("|", $embl_acc, $clone_start, $clone_end, $clone_strand);
            
            ## calculate clone coordinates for SNP
            my ($start, $end);
            if ($clone_strand == 1) {
                $start = $row->{'SNP_START'} - $clone_start + 1;
                $end = $row->{'SNP_END'} - $clone_start + 1;
            } else {
                $start = $clone_end - $row->{'SNP_START'} + 1;
                $end = $clone_end - $row->{'SNP_END'} + 1;
            }
            next if ($start < 0);

            ## map to chromosomal coordinates
            my $mapper = $dnadb->get_AssemblyMapperAdaptor->fetch_by_type(
                                $dnadb->assembly_type);
            my $clone;
            eval { 
                $clone = $dnadb->get_CloneAdaptor->fetch_by_accession($embl_acc);
            };
            if ($@) {
                warn $@;
                next;
            }
            my $contig = $clone->get_RawContig_by_position($start);
            my $offset = $contig->embl_offset;
            @mapped = $mapper->map_coordinates_to_assembly($contig->dbID,
                                $start - $offset + 1,
                                $end - $offset + 1,
                                $clone_strand);

            #if maps to multiple locations in assembly, skip feature
            next if(@mapped > 1);

            #warn join ("|", $clone_strand, $row->{'SNP_STRAND'});

            #try next clone if mapped to gap
            #warn $mapped[0]->start;
            last unless($mapped[0]->isa('Bio::EnsEMBL::Mapper::Gap'));
        }
        ## hack: skip if we don't get clones from NT_contig
        next unless @mapped;

        my $snp = Bio::EnsEMBL::SNP->new;
        $snp->start($mapped[0]->start);
        $snp->end($mapped[0]->end);
        $snp->strand($row->{'SNP_STRAND'});
        $snp->original_strand($row->{'SNP_STRAND'});
        
        $snp->dbID($row->{'INTERNAL_ID'});
        $snp->chr_name($row->{'CHR_NAME'});
        
        my $acc_version = '';
        $acc_version = $row->{'SEQNAME'} if $row->{'SEQNAME'};
        $acc_version .= "." . $row->{'SEQVERSION'} if $row->{'SEQVERSION'};
        $snp->seqname($acc_version);
        
        $snp->source_tag('Glovar');
        $snp->snpclass($row->{'SNPCLASS'});
        $snp->raw_status($row->{'VALIDATED'});
        $snp->alleles($row->{'ALLELES'});
        $snp->type($self->_map_position_type($row->{'POS_TYPE'}));
        $snp->consequence($row->{'CONSEQUENCE'});

        ## get flanking sequence from core
        my $slice = $dnadb->get_SliceAdaptor->fetch_by_chr_start_end(
           $row->{'CHR_NAME'},
           $mapped[0]->start - 25,
           $mapped[0]->end + 25,
        );
        $slice = $slice->invert if ($row->{'SNP_STRAND'} == -1);
        my $seq = $slice->seq;

        ## determine end of upstream sequence depending on range type (in-dels
        ## of type "between", i.e. start !== end, are actually inserts)
        my $up_end = 25;
        $up_end++ if (($row->{'SNPCLASS'} eq "SNP - indel") && ($mapped[0]->start ne $mapped[0]->end));
        $snp->upStreamSeq(substr($seq, 0, $up_end));
        $snp->dnStreamSeq(substr($seq, 26));
        
        ## these attributes are on ensembl SNPs, but are not available in Glovar
        #$snp->score($mapweight);
        #$snp->het($het);
        #$snp->hetse($hetse);
        
        ## DBLinks
        $self->_get_DBLinks($snp, $row->{'INTERNAL_ID'});
        
        push @snps, $snp;
    }

    &eprof_end('fetch_snp_by_id');
    #&eprof_dump(\*STDERR);

    return \@snps;
}

=head2 _ambiguity_code

  Arg[1]      : String - alleles
  Example     : my $ambig = $self->_ambituity_code('A|T');
  Description : returns the ambiguity code for a variation
  Return type : String - ambiguity code
  Exceptions  : none
  Caller      : $self

=cut

sub _ambiguity_code {
    my ($self, $alleles) = @_;
    my %ambig = qw(AC M ACG V ACGT N ACT H AG R AGT D AT W CG S CGT B CT Y GT K);
    return $ambig{ join '', sort split /\|/, $alleles };

}

=head2 _get_DBLinks

  Arg[1]      : Bio::EnsEMBL::SNP object
  Arg[2]      : glovar SNP ID (ID_SNP)
  Example     : $glovar_adaptor->_get_DBLinks($snp, '104567');
  Description : adds external database links to snp object; links are added
                as Bio::Annotation::DBLink objects
  Return type : none
  Exceptions  : none
  Caller      : $self

=cut

sub _get_DBLinks {
    my ($self, $snp, $id) = @_;
    my $q = qq(
        SELECT
                snp_name.SNP_NAME               as NAME,
                snpnametypedict.DESCRIPTION     as TYPE
        FROM    
                snp_name,
                snpnametypedict
        WHERE   snp_name.ID_SNP = ?
        AND     snp_name.SNP_NAME_TYPE = snpnametypedict.ID_DICT
    );
    my $sth;
    eval {
        $sth = $self->prepare($q);
        $sth->execute($id);
    }; 
    if ($@){
        warn("ERROR: SQL failed in " . (caller(0))[3] . "\n$@");
        return;
    }

    while (my $xref = $sth->fetchrow_hashref()) {
        my $link = new Bio::Annotation::DBLink;
        $link->database($xref->{'TYPE'});
        $link->primary_id($xref->{'NAME'});
        $snp->add_DBLink($link);
    }
}

=head2 _get_consequences

  Arg[1]      : Bio::EnsEMBL::SNP object
  Arg[2]      : glovar SNP ID (ID_SNP)
  Arg[3]      : ID of the consequence experiment
  Example     : $glovar_adaptor->_get_consequences($snp, '104567', 0246);
  Description : adds consequences (position type, consequence) to snp object
  Return type : none
  Exceptions  : none
  Caller      : $self

=cut

sub _get_consequences {
    my ($self, $snp, $id, $exp) = @_;
    my $q = qq(
        SELECT
                distinct(sgc.id_snp)    as id_snp,
                ptd.description         as pos_type,
                sgc_dict.description    as consequence
        FROM    
                coding_sequence cs,
                snp_gene_consequence sgc
        LEFT JOIN
                position_type_dict ptd on sgc.position_description = ptd.id_dict
        LEFT JOIN
                sgc_dict on sgc.consequence = sgc_dict.id_dict
        WHERE   sgc.id_snp = ?
        AND     sgc.id_codingseq = cs.id_codingseq
        AND     cs.design_entry = ?
    );
    my $sth;
    eval {
        $sth = $self->prepare($q);
        $sth->execute($id, $exp);
    }; 
    if ($@){
        warn("ERROR: SQL failed in " . (caller(0))[3] . "\n$@");
        return;
    }

    my (undef, $pos_type, $cons) = $sth->fetchrow_array;
    $snp->type($self->_map_position_type($pos_type));
    $snp->consequence($cons);
}

=head2 _map_position_type

  Arg[1]      : String - position type
  Example     : my $type = $glovar_adaptor->_map_position_type($glovar_type);
  Description : maps glovar position types to ensembl naming convention
  Return type : String - position type
  Exceptions  : none
  Caller      : $self

=cut

sub _map_position_type {
    my ($self, $type) = @_;
    my %mapping = (
        'Coding' => 'coding',
        'Non-coding exonic' => 'utr',
        'Intronic' => 'intron',
        'Upstream' => 'local',
    );
    return $mapping{$type} || $type;
}

=head2 consequence_exp

  Arg[1]      : (optional) consequence experiment id
  Example     : $glovar_adaptor->consequence_ext(2046);
  Description : getter/setter for the consequence experiment
                (coding_sequence.design_entry in the glovar db)
  Return type : String - consequence experiment id
  Exceptions  : none
  Caller      : general

=cut

sub consequence_exp {
    my ($self, $exp) = @_;
    if ($exp) {
        $self->{'consequence_exp'} = $exp;
    }
    return $self->{'consequence_exp'};
}

=head2 coordinate_systems

  Arg[1]      : none
  Example     : my @coord_systems = $glovar_adaptor->coordinate_systems;
  Description : This method returns a list of coordinate systems which are
                implemented by this class. A minimum of one valid coordinate
                system must be implemented. Valid coordinate systems are:
                'SLICE', 'ASSEMBLY', 'CONTIG', and 'CLONE'.
  Return type : list of strings
  Exceptions  : none
  Caller      : internal

=cut

sub coordinate_systems {
    return ('CLONE');
}

=head2 track_name

  Arg[1]      : none
  Example     : my $track_name = $snp_adaptor->track_name;
  Description : returns the track name
  Return type : String - track name
  Exceptions  : none
  Caller      : Bio::EnsEMBL::Slice,
                Bio::EnsEMBL::ExternalData::ExternalFeatureAdaptor

=cut

sub track_name {
    return("GlovarSNP");
}

1;

