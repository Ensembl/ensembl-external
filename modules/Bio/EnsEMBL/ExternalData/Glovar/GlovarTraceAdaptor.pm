# 
# BioPerl module for Bio::EnsEMBL::ExternalData::Glovar::GlovarTraceAdaptor
# 
# Cared for by Patrick Meidl <pm2@sanger.ac.uk>
#
# Copyright EnsEMBL
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

GlovarHaplotypeAdaptor - Database adaptor for Glovar haplotypes

=head1 SYNOPSIS

$glodb = Bio::EnsEMBL::ExternalData::Glovar::DBAdaptor->new(
                                         -user   => 'ensro',
                                         -dbname => 'snp',
                                         -host   => 'go_host',
                                         -driver => 'Oracle');
my $glovar_adaptor = $glodb->get_GlovarHaplotypeAdaptor;
$var_listref  = $glovar_adaptor->fetch_all_by_Slice($slice);

=head1 DESCRIPTION

This module is an entry point into a glovar database,

Objects can only be read from the database, not written. (They are loaded using
a separate system).

=head1 CONTACT

 Patrick Meidl <pm2@sanger.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal
methods are usually preceded with a _

=cut

package Bio::EnsEMBL::ExternalData::Glovar::GlovarTraceAdaptor;

use strict;

use Bio::EnsEMBL::MapFrag;
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
  Caller     : Bio::EnsEMBL::Slice::get_all_ExternalFeatures

=cut

sub fetch_all_by_Slice {
    my ($self, $slice, $is_light) = @_;

    unless ($slice->assembly_name && $slice->assembly_version) {
        warn ("Cannot determine assembly name and version from Slice in GlovarAdaptor!\n");
        return ([]);
    }

    my @f = ();
    if($is_light){
        push @f, @{$self->fetch_Light_Trace_by_chr_start_end($slice)};
    } else {
        push @f, @{$self->fetch_Trace_by_chr_start_end($slice)};
    } 
    return(\@f); 
}


=head2 fetch_Light_Trace_by_chr_start_end

 Title   : fetch_Light_Trace_by_chr_start_end
 Usage   : $db->fetch_Light_Trace_by_chr_start_end($slice);
 Function: find lightweight variations by chromosomal location.
 Example :
 Returns : a list ref of very light SNP objects - designed for drawing only.
 Args    : slice

=cut

sub fetch_Light_Trace_by_chr_start_end  {
    my ($self,$slice) = @_; 
    my $slice_chr    = $slice->chr_name();
    my $slice_start  = $slice->chr_start();
    my $slice_end    = $slice->chr_end();
    my $ass_name     = $slice->assembly_name();
    my $ass_version  = $slice->assembly_version();

    ## return traces from cache if available
    my $key = join(":", $slice_chr, $slice_start, $slice_end);
    if ($self->{'_cache'}->{$key}) {
        warn "using trace cache $key";
        return $self->{'_cache'}->{$key};
    }

    &eprof_start('glovar_trace2');

    ## removed DISTINCT ???
    my $q = qq(
        SELECT   
        DISTINCT
                (ssm.contig_orientation * ms.contig_match_start)
                    + ssm.start_coordinate - 1 as start_coord,
                (ssm.contig_orientation * ms.contig_match_end)
                    + ssm.start_coordinate - 1 as end_coord,
                ms.snp_rea_id_read      as read_id,
                sr.readname             as readname,
                ms.is_revcomp           as orientation,
                ms.read_match_start     as read_start,
                ms.read_match_end       as read_end
        FROM    chrom_seq cs,
                seq_seq_map ssm,
                mapped_seq ms,
                snp_read sr,
                database_dict dd
        WHERE   cs.database_seqname = '$slice_chr'
        AND     dd.database_version = '$ass_version'
        AND     dd.database_name = '$ass_name'
        AND     cs.database_source = dd.id_dict
        AND     cs.id_chromseq = ssm.id_chromseq
        AND     ssm.sub_sequence = ms.id_sequence
        AND     ms.snp_rea_id_read = sr.id_read
        AND ((
                (ms.is_revcomp = 0) 
            AND
                (ms.contig_match_start BETWEEN
                $slice_start-10000-ssm.start_coordinate AND
                $slice_end-ssm.start_coordinate+1)
            AND
                (ms.contig_match_end >$slice_start-ssm.start_coordinate+1)
            ) OR (
                (ms.is_revcomp = 1)
            AND
                (ms.contig_match_start BETWEEN
                $slice_start-ssm.start_coordinate+1 AND
                $slice_end-ssm.start_coordinate+10000)
            AND
                (ms.contig_match_end < $slice_end-ssm.start_coordinate+1)
            ))
        ORDER BY 
                start_coord
    );

    my $sth;
    eval {
        $sth = $self->prepare($q);
        $sth->execute();
    }; 
    if ($@){
        warn("ERROR: SQL failed in GlovarAdaptor->fetch_Light_Trace_by_chr_start_end()!\n$@");
        return([]);
    }

    my @traces = ();
    while (my $row = $sth->fetchrow_hashref()) {
        return([]) unless keys %{$row};
        next if $row->{'PRIVATE'};
        my ($start, $end, $strand);
        if ($row->{'ORIENTATION'} == 1) {
            $start = $row->{'END_COORD'};
            $end = $row->{'START_COORD'};
            $strand = '-1';
        } else {
            $start = $row->{'START_COORD'};
            $end = $row->{'END_COORD'};
            $strand = 1;
        }
        my $trace = Bio::EnsEMBL::MapFrag->new(
            $slice_start,
            $row->{'READ_ID'},
            'clone',
            $slice_chr,
            'Chromosome',
            $start,
            $end,
            $strand,
            $row->{'READNAME'},
        );
        $trace->add_annotation('read_start', $row->{'READ_START'});
        $trace->add_annotation('read_end', $row->{'READ_END'});
        ## add strand as annotation so that GlyphSet_simple understands it
        $trace->add_annotation('strand', $strand);

        push (@traces,$trace); 

        #warn join(" | ", $row->{'READNAME'}, $start, $end, $strand);
    }
    
    &eprof_end('glovar_trace2');
    #&eprof_dump(\*STDERR);
    
    return $self->{'_cache'}->{$key} = \@traces;
}                                       


sub fetch_Trace_by_chr_start_end  {
    my ($self, $slice) = @_;
    return(1);
}

sub fetch_Trace_Alignment_by_id  {
    my ($self, $id) = @_;
    return(1);
}

sub track_name {
    my ($self) = @_;    
    return("GlovarTrace");
}

1;

