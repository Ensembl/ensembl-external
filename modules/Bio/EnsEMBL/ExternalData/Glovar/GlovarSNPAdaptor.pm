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

use Bio::EnsEMBL::ExternalData::Glovar::SNP;
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
        $self->_get_DBLinks($snp);
        $self->_get_consequences($snp);
        
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
    my ($self, $embl_acc, $embl_version, $cl_start, $cl_end) = @_;

    #&eprof_start('clone_sql');

    my $dnadb;
    eval { $dnadb = $self->ensembl_db; };
    if ($@) {
        warn "ERROR: No dnadb attached to Glovar: $@";
        return;
    }
    
    ## get info on clone
    my $q1 = qq(
        SELECT
                ss.database_seqnname,
                csm.id_sequence,
                csm.start_coordinate,
                csm.end_coordinate,
                csm.contig_orientation
        FROM    clone_seq cs,
                clone_seq_map csm,
                snp_sequence ss
        WHERE   cs.database_seqname = '$embl_acc'
        AND     cs.id_cloneseq = csm.id_cloneseq
        AND     csm.id_sequence = ss.id_sequence
        AND     ss.is_current = 1
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
    my ($nt_name, $id_seq, $clone_start, $clone_end, $clone_strand);
    my $i;
    while (my @res = $sth->fetchrow_array) {
        ($nt_name, $id_seq, $clone_start, $clone_end, $clone_strand) = @res;
        $i++;
    }
    if ($i > 1) {
        $self->warn("Clone ($embl_acc) maps to more than one ($i) NTs and/or clones.");
    }

    ## temporary hack for SNP density script: skip vega-specific clones
    #unless ($nt_name =~ /^NT/) {
    #    warn "WARNING: Skipping vega-specific clone ($embl_acc).\n";
    #    return ([]);
    #}

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
    #warn join("|", $clone_start, $clone_end, $cl_start, $cl_end, $q_start, $q_end, $clone_strand, "\n");
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

    my (%snps, %cons);
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
            $start = $clone_end - $row->{'SNP_END'} + 1;
            $end = $clone_end -$row->{'SNP_START'} + 1;
        }

        ## if SNP has multiple consequences, use the most important one
        my %mapping = (
            'Coding' => '01:coding',
            'Non-coding exonic' => '02:utr',
            'Intronic' => '03:intron',
            'Upstream' => '04:local',
        );
        my $strand = $row->{'SNP_STRAND'}*$clone_strand;
        my $key = join(":", $row->{'ID_DEFAULT'}, $start, $end, $strand);
        my $pos_type = $self->_map_position_type($row->{'POS_TYPE'});
        if (! $cons{$key} or $pos_type le $cons{$key}) {
            $cons{$key} = $pos_type;
            my $snp = Bio::EnsEMBL::ExternalData::Glovar::SNP->new_fast(
                {
                    'dbID'          =>  $row->{'INTERNAL_ID'},
                    'display_id'    =>  $row->{'ID_DEFAULT'},
                    'start'         =>  $start,
                    'end'           =>  $end,
                    'strand'        =>  $row->{'SNP_STRAND'}*$clone_strand,
                    'raw_status'    =>  $row->{'VALIDATED'},
                    'ambiguity_code'=>  $self->_ambiguity_code($row->{'ALLELES'}),
                    'alleles'       =>  $row->{'ALLELES'},
                    'snpclass'      =>  $row->{'SNPCLASS'},
                    'source'        =>  'Glovar',
                    'source_tag'    =>  'glovar',
                    'consequence'   =>  $row->{'CONSEQUENCE'},
                    'type'          =>  $pos_type,
                });

            ## DBLinks and consequences
            $self->_get_DBLinks($snp);
            
            $snps{$key} = $snp; 
        }
    }

    #&eprof_end('clone_sql');
    #&eprof_dump(\*STDERR);
    
    return [values %snps];
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
    
    #&eprof_start('fetch_snp_by_id');
    
    my $dnadb;
    eval { $dnadb = $self->ensembl_db; };
    if ($@) {
        warn "ERROR: No dnadb attached to Glovar: $@";
        return;
    }
    
    ## SNP query
    my $q1 = qq(
        SELECT
                distinct(ss.id_snp)         as internal_id,
                ss.default_name             as id_default,
                ms.position                 as snp_start,
                ms.end_position             as snp_end,
                ms.is_revcomp               as snp_strand,
                scd.description             as validated,
                ss.alleles                  as alleles,
                svd.description             as snpclass,
                cd.chromosome               as chr_name,
                sseq.id_sequence            as nt_id,
                sseq.database_seqnname      as seq_name
        FROM    
                snp_sequence sseq,
                mapped_snp ms,
                snp,
                snpvartypedict svd,
                snp_confirmation_dict scd,
                snp_summary ss,
                chromosomedict cd
        WHERE   ss.default_name = ?
        AND     sseq.id_sequence = ms.id_sequence
        AND     ms.id_snp = ss.id_snp
        AND     ss.id_snp = snp.id_snp
        AND     snp.var_type = svd.id_dict
        AND     ss.confirmation_status = scd.id_dict
        AND     sseq.chromosome = cd.id_dict
        AND     sseq.is_current = 1
    );

    my @snps = ();
    my $sth1;

    eval {
        $sth1 = $self->prepare($q1);
        $sth1->execute($id);
    }; 
    if ($@){
        warn("ERROR: SQL failed in " . (caller(0))[3] . "\n$@");
        return([]);
    }

    ## loop over all SNP mappings found and pick one; mappings to clones
    ## take preference over mappings to NT_contigs
    my (@seq_nt, @seq_clone);
    while (my $r = $sth1->fetchrow_hashref()) {
        return([]) unless keys %{$r};
        if ($r->{'SEQ_NAME'} =~ /^NT/) {
            push @seq_nt, $r;
        } else {
            push @seq_clone, $r;
        }
    }
    # if more than one NT or clone mapping has been returned, something is
    # wrong with snp_sequence.is_current, so print a warning
    if (@seq_nt > 1 or @seq_clone > 1) {
        $self->warn(
            "More than one mapping of SNP to NT_contig ("
            . join(", ", map { $_->{'SEQ_NAME'} } @seq_nt)
            . ") or clone (" 
            . join(", ", map { $_->{'SEQ_NAME'} } @seq_clone)
            . ")."
        );
    }
    my $row = $seq_clone[0] || $seq_nt[0];

    $row->{'SNP_END'} ||= $row->{'SNP_START'};
    my $snp_start = $row->{'SNP_START'};
    my $id_seq = $row->{'NT_ID'};

    ## get clone the SNP is on
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
    my $snp = Bio::EnsEMBL::ExternalData::Glovar::SNP->new;
    my $j;
    while (my ($embl_acc, $clone_start, $clone_end, $clone_strand) = $sth2->fetchrow_array()) {
        $j++;
        
        ## calculate clone coordinates for SNP
        my ($start, $end);
        if ($clone_strand == 1) {
            $start = $row->{'SNP_START'} - $clone_start + 1;
            $end = $row->{'SNP_END'} - $clone_start + 1;
        } else {
            $start = $clone_end - $row->{'SNP_END'} + 1;
            $end = $clone_end - $row->{'SNP_START'} + 1;
        }
        next if ($start < 0);

        ## map to chromosome
        my $clone = $dnadb->get_SliceAdaptor->fetch_by_region('clone', $embl_acc);
        $snp->slice($clone);
        $snp->start($start);
        $snp->end($end);
        $snp->strand($row->{'SNP_STRAND'}*$clone_strand);
        $snp = $snp->transform('chromosome');

        ## try next clone if we couldn't map the SNP
        #last if ($snp->start && $snp->end);
    }
    warn "WARNING: Multiple clones ($j) returned" if ($j > 1);
    
    $snp->dbID($row->{'INTERNAL_ID'});
    $snp->display_id($id);
    $snp->seq_region_name($row->{'CHR_NAME'});
    $snp->original_strand($row->{'SNP_STRAND'});
    $snp->source_tag('Glovar');
    $snp->snpclass($row->{'SNPCLASS'});
    $snp->raw_status($row->{'VALIDATED'});
    $snp->alleles($row->{'ALLELES'});

    ## get flanking sequence from core
    my $slice = $dnadb->get_SliceAdaptor->fetch_by_region(
        'chromosome',
        $row->{'CHR_NAME'},
        $snp->start - 25,
        $snp->end + 25,
    );
    $slice = $slice->invert if ($row->{'SNP_STRAND'} == -1);
    my $seq = $slice->seq;

    ## determine end of upstream sequence depending on range type (in-dels
    ## of type "between", i.e. start !== end, are actually inserts)
    my $up_end = 25;
    $up_end++ if (($row->{'SNPCLASS'} eq "SNP - indel") && ($snp->start ne $snp->end));
    $snp->upStreamSeq(substr($seq, 0, $up_end));
    $snp->dnStreamSeq(substr($seq, 26));
    
    ## consequences and  DBLinks
    $self->_get_consequences($snp);
    $self->_get_DBLinks($snp);

    #&eprof_end('fetch_snp_by_id');
    #&eprof_dump(\*STDERR);

    return [$snp];
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
  Example     : $glovar_adaptor->_get_DBLinks($snp, '104567');
  Description : adds external database links to snp object; links are added
                as Bio::Annotation::DBLink objects
  Return type : none
  Exceptions  : none
  Caller      : $self

=cut

sub _get_DBLinks {
    my ($self, $snp) = @_;
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
        $sth->execute($snp->dbID);
    }; 
    if ($@){
        warn("ERROR: SQL failed in " . (caller(0))[3] . "\n$@");
        return;
    }

    while (my $xref = $sth->fetchrow_hashref()) {
        my $link = new Bio::Annotation::DBLink(-database => $xref->{'TYPE'},
                                               -primary_id => $xref->{'NAME'});
        $snp->add_DBLink($link);
    }
}

=head2 _get_consequences

  Arg[1]      : Bio::EnsEMBL::SNP object
  Example     : $glovar_adaptor->_get_consequences($snp);
  Description : adds consequences (position type, consequence) to snp object
  Return type : none
  Exceptions  : none
  Caller      : $self

=cut

sub _get_consequences {
    my ($self, $snp) = @_;
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
        $sth->execute($snp->dbID, $self->consequence_exp);
    }; 
    if ($@){
        warn("ERROR: SQL failed in " . (caller(0))[3] . "\n$@");
        return;
    }

    ## get the most important consequence
    my %cons;
    while (my (undef, $pos_type, $cons) = $sth->fetchrow_array) {
        $cons{$self->_map_position_type($pos_type)} = $cons;
    }
    my ($best) = sort keys %cons;
    if ($best) {
        $snp->type($best);
        $snp->consequence($cons{$best});
    }
}

=head2 _map_position_type

  Arg[1]      : String - position type
  Example     : my $type = $glovar_adaptor->_map_position_type($glovar_type);
  Description : maps glovar position types to ensembl naming convention
                also prefixes a priority tag which allows picking the position
                type that is most important
  Return type : String - position type
  Exceptions  : none
  Caller      : $self

=cut

sub _map_position_type {
    my ($self, $type) = @_;
    my %mapping = (
        'Coding' => '01:coding',
        'Non-coding exonic' => '02:utr',
        'Intronic' => '03:intron',
        'Upstream' => '04:local',
    );
    return $mapping{$type} || '05:';
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

