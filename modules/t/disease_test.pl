use strict;
use Bio::EnsEMBL::Map::DBSQL::Obj;
use Bio::EnsEMBL::DBSQL::Obj;
use Bio::EnsEMBL::ExternalData::Disease::DBHandler;





my $mapdb = new Bio::EnsEMBL::Map::DBSQL::Obj( -user => 'root', 
					    -dbname => 'maps2', 
					    -host=>'ensrv3.sanger.ac.uk',
					    -ensdb=>'f15');



my $ensembldb = new Bio::EnsEMBL::DBSQL::Obj( -user => 'ensro', 
					    -dbname => 'f15',
					    -host=>'ensrv3.sanger.ac.uk');


my $diseasedb = new Bio::EnsEMBL::ExternalData::Disease::DBHandler( -user => 'root', 
						      -dbname => 'disease',
						      -host=>'ensrv3.sanger.ac.uk',
						      -ensdb=>$ensembldb,
						      -mapdb=>$mapdb);





#my @diseases=$diseasedb->diseases_on_chromosome(22);
#my @diseases=$diseasedb->diseases_without_genes;
#my @diseases=$diseasedb->all_diseases;
#my @diseases_names=$diseasedb->all_disease_names_limit();
#my @diseases_names=$diseasedb->disease_names_on_chromosome_limit(1,90,3);

#my @diseases_names=$diseasedb->disease_names_with_genes(90,3);
#my @diseases_names=$diseasedb->disease_names_without_genes(4,3);
my @diseases=$diseasedb->diseases_like("leukemia");
my @diseases_names=$diseasedb->disease_names_like("diabetes",4,5);
#my @diseases=$diseasedb->disease_by_name("DiGeorge syndrome (2)");
#my @diseases=$diseasedb->disease_by_name("Albinism, rufous, 278400 (3)");








foreach my $disease_name (@diseases_names)
{
    print $disease_name,"\n";
}


print "count ",$diseasedb->disease_names_like_count('diabetes'),"\n";





foreach my $dis (@diseases)
{
    print $dis->name,"\n";


    foreach my $location($dis->each_Location){
	
		print "has gene ",$location->external_gene," on chromosome ",
		$location->chromosome," (",$location->cyto_start,"-",$location->cyto_end,")","\n";
	
	if (defined $location->ensembl_gene){

	    print $dis->name," ",$location->external_gene," = ",$location->ensembl_gene->id,"\n";
	}
	else {print "no ensembl predictions for ", $location->external_gene,"\n";}
    }
}















