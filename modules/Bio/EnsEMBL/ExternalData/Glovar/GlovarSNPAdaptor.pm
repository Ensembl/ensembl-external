# 
# BioPerl module for Bio::EnsEMBL::ExternalData::Glovar::GlovarSNPAdaptor
# 
# Cared for by Tony Cox <avc@sanger.ac.uk>
#
# Copyright EnsEMBL
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

GlovarAdaptor - DESCRIPTION of Object

  This object represents the Glovar database.

=head1 SYNOPSIS

$glodb = Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor->new(
                                         -user   => 'ensro',
                                         -dbname => 'snp',
                                         -host   => 'go_host',
                                         -driver => 'Oracle');

my $glovar_adaptor = $glodb->get_GlovarAdaptor;

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

package Bio::EnsEMBL::ExternalData::Glovar::GlovarSNPAdaptor;

use strict;

use Bio::EnsEMBL::SNP;
use Bio::Annotation::DBLink;
use Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor;

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
  Caller     : Bio::EnsEMBL::Slice::get_all_Glovar_variations

=cut

sub fetch_all_by_Slice {
  my ($self, $slice, $is_light) = @_;

  unless($slice->assembly_name() && $slice->assembly_version()){
      warn("Cannot determine assembly name and version from Slice in GlovarAdaptor!\n");
      return([]);
  }

  my @f = ();
  if($is_light){
    push @f, @{$self->fetch_Light_SNP_by_chr_start_end($slice)};
  } else {
    push @f, @{$self->fetch_SNP_by_chr_start_end($slice)};
  } 
  return(\@f); 
}


=head2 fetch_Light_SNP_by_chr_start_end

 Title   : fetch_Light_SNP_by_chr_start_end
 Usage   : $db->fetch_Light_SNP_by_chr_start_end($slice);
 Function: find lightweight variations by chromosomal location.
 Example :
 Returns : a list ref of very light SNP objects - designed for drawing only.
 Args    : slice

=cut

sub fetch_Light_SNP_by_chr_start_end  {
    my ($self, $slice) = @_; 
    my $slice_chr    = $slice->chr_name();
    my $slice_start  = $slice->chr_start();
    my $slice_end    = $slice->chr_end();
    my $slice_strand = $slice->strand();
    my $ass_name     = $slice->assembly_name();
    my $ass_version  = $slice->assembly_version();

    my $q = qq(
        SELECT
                ss.ID_SNP                       as INTERNAL_ID,
                ss.DEFAULT_NAME                 as ID_DEFAULT,
                (seq_seq_map.contig_orientation * mapped_snp.POSITION)
                    + seq_seq_map.START_COORDINATE - 1
                                                as CHR_START,
                (seq_seq_map.contig_orientation * mapped_snp.END_POSITION)
                    + seq_seq_map.START_COORDINATE - 1
                                                as CHR_END,
                seq_seq_map.CONTIG_ORIENTATION  as CHR_STRAND,
                scd.DESCRIPTION                 as VALIDATED,
                ss.ALLELES                      as ALLELES,
                svd.DESCRIPTION                 as SNPCLASS,
                ss.IS_PRIVATE                   as PRIVATE
        FROM    chrom_seq,
                database_dict,
                seq_seq_map,
                snp_sequence,
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
        AND     seq_seq_map.SUB_SEQUENCE = snp_sequence.ID_SEQUENCE
        AND     snp_sequence.ID_SEQUENCE = mapped_snp.ID_SEQUENCE
        AND     mapped_snp.ID_SNP = ss.ID_SNP
        AND     ss.ID_SNP = snp.ID_SNP
        AND     snp.VAR_TYPE = svd.ID_DICT
        AND     ss.CONFIRMATION_STATUS = scd.ID_DICT
        AND     mapped_snp.POSITION
        BETWEEN
                ('$slice_start' - seq_seq_map.START_COORDINATE - 99)
                AND 
                ('$slice_end' - seq_seq_map.START_COORDINATE + 1)
        ORDER BY
                CHR_START

    );

    my $sth;
    eval {
        $sth = $self->prepare($q);
        $sth->execute();
    }; 
    if ($@){
        warn("ERROR: SQL failed in GlovarAdaptor->fetch_Light_SNP_by_chr_start_end()!\n$@");
        return([]);
    }

    my %ambig = qw(AC M ACG V ACGT N ACT H AG R AGT D AT W CG S CGT B CT Y GT K);
    my @snps = ();
    while (my $row = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$row};
        next if $row->{'PRIVATE'};

        my $ambig = $ambig{ join '', sort split /\|/, $row->{'ALLELES'} };
        $row->{'CHR_END'} ||= $row->{'CHR_START'};
        my $snp = Bio::EnsEMBL::SNP->new_fast(
            {
                '_snpid'        =>    $row->{'ID_DEFAULT'},
                'dbID'          =>    $row->{'INTERNAL_ID'},
                '_gsf_start'    =>    $row->{'CHR_START'} - $slice_start + 1,
                '_gsf_end'      =>    $row->{'CHR_END'} - $slice_start + 1,
                '_snp_strand'   =>    $row->{'CHR_STRAND'},
                '_gsf_score'    =>    -1,
                '_validated'    =>    $row->{'VALIDATED'},
                '_raw_status'   =>    $row->{'VALIDATED'},
                '_ambiguity_code' =>  $ambig,
                'alleles'       =>    $row->{'ALLELES'},
                '_snpclass'     =>    $row->{'SNPCLASS'},
                '_source'       =>    'Glovar',
                '_source_tag'   =>    'glovar',
                '_consequence'  =>    $row->{'CONSEQUENCE'},
                '_type'         =>    $row->{'POS_TYPE'},
            });

        ## DBLinks and consequences
        $self->_get_DBLinks($snp, $row->{'INTERNAL_ID'});
        $self->_get_consequences($snp, $row->{'INTERNAL_ID'});
        
        push (@snps, $snp); 
    }

    return(\@snps);
}                                       

=head2 fetch_SNP_by_chr_start_end

 Title   : fetch_SNP_by_chr_start_end
 Usage   : $db->fetch_SNP_by_chr_start_end($slice);
 Function: find full variations by chromosomal location.
 Example :
 Returns : a list ref SNP objects.
 Args    : slice

=cut

sub fetch_SNP_by_chr_start_end  {
    my ($self,$slice) = @_; 

    ## to be implemented

    my @vars = ();
    return(\@vars);
}                                       

=head2 fetch_SNP_by_id

  Arg[1]      : String - Variation ID
  Example     : my $variation = $glovar_adaptor->fetch_SNP_by_id($id);
  Description : retrieve variations from Glovar by ID
  Return type : List of Bio::EnsEMBL::SNP

=cut

sub fetch_SNP_by_id  {
    my ($self, $id) = @_;
    
    ## get assembly name and version from DNA db
    my $dnadb;
    eval { $dnadb = $self->db->dnadb; };
    if ($@) {
        warn "ERROR: No dnadb attached to Glovar: $@";
        return;
    }
    my $ass_name = $dnadb->assembly_name;
    my $ass_version = $dnadb->assembly_version;
    
    my $q1 = qq(
        SELECT
                ss.ID_SNP                       as INTERNAL_ID,
                ss.DEFAULT_NAME                 as ID_DEFAULT,
                (seq_seq_map.contig_orientation * mapped_snp.POSITION)
                    + seq_seq_map.START_COORDINATE - 1
                                                as CHR_START,
                (seq_seq_map.contig_orientation * mapped_snp.END_POSITION)
                    + seq_seq_map.START_COORDINATE - 1
                                                as CHR_END,
                seq_seq_map.CONTIG_ORIENTATION  as CHR_STRAND,
                scd.DESCRIPTION                 as VALIDATED,
                snp_sequence.DATABASE_SEQNNAME      as SEQNAME,
                snp_sequence.DATABASE_SEQVERSION    as SEQVERSION,
                snp_sequence.CHROMOSOME         as CHR_NAME,
                ss.ALLELES                      as ALLELES,
                ss.IS_PRIVATE                   as PRIVATE
        FROM    chrom_seq,
                database_dict,
                seq_seq_map,
                snp_sequence,
                mapped_snp,
                snp_name,
                snp_confirmation_dict scd,
                snp_summary ss
        WHERE   snp_name.SNP_NAME = '$id'
        AND     database_dict.DATABASE_NAME = '$ass_name'
        AND     database_dict.DATABASE_VERSION = '$ass_version'
        AND     database_dict.ID_DICT = chrom_seq.DATABASE_SOURCE
        AND     chrom_seq.ID_CHROMSEQ = seq_seq_map.ID_CHROMSEQ
        AND     seq_seq_map.SUB_SEQUENCE = snp_sequence.ID_SEQUENCE
        AND     snp_sequence.ID_SEQUENCE = mapped_snp.ID_SEQUENCE
        AND     mapped_snp.ID_SNP = ss.ID_SNP
        AND     ss.ID_SNP = snp_name.ID_SNP
        AND     ss.CONFIRMATION_STATUS = scd.ID_DICT
    );

    my @snps = ();
    my $sth;

    eval {
        $sth = $self->prepare($q1);
        $sth->execute();
    }; 
    if ($@){
        warn("ERROR: SQL failed in GlovarAdaptor->fetch_SNP_by_id()!
            \n$@");
        return([]);
    }

    while (my $row = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$row};
        next if $row->{'PRIVATE'};

        my $snp = Bio::EnsEMBL::SNP->new;
        
        my $acc_version = '';
        $acc_version = $row->{'SEQNAME'} if $row->{'SEQNAME'};
        $acc_version .= "." . $row->{'SEQVERSION'} if $row->{'SEQVERSION'};

        $snp->dbID($row->{'INTERNAL_ID'});
        $snp->seqname($acc_version);
        $snp->start($row->{'CHR_START'});
        $snp->end($row->{'CHR_END'} || $row->{'CHR_START'});
        $snp->strand($row->{'CHR_STRAND'});
        $snp->original_strand($row->{'CHR_STRAND'});
        $snp->chr_name($row->{'CHR_NAME'});
        
        $snp->source_tag('Glovar');
        $snp->snpclass('SNP');
        $snp->raw_status($row->{'VALIDATED'});

        $snp->alleles($row->{'ALLELES'});

        ## get flanking sequence from core
        my $slice = $dnadb->get_SliceAdaptor->fetch_by_chr_start_end(
           $row->{'CHR_NAME'},
           $row->{'CHR_START'} - 25,
           $row->{'CHR_START'} + 25,
        );
        my $seq = $slice->seq;
        $snp->upStreamSeq(substr($seq, 0, 25));
        $snp->dnStreamSeq(substr($seq, 26));
        
        ## these attributes are on ensembl SNPs, but are not available in Glovar
        #$snp->score($mapweight);
        #$snp->het($het);
        #$snp->hetse($hetse);
        
        ## DBLinks and consequences
        $self->_get_DBLinks($snp, $row->{'INTERNAL_ID'});
        $self->_get_consequences($snp, $row->{'INTERNAL_ID'});
        
        push @snps, $snp;
    }

    return \@snps;
}

=head2 _get_DBLinks

  Arg[1]      : Bio::EnsEMBL::SNP object
  Arg[2]      : glovar SNP ID (ID_SNP)
  Example     : $glovar_adaptor->_get_DBLinks($snp, '104567');
  Description : adds external database links to snp object; links are added
                as Bio::Annotation::DBLink objects
  Return type : none

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
        warn("ERROR: SQL failed in GlovarAdaptor->fetch_SNP_by_id()!
            \n$@");
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
  Example     : $glovar_adaptor->_get_consequences($snp, '104567');
  Description : adds consequences (position type, consequence) to snp object;
                these are stored as anonymous arrayrefs in snp->type and
                snp->consequence
  Return type : none

=cut

sub _get_consequences {
    my ($self, $snp, $id) = @_;
    my $q = qq(
        SELECT
                ptd.DESCRIPTION         as POS_TYPE,
                sgc_dict.DESCRIPTION    as CONSEQUENCE
        FROM    
                snp_gene_consequence sgc
        LEFT JOIN
                position_type_dict ptd on sgc.POSITION_DESCRIPTION = ptd.ID_DICT
        LEFT JOIN
                sgc_dict on sgc.CONSEQUENCE = sgc_dict.ID_DICT
        WHERE   sgc.ID_SNP = ?
        ORDER BY ptd.ID_DICT
    );
    my $sth;
    eval {
        $sth = $self->prepare($q);
        $sth->execute($id);
    }; 
    if ($@){
        warn("ERROR: SQL failed in GlovarAdaptor->fetch_SNP_by_id()!
            \n$@");
        return;
    }

    # this is a bit hacky, since it abuses Variation::type and
    # Variation::consequence to store an anonymous arrayref instead of a string
    my ($t, $c);
    while (my $cons = $sth->fetchrow_hashref()) {
        push @{$t}, $self->_map_position_type($cons->{'POS_TYPE'});
        push @{$c}, $cons->{'CONSEQUENCE'};
    }
    $snp->type($t || []);
    $snp->consequence($c || []);
}

=head2 _map_position_type

  Arg[1]      : String - position type
  Example     : my $type = $glovar_adaptor->_map_position_type($glovar_type);
  Description : maps glovar position types to ensembl naming convention
  Return type : String - position type

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

sub track_name {
    my ($self) = @_;    
    return("GlovarSNP");
}

1;

