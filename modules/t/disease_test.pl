use strict;
use Bio::EnsEMBL::Map::DBSQL::Obj;
use Bio::EnsEMBL::DBSQL::Obj;
use Bio::EnsEMBL::ExternalData::Disease::DBHandler;





my $mapdb = new Bio::EnsEMBL::Map::DBSQL::Obj( -user => 'ensro', 
					    -dbname => 'maps2_f15', 
					    -host=>'ensrv4.sanger.ac.uk',
					    -ensdb=>'f15');

my $ensembldb = new Bio::EnsEMBL::DBSQL::Obj( -user => 'ensro', 
					    -dbname => 'ensembl_freeze15_tim',
					    -host=>'ensrv4.sanger.ac.uk');

my $diseasedb = new Bio::EnsEMBL::ExternalData::Disease::DBHandler( -user => 'ensembl', 
						      -dbname => 'disease',
						      -host=>'sol28.ebi.ac.uk',
						      -ensdb=>$ensembldb,
						      -mapdb=>$mapdb);


if ($mapdb){print "connected maps\n";}
if ($ensembldb){print "connected ensembl\n";}
if ($diseasedb){print "connected diseases\n";}

#my @diseases=$diseasedb->diseases_on_chromosome(22);
#my @diseases=$diseasedb->diseases_without_genes;
my @diseases=$diseasedb->all_diseases;
#my @diseases=$diseasedb->disease_by_name("DiGeorge syndrome (2)");
#my @diseases=$diseasedb->diseases_like("diabetes");

foreach my $dis (@diseases)
{
    print "\n",$dis->name, "\n";
    
    foreach my $location($dis->each_Location){
	
	print "has gene ",$location->external_gene," on chromosome ",
	$location->chromosome," (",$location->cyto_start,"-",$location->cyto_end,")","\n";
	
	if (defined $location->ensembl_gene){
	    print "FOUND ensembl gene for ",$location->external_gene," = ",$location->ensembl_gene->id;

	    foreach my $transcript ($location->ensembl_gene->each_Transcript){
		print " transcripts: ",$transcript->id,"\n";}
	}
	else {print "no ensembl predictions for ", $location->external_gene,"\n";}
    }
    
    print "\n";
}




