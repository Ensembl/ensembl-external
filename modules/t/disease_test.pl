use strict;
use Bio::EnsEMBL::Map::DBSQL::Obj;
use Bio::EnsEMBL::DBSQL::Obj;
use Bio::EnsEMBL::ExternalData::Disease::DBHandler;





my $mapdb = new Bio::EnsEMBL::Map::DBSQL::Obj( -user => 'ensro', 
					    -dbname => 'maps2', 
					    -host=>'ensrv3.sanger.ac.uk',
					    -ensdb=>'ensembl081');

my $ensembldb = new Bio::EnsEMBL::DBSQL::Obj( -user => 'ensro', 
					    -dbname => 'ensembl081',
					    -host=>'ensrv3.sanger.ac.uk');

my $diseasedb = new Bio::EnsEMBL::ExternalData::Disease::DBHandler( -user => 'ensembl', 
						      -dbname => 'disease',
						      -host=>'sol28.ebi.ac.uk',
						      -ensdb=>$ensembldb,
						      -mapdb=>$mapdb);


#my @diseases=$diseasedb->diseases_on_chromosome(22);
#my @diseases=$diseasedb->diseases_without_genes;
my @diseases=$diseasedb->all_diseases;
#my @diseases=$diseasedb->disease_by_name("DiGeorge syndrome (2)");
#my @diseases=$diseasedb->diseases_like("leukemia, acute lymphoblastic");

foreach my $dis (@diseases)
{
   # print "\n",$dis->name, "\n";
    
    foreach my $location($dis->each_Location){
	if (defined $location->ensembl_gene){
	print "gene ",$location->external_gene," chromosome ",
	$location->chromosome," ENSGENE ",$location->ensembl_gene->id,"\n";
}
    }

    print "\n";
}




