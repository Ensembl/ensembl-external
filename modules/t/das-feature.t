use strict;

BEGIN { $| = 1;
        use Test::More tests => 32;
}

use Bio::EnsEMBL::ExternalData::DAS::Feature;
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

my $slice = $dba->get_SliceAdaptor()->fetch_by_region('chromosome', 'X',1000,2000,1);

  my $raw_group = {
    'group_id'    => 'group1',
    'group_label' => 'Group 1',
    'group_type'  => 'transcript',
    'note'        => [ 'Something interesting' ],
    'link'        => [
                      { 'href' => 'http://...',
                        'txt'  => 'Group Link'  }
                     ],
    'target'      => [
                      { 'target_id'    => 'Seq 1',
                        'target_start' => '400',
                        'target_stop'  => '800'  }
                     ]
  };

  my $raw_feature = {
  
    # Core Ensembl attributes:
    'start'  => 100,
    'end'    => 200,
    'strand' => -1,     # or can use "orientation"
    'slice'  => $slice, # optional, for genomic features
    
    # DAS-specific attributes:
    'orientation'   => '+',         # + or - or .
    'feature_id'    => 'feature1',
    'feature_label' => 'Feature 1',
    'type'          => 'exon',
    'type_id'       => 'SO:0000147',
    'type_category' => 'inferred from electronic annotation (ECO:00000067)',
    'score'         => 85,
    'note'          => [ 'Something useful to know' ],
    'link'          => [
                        { 'href' => 'http://...',
                          'txt'  => 'Feature Link' }
                       ],
    'group'         => [
                        $raw_group
                       ],
    'target'        => [
                        { 'target_id'    => 'Seq 1',
                          'target_start' => '500',
                          'target_stop'  => '600'  }
                       ]
    
  };
  
  my $f = Bio::EnsEMBL::ExternalData::DAS::Feature->new( $raw_feature );
  
  ok($f->display_id);
  ok($f->display_label);
  ok($f->start);
  ok($f->end);
  ok($f->seq_region_start);
  ok($f->seq_region_end);
  ok($f->type_label);
  ok($f->type_id);
  ok($f->type_category);
  ok($f->score);

  ok(@{ $f->links });
  for my $l ( @{ $f->links() } ) {
    ok($l->{'href'});
    ok($l->{'txt'});
  }
  
  ok(@{ $f->notes });
  for my $n ( @{ $f->notes() } ) {
    ok($n);
  }
 
  ok(@{ $f->targets }); 
  for my $t ( @{ $f->targets() } ) {
    ok($t->{'target_id'});
    ok($t->{'target_start'});
    ok($t->{'target_stop'});
  }
  
  ok(@{ $f->groups });
  for my $g ( @{ $f->groups() } ) {
    ok($g->display_id);
    ok($g->display_label);
    ok($g->type_label);
    
    ok(@{ $g->links });
    for my $l ( @{ $g->links() } ) {
      ok($l->{'href'});
      ok($l->{'txt'});
    }
    
    ok(@{ $g->notes });
    for my $n ( @{ $g->notes() } ) {
      ok($n);
    }
    
    ok(@{ $g->targets });
    for my $t ( @{ $g->targets() } ) {
      ok($t->{'target_id'});
      ok($t->{'target_start'});
      ok($t->{'target_stop'});
    }
  }
