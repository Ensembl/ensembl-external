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
use vars qw(@ISA);
use strict;
use Data::Dumper;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::External::ExternalFeatureAdaptor;
use Bio::EnsEMBL::SeqFeature;
use Bio::EnsEMBL::SNP;
use Bio::Annotation::DBLink;
use Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor;

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
    push @f, @{$self->fetch_Light_Variations_by_chr_start_end($slice)};
  } else {
    push @f, @{$self->fetch_Variations_by_chr_start_end($slice)};
  } 
  return(\@f); 
}


=head2 fetch_Light_Variations_by_chr_start_end

 Title   : fetch_Light_Variations_by_chr_start_end
 Usage   : $db->fetch_Light_Variations_by_chr_start_end($slice);
 Function: find lightweight variations by chromosomal location.
 Example :
 Returns : a list ref of very light SNP objects - designed for drawing only.
 Args    : slice

=cut

sub fetch_Light_Variations_by_chr_start_end  {
    my ($self,$slice) = @_; 

    my $slice_chr    = $slice->chr_name();
    my $slice_start  = $slice->chr_start();
    my $slice_end    = $slice->chr_end();
    my $slice_strand = $slice->strand();
    my $ass_name     = $slice->assembly_name();
    my $ass_version  = $slice->assembly_version();

    my $q1 = qq(
        SELECT
                mapped_snp.position + seq_seq_map.START_COORDINATE -1
                                                as chr_start,
                mapped_snp.id_snp               as internal_id,
                seq_seq_map.contig_orientation  as chr_strand,
                snp_name.snp_name               as id_refsnp,
                'glovar'                        as source,
                'snp'                           as snpclass,
                svd.description                 as type,
                snp.is_private                  as private,
                snpf.allele_txt(snp.id_snp)     as alleles,
                scd.description                 as validated
        FROM    chrom_seq,
                seq_seq_map,
                snp_sequence,
                mapped_snp,
                snp_name,
                snp,
                snpvartypedict svd,
                snp_confirmation_dict scd,
                database_dict
        WHERE   chrom_seq.DATABASE_SEQNAME= '$slice_chr'
        AND     chrom_seq.ID_CHROMSEQ = seq_seq_map.ID_CHROMSEQ
        AND     snp_sequence.ID_SEQUENCE = seq_seq_map.SUB_SEQUENCE
        AND     mapped_snp.ID_SEQUENCE = snp_sequence.ID_SEQUENCE
        AND     snp_name.id_snp = mapped_snp.id_snp
        AND     snp.id_snp = snp_name.id_snp
        AND     snp.var_type = svd.id_dict
        AND     snp.is_confirmed = scd.id_dict
        AND     snp_name.snp_name_type = 1
        AND     chrom_seq.DATABASE_SOURCE = database_dict.ID_DICT
        AND     database_dict.DATABASE_NAME = '$ass_name'
        AND     database_dict.DATABASE_VERSION = '$ass_version'
        AND     (mapped_snp.position + seq_seq_map.START_COORDINATE -1)
        BETWEEN
                '$slice_start' AND '$slice_end'
        ORDER BY
                chr_start
    );

      my $q2 = qq(SELECT ms.id_sts,
               (ms.start_coordinate + ssm.start_coordinate -1) as start_coord,
               (ms.end_coordinate + ssm.start_coordinate -1) as end_coord,
               ss.sts_name,
               ss.id_sts as sts_id,
               length(ss.sense_oligoprimer) as sen_len,
               length(ss.antisense_oligoprimer) as anti_len,
               ss.pass_status,
               ms.is_revcomp as ori
        FROM   chrom_seq cs,
               database_dict dd,
               seq_seq_map ssm,
               mapped_sts ms,
               sts_summary ss
        WHERE  cs.database_seqname = '$slice_chr'
        AND    dd.id_dict = cs.database_source
        AND    dd.database_name = '$ass_name'
        AND    dd.database_version = '$ass_version'
        AND    ssm.id_chromseq = cs.id_chromseq
        AND    ms.id_sequence = ssm.sub_sequence
        AND    ss.id_sts = ms.id_sts
        AND    (ms.start_coordinate + ssm.start_coordinate) 
        BETWEEN 
                '$slice_start' 
        AND 
                '$slice_end'
        ORDER BY 
                end_coord
        
        );
    
    my @vars = ();
    my $sth;

    eval {
        $sth = $self->prepare($q1);
        $sth->execute();
    }; 
    if ($@){
        warn("ERROR: SQL failed in GlovarAdaptor->fetch_Light_Variations_by_chr_start_end()!\n$@");
        return([]);
    }

    while (my $rowhash = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$rowhash};
        if ($rowhash->{'PRIVATE'}){
            #print Dumper($rowhash);
            next;
        }
        #print STDERR Dumper($rowhash);
        my $var = Bio::EnsEMBL::SNP->new_fast(
            {
                '_snpid'        =>    $rowhash->{'ID_REFSNP'},
                'dbID'          =>    $rowhash->{'INTERNAL_ID'},
                '_gsf_start'    =>    $rowhash->{'CHR_START'} - $slice_start + 1,#convert assembly coords to slice coords
                '_gsf_end'      =>    $rowhash->{'CHR_START'} - $slice_start + 1,
                '_snp_strand'   =>    $rowhash->{'CHR_STRAND'},
                '_gsf_score'    =>    -1,
                '_type'         =>    '_',
                '_validated'    =>    $rowhash->{'VALIDATED'},
                'alleles'       =>    $rowhash->{'ALLELES'},
                '_snpclass'     =>    $rowhash->{'SNPCLASS'},
                '_source_tag'   =>    $rowhash->{'SOURCE'},
            });

        my $link = Bio::Annotation::DBLink->new();
        $link->database("dbSNP");
        $link->primary_id($rowhash->{'ID_REFSNP'});
        $var->add_DBLink($link);
        #print STDERR Dumper($var);
        push (@vars,$var); 
    }
    
    return(\@vars);

    ############# for STSs  ###############
    eval {
        $sth = $self->prepare($q2);
        $sth->execute();
    }; 
    if ($@){
        warn("ERROR: SQL failed in GlovarAdaptor->fetch_Light_Variations_by_chr_start_end()!\n$@");
        return([]);
    }

    while (my $rowhash = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$rowhash};
        #print STDERR Dumper($rowhash);
        my $var = Bio::EnsEMBL::SNP->new_fast(
            {
                '_snpid'        =>    $rowhash->{'STS_NAME'},
                'dbID'          =>    $rowhash->{'STS_NAME'},
                '_gsf_start'    =>    $rowhash->{'START_COORD'} - $slice_start + 1,#convert assembly coords to slice coords
                '_gsf_end'      =>    $rowhash->{'END_COORD'} - $slice_start + 1,
                '_snp_strand'   =>    -1,
                '_gsf_score'    =>    -1,
                '_type'         =>    '_',
                '_validated'    =>    $rowhash->{'VALIDATED'},
                'alleles'       =>    $rowhash->{'ALLELES'},
                '_source_tag'   =>    $rowhash->{'SOURCE'},
            });

        my $link = Bio::Annotation::DBLink->new();
        $link->database("dbSNP");
        $link->primary_id($rowhash->{'ID_REFSNP'});
        $var->add_DBLink($link);
        #print STDERR Dumper($var);
        push (@vars,$var); 

    }
    
    return(\@vars);
}                                       

=head2 fetch_Variations_by_chr_start_end

 Title   : fetch_Variations_by_chr_start_end
 Usage   : $db->fetch_Variations_by_chr_start_end($slice);
 Function: find full variations by chromosomal location.
 Example :
 Returns : a list ref SNP objects.
 Args    : slice

=cut

sub fetch_Variations_by_chr_start_end  {
    my ($self,$slice) = @_; 

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
    my $ass_name = $self->db->dnadb->assembly_name;
    my $ass_version = $self->db->dnadb->assembly_version;
    
    my $q1 = qq(
        SELECT
                snp_summary.ID_SNP              as INTERNAL_ID,
                snp_summary.DEFAULT_NAME        as ID_DEFAULT,
                mapped_snp.POSITION + seq_seq_map.START_COORDINATE -1
                                                as CHR_START,
                mapped_snp.END_POSITION         as CHR_END,
                seq_seq_map.CONTIG_ORIENTATION  as CHR_STRAND,
                'Glovar'                        as SOURCE,
                'SNP'                           as SNPCLASS,
                scd.DESCRIPTION                 as VALIDATED,
                snp_sequence.DATABASE_SEQNNAME      as SEQNAME,
                snp_sequence.DATABASE_SEQVERSION    as SEQVERSION,
                snp_sequence.CHROMOSOME         as CHR,
                snp_summary.ALLELES             as ALLELES,
                snp_summary.IS_PRIVATE          as PRIVATE
        FROM    chrom_seq,
                database_dict,
                seq_seq_map,
                snp_sequence,
                mapped_snp,
                snp_summary,
                snp_confirmation_dict scd
        WHERE   snp_summary.DEFAULT_NAME = '$id'
        AND     database_dict.DATABASE_NAME = '$ass_name'
        AND     database_dict.DATABASE_VERSION = '$ass_version'
        AND     database_dict.ID_DICT = chrom_seq.DATABASE_SOURCE
        AND     chrom_seq.ID_CHROMSEQ = seq_seq_map.ID_CHROMSEQ
        AND     seq_seq_map.SUB_SEQUENCE = snp_sequence.ID_SEQUENCE
        AND     snp_sequence.ID_SEQUENCE = mapped_snp.ID_SEQUENCE
        AND     mapped_snp.ID_SNP = snp_summary.ID_SNP
        AND     snp_summary.CONFIRMATION_STATUS = scd.ID_DICT
    );

    my @vars = ();
    my $sth;

    eval {
        $sth = $self->prepare($q1);
        $sth->execute();
    }; 
    if ($@){
        warn("ERROR: SQL failed in GlovarAdaptor->fetch_SNP_by_id()!
            \n$@");
        return;
    }

    my $row = $sth->fetchrow_hashref();
    if (!(keys %{$row}) || $row->{'PRIVATE'}){
        return;
    }

    my $snp = Bio::EnsEMBL::SNP->new;
    
    my $acc_version = '';
    $acc_version = $row->{'SEQNAME'} if $row->{'SEQNAME'};
    $acc_version .= "." . $row->{'SEQVERSION'} if $row->{'SEQVERSION'};

    $snp->dbID($row->{'INTERNAL_ID'});
    $snp->seqname($acc_version);
    $snp->start($row->{'CHR_START'});
    $snp->end($row->{'CHR_END'});
    $snp->strand($row->{'CHR_STRAND'});
    $snp->original_strand($row->{'CHR_STRAND'});
    
    $snp->source_tag($row->{'SOURCE'});
    $snp->snpclass($row->{'SNPCLASS'});
    $snp->raw_status($row->{'VALIDATED'});

    $snp->alleles($row->{'ALLELES'});

    my $slice = $self->db->dnadb->get_SliceAdaptor->fetch_by_chr_start_end(
       $row->{'CHR'},
       $row->{'CHR_START'} - 20,
       $row->{'CHR_START'},
    );
    $snp->upStreamSeq($slice->seq);
    
    if (0) {
        my $seq_adaptor = $self->db->dnadb->get_SequenceAdaptor;
        my $seq5 = $seq_adaptor->fetch_by_assembly_location(
           $row->{'CHR_START'} - 20,
           $row->{'CHR_START'},
           $row->{'CHR_STRAND'},
           $row->{'CHR'},
           $self->db->dnadb->get_MetaContainer->get_default_assembly
        );
        $snp->upStreamSeq($seq5);
    }
    #$snp->dnStreamSeq($seq3);

    ## not available
    #$snp->score($mapweight); 
    #$snp->het($het);
    #$snp->hetse($hetse);
    
    #DBLink
    my $q2 = qq(
        SELECT
                snp_name.SNP_NAME               as NAME,
                snpnametypedict.DESCRIPTION     as TYPE
        FROM    
                snp_name,
                snpnametypedict
        WHERE   snp_name.ID_SNP = ?
        AND     snp_name.SNP_NAME_TYPE = snpnametypedict.ID_DICT
    );
    my $sth2;
    eval {
        $sth2 = $self->prepare($q2);
        $sth2->execute($row->{'INTERNAL_ID'});
    }; 
    if ($@){
        warn("ERROR: SQL failed in GlovarAdaptor->fetch_SNP_by_id()!
            \n$@");
        return;
    }

    while (my $xref = $sth2->fetchrow_hashref()) {
        my $link = new Bio::Annotation::DBLink;
        $link->database($xref->{'TYPE'});
        $link->primary_id($xref->{'NAME'});
        $snp->add_DBLink($link);
    }
    
    ## sanity check for more result rows
    while (my $row = $sth->fetchrow_hashref()) {
        if (keys %{$row}) {
            warn "Glovar returned more than one result row!";
            last;
        }
    }
    
    return $snp;
}


sub track_name {
    my ($self) = @_;    
    return("GlovarSNP");
}

1;

