=head2 DESCRIPTION

This test covers the following DAS conversions:
  uniprot_peptide -> ensembl_peptide

=cut
use strict;

BEGIN { $| = 1;
	use Test::More tests => 5;
}

use Bio::EnsEMBL::ExternalData::DAS::Coordinator;
# TODO: need to use data from a test database!
#use Bio::EnsEMBL::Test::MultiTestDB;
#use Bio::EnsEMBL::Test::TestUtils;
#my $multi = Bio::EnsEMBL::Test::MultiTestDB->new();
#my $dba = $multi->get_DBAdaptor( 'core' );
use Bio::EnsEMBL::Registry;
Bio::EnsEMBL::Registry->load_registry_from_db(
  -host => 'ensembldb.ensembl.org',
  -user => 'anonymous',
);
my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( 'human', 'core' ) || die("Can't connect to database");

my $pea = $dba->get_TranslationAdaptor();
my $prot = $pea->fetch_by_stable_id('ENSP00000324984');
my ($xref) = grep {$_->dbname =~ m{uniprot/sptrembl|uniprot/swissprot}i && $_->primary_id eq 'Q96LP6'} @{ $prot->get_all_DBEntries('Uniprot/%') };
my $prot_cs = Bio::EnsEMBL::CoordSystem->new( -name => 'ensembl_peptide', -rank => 99 );
my $unip_cs = Bio::EnsEMBL::CoordSystem->new( -name => 'uniprot_peptide', -rank => 99 );

my $desc = 'uniprot->peptide';
my $c = Bio::EnsEMBL::ExternalData::DAS::Coordinator->new();
my $segments = $c->_get_Segments($unip_cs, $prot_cs, undef, undef, $prot);
ok((grep {$_ eq $xref->primary_id} @$segments), "$desc correct query segment");
SKIP: {
my $q_start = $xref->query_start;
my $q_end   = $xref->query_start + 9;
my $q_feat = &build_feat($xref->primary_id, $q_start, $q_end);
my $f = $c->map_Features([$q_feat], undef, $unip_cs, $prot_cs, undef)->[0];
ok($f, 'got mapped feature') || skip('requires mapped feature', 3);
my $c_start = $xref->translation_start;
my $c_end   = $xref->translation_start + 9;
is($f->start,  $c_start,  "$desc correct start");
is($f->end,    $c_end,    "$desc correct end");
is($f->strand, 1,         "$desc correct strand");
}

sub build_feat {
  my ($segid, $start, $end, $strand ) = @_;
  return {
    'segment_id'  => $segid,
    'start'       => $start,
    'end'         => $end,
    'orientation' => defined $strand && $strand == -1 ? '-' : '+',
  };
}