package Bio::EnsEMBL::ExternalData::Disease::DBHandler; 


use strict;
use Bio::Root::Object;
use DBI;
use Bio::EnsEMBL::ExternalData::Disease::Disease;
use Bio::EnsEMBL::ExternalData::Disease::DiseaseLocation;
use vars qw(@ISA);

@ISA = qw( Bio::Root::RootI );



sub new 
{
    my($class,@args) = @_;
    my $self = bless {}, $class;
    
    my ($db,$host,$driver,$user,$password,$debug,$ensdb,$mapdb) = 
      $self->_rearrange([qw(DBNAME
			    HOST
			    DRIVER
			    USER
			    PASS
			    DEBUG
			    ENSDB
			    MAPDB
			    )],@args);
    

    $driver || ( $driver = 'mysql' );
    $host   || ( $host = 'sol28.ebi.ac.uk' );
    $db     || ( $db = 'disease' );
    $user   || ( $user = 'ensembl' );   
    $ensdb  || $self->throw("I need ensembl db obj");
    $mapdb  || $self->throw("I need map db obj");
   
    $self->_ensdb($ensdb); 
    $self->_mapdb($mapdb); 
    
    my $dsn = "DBI:$driver:database=$db;host=$host";
    if( $debug && $debug > 10 ) {
	$self->_db_handle("dummy dbh handle in debug mode $debug");
    } else {
	my $dbh = DBI->connect("$dsn","$user",$password,{RaiseError => 1});
	$dbh || $self->throw("Could not connect to database $db user $user using [$dsn] as a locator");
	$self->_db_handle($dbh);
    }
    
    print STDERR "Connected to $db on $host.\n";
    
    return $self; 
}




sub all_diseases 
{
    my ($self)=@_;

    my $query_string='select d.disease,g.id,g.gene_symbol,g.omim_id,g.start_cyto,g.end_cyto, 
                      g.chromosome from disease as d,gene as g where d.id = g.id';

    return $self->_get_diseases($query_string);

} 
                         


sub diseases_on_chromosome 
{                          
    my ($self,$chromosome_no)=@_;

    $chromosome_no || $self->throw("I need chromosome number");
    
    my $query_string= "select d.disease,g.id,g.gene_symbol,g.omim_id,g.start_cyto,g.end_cyto, 
                       g.chromosome from disease as d,gene as g where d.id = g.id 
                       and g.chromosome='$chromosome_no'";

    return $self->_get_diseases($query_string);
       
}
                          

sub diseases_with_genes 
    
{
    my ($self)=@_;

    my $query_string= "select d.disease,g.id,g.gene_symbol,g.omim_id,g.start_cyto,g.end_cyto, 
                       g.chromosome from disease as d,gene as g where d.id = g.id 
                       and g.gene_symbol IS NOT NULL";

    return $self->_get_diseases($query_string);


} 


sub diseases_without_genes 
{
    my ($self)=@_;

    my $query_string= "select d.disease,g.id,g.gene_symbol,g.omim_id,g.start_cyto,g.end_cyto, 
                       g.chromosome from disease as d,gene as g where d.id = g.id 
                       and g.gene_symbol IS NULL";


    return $self->_get_diseases($query_string);


} 

                     
sub disease_by_name
{                          
    my ($self,$disease_name)=@_;

 my $query_string= "select d.disease,g.id,g.gene_symbol,g.omim_id,g.start_cyto,g.end_cyto,
                    g.chromosome from disease as d,gene as g where d.id = g.id 
                    and d.disease='$disease_name'";

    return $self->_get_diseases($query_string);

}



sub diseases_like 
{
    my ($self,$disease)=@_;
    
    my $query_string="select d.disease,g.id,g.gene_symbol,g.omim_id,g.start_cyto,g.end_cyto, 
                      g.chromosome from disease as d,gene as g where d.id = g.id and d.disease like '%$disease%'";

    return $self->_get_diseases($query_string);

} 
                         


sub _get_diseases
{

my ($self,$query_string)=@_;


my $sth=$self->_db_handle->prepare($query_string);

$sth->execute;

my $id;
my @diseases;
my $counter;
my $disease;

while ( my $rowhash = $sth->fetchrow_hashref) 
{
    $counter++;
    if ($id!=$rowhash->{'id'})
    {	
	unless ($counter==1){push @diseases,$disease;}
	$disease=new Bio::EnsEMBL::ExternalData::Disease::Disease;
	$disease->name($rowhash->{'disease'});
    }

    my $location=new Bio::EnsEMBL::ExternalData::Disease::DiseaseLocation(
							    -db_id=>$rowhash->{'omim_id'},
							    -cyto_start=>$rowhash->{'start_cyto'},
							    -cyto_end=>$rowhash->{'end_cyto'},
							    -external_gene=>$rowhash->{'gene_symbol'},
							    -chromosome=>$rowhash->{'chromosome'});

    $disease->add_Location($location);

    $id=$rowhash->{'id'};
}

unless (! defined $disease ){push @diseases,$disease;}


if (defined $self->_ensdb){@diseases=$self->_link2ensembl(@diseases);}
if (defined $self->_mapdb){@diseases=$self->_link2maps(@diseases);}


return @diseases;


}


                       


sub _prepare
{
    my ($self,$string) = @_;
    
    if( ! $string ) {$self->throw("Attempting to prepare an empty SQL query!");}
    
    my( $sth );
    eval {$sth = $self->_db_handle->prepare($string);};
    $self->throw("Error preparing $string\n$@") if $@;
    return $sth;
    
}


sub _db_handle 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_db_handle'} = $value;}
  
  return $self->{'_db_handle'};
}


sub _ensdb 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_ensdb'} = $value;}
  
  return $self->{'_ensdb'};
}


sub _mapdb 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_mapdb'} = $value;}
  
  return $self->{'_mapdb'};
}




sub _link2ensembl
{
    
    my ($self,@diseases)=@_;
    
    foreach my $dis (@diseases){ 
	foreach my $location($dis->each_Location){  
#	    foreach my $gene ($self->_ensdb->each_Gene){
#		foreach my $link ($gene->each_DBLink){
#		    if ($link->primary_id eq $location->external_gene)
#		    {
#			$location->ensembl_gene("ENSG ");
#		    }			    
#		}
#	    }
	}
    }
    
    return @diseases;
}



sub _link2maps
{

    my ($self,@diseases)=@_;

    foreach my $dis (@diseases){ 
	foreach my $location($dis->each_Location){
	    
	    # set global coordinates	
	    $location->global_position("555555 ");
	    
	}
    }
    
    return @diseases;

}





