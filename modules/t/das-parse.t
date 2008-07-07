use strict;

BEGIN {
    $| = 1;
    use Test;
    plan tests => 1;
}

use Bio::EnsEMBL::ExternalData::DAS::SourceParser;

my $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
  -location => 'http://www.ebi.ac.uk/das-srv/genomicdas/das',
);
my $sources = $parser->fetch_Sources( -taxid => 9606 );
ok(scalar @{ $sources });