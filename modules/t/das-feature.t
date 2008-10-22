use strict;

BEGIN { $| = 1;
        use Test::More tests => 1;
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
  
  printf "ID:           %s\n"     , $f->display_id();
  printf "Label:        %s\n"     , $f->display_label();
  printf "Start:        %d (%d)\n", $f->start(), $f->seq_region_start;
  printf "End:          %d (%d)\n", $f->end()  , $f->seq_region_end;
  printf "Type Label:   %s\n"     , $f->type_label();
  printf "Type ID:      %s\n"     , $f->type_id();
  printf "Category:     %s\n"     , $f->type_category();
  printf "Score:        %s\n"     , $f->score();
  
  for my $l ( @{ $f->links() } ) {
    printf "Link:         %s -> %s\n", $l->{'href'}, $l->{'txt'};
  }
  
  for my $n ( @{ $f->notes() } ) {
    printf "Note:         %s\n", $n;
  }
  
  for my $t ( @{ $f->targets() } ) {
    printf "Target:       %s:%s,%s\n", $t->{'target_id'},
                                     $t->{'target_start'},
                                     $t->{'target_stop'};
  }
  
  for my $g ( @{ $f->groups() } ) {
    printf "Group ID:     %s\n", $g->display_id();
    printf "Group Label:  %s\n", $g->display_label();
    printf "Group Type:   %s\n", $g->type_label();
    
    for my $l ( @{ $g->links() } ) {
      printf "Group Link:   %s -> %s\n", $l->{'href'}, $l->{'txt'};
    }
    
    for my $n ( @{ $g->notes() } ) {
      printf "Group Note:   %s\n", $n;
    }
    
    for my $t ( @{ $g->targets() } ) {
      printf "Group Target: %s:%s,%s\n", $t->{'target_id'},
                                         $t->{'target_start'},
                                         $t->{'target_stop'};
    }
  }
