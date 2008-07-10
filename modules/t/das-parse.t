use strict;

BEGIN {
    $| = 1;
    use Test;
    plan tests => 1;
}

use Bio::EnsEMBL::ExternalData::DAS::SourceParser;

my $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
  -location => 'http://www.ensembl.org/das',
);
my $sources = $parser->fetch_Sources( -taxid => 9606 );
if ( ok(scalar @{ $sources }) ) {
  ok( $sources->[0]->display_label );
  ok( $sources->[0]->url );
  ok( $sources->[0]->dsn );
  ok( $sources->[0]->homepage );
  ok( $sources->[0]->maintainer );
  ok( scalar @{ $sources->[0]->coord_systems || [] } );
}