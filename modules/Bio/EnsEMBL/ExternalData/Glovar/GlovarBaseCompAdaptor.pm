# 
# BioPerl module for Bio::EnsEMBL::ExternalData::Glovar::GlovarSNPAdaptor
# 
# Cared for by Jody Clements <jc3@sanger.ac.uk>
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

Jody Clements <jc3@sanger.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal
methods are usually preceded with a _

=cut

package Bio::EnsEMBL::ExternalData::Glovar::GlovarBaseCompAdaptor;
use vars qw(@ISA);
use strict;
use Data::Dumper;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::External::ExternalFeatureAdaptor;
use Bio::EnsEMBL::SeqFeature;
use Bio::EnsEMBL::GlovarBaseComp;
use Bio::Annotation::DBLink;
use Bio::EnsEMBL::ExternalData::Glovar::GlovarAdaptor;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

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
    push @f, @{$self->fetch_Light_Base_Comp_by_chr_start_end($slice)};
  } else {
    push @f, @{$self->fetch_Base_Comp_by_chr_start_end($slice)};
  }
  return(\@f);
}

=head2 fetch_Light_Base_Comp_by_chr_start_end

 Title   : fetch_Light_Base_Comp_by_chr_start_end
 Usage   : $db->fetch_Light_Base_Comp_by_chr_start_end($slice);
 Function: find lightweight variations by chromosomal location.
 Example :
 Returns : a list ref of very light base composition objects - designed for drawing.
 Args    : slice

=cut

sub fetch_Light_Base_Comp_by_chr_start_end {
  my ($self,$slice) = @_;
  my $slice_chr    = $slice->chr_name();
  my $slice_start  = $slice->chr_start();
  my $slice_end    = $slice->chr_end();
  my $slice_strand = $slice->strand();
  my $ass_name     = $slice->assembly_name();
  my $ass_version  = $slice->assembly_version();

  my $q = qq(SELECT 	(rp.position + ssm.start_coordinate -1) as position,
	rp.genomic_base as genomic_base,
	COUNT(decode (sp.base,'A',1
			     ,'G',NULL
			     ,'T',NULL
			     ,'C',NULL)) as A,
	COUNT(decode (sp.base,'A',NULL
			     ,'G',1
			     ,'T',NULL
			     ,'C',NULL)) as G,
	COUNT(decode (sp.base,'A',NULL
			     ,'G',NULL
			     ,'T',NULL
			     ,'C',1)) as C,
	COUNT(decode (sp.base,'A',NULL
			     ,'G',NULL
			     ,'T',1
			     ,'C',NULL)) as T
FROM	chrom_seq cs,
	seq_seq_map ssm,
	snp_sequence ss,
	reference_position rp,
	sequence_position sp
WHERE	cs.database_seqname = '$slice_chr'
AND     cs.is_current = 1
AND	cs.id_chromseq = ssm.id_chromseq
AND	ssm.sub_sequence = ss.id_sequence
AND	ss.id_sequence = rp.id_sequence
AND	rp.id_sequence = sp.repo_id_sequence
AND	sp.repo_position = rp.position
AND     sp.is_nqs = 1
AND	rp.position
	BETWEEN	($slice_start - ssm.start_coordinate + 1)
	AND	($slice_end - ssm.start_coordinate + 1)
GROUP BY (rp.position + ssm.start_coordinate),
	  rp.genomic_base
ORDER by position);

  my $sth;
  eval {
        $sth = $self->prepare($q);
        $sth->execute();
  };
  if ($@){
    warn("ERROR: SQL failed in GlovarAdaptor->fetch_Light_Base_Comp_by_chr_start_end()!\n$@");
    return([]);
  }

  my @bases = ();

  my $refs = $sth->fetchall_arrayref();

  for my $ref(@$refs){
    my($position,$genomic_base,$A_count,$G_count,$C_count,$T_count) = @$ref;

    my $basecomp = Bio::EnsEMBL::GlovarBaseComp->new_fast({
						 'position'     => $position - $slice_start + 1,
						 'genomic_base' => $genomic_base,
						 'alleles'      => {
								    'T' => $T_count,
								    'G' => $G_count,
								    'A' => $A_count,
								    'C' => $C_count,
								   },
						 '_gsf_strand'  => 1,
							  });
    push (@bases, $basecomp);

  }
  return (\@bases);
}

=head2 fetch_Base_Comp_by_chr_start_end

 Title   : fetch_Base_Comp_by_chr_start_end
 Usage   : $db->fetch_Base_Comp_by_chr_start_end($slice);
 Function: find full variations by chromosomal location.
 Example :
 Returns : a list ref of Base Composition objects.
 Args    : slice

=cut

sub fetch_Base_Comp_by_chr_start_end  {
    my ($self,$slice) = @_;

    my @vars = ();
    return(\@vars);
}


=head2 fetch_Base_Comp_by_id

  Arg[1]      : String - Position ID
  Example     : my $composition = $glovar_adaptor->fetch_Base_Comp_by_id($id);
  Description : retrieve base composition from Glovar by ID
  Return type : List of Base composition Objects

=cut

sub fetch_Base_Comp_by_id  {
    my ($self,$slice) = @_;

    my @vars = ();
    return(\@vars);
}


sub track_name {
    my ($self) = @_;
    return("GlovarBaseComp");
}

1;
