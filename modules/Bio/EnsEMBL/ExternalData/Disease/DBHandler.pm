#
# BioPerl module for Bio::EnsEMBL::ExternalData::Disease::DBHandler
#
# Written by Arek Kasprzyk <arek@ebi.ac.uk>
#
# You may distribute this module under the same terms as perl itself
# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::Disease::DBHandler 

=head1 SYNOPSIS


my $diseasedb = new Bio::EnsEMBL::ExternalData::Disease::DBHandler( -user => 'ensembl', 
						      -dbname => 'disease',
						      -host=>'sol28.ebi.ac.uk',
						      -ensdb=>$ensembldb,
						      -mapdb=>$mapdb);



my @diseases=$diseasedb->diseases_on_chromosome(22);
my @diseases=$diseasedb->diseases_without_genes;
my @diseases=$diseasedb->all_diseases;
my $disease =$diseasedb->disease_by_name("DiGeorge syndrome (2)");
my @diseases=$diseasedb->diseases_like("corneal");


=head1 DESCRIPTION

This object represents a disease database consisting of disease phenotype descriptions, 
chromosomal locations and/or associated genes from OMIM morbid map and 
Mitelman Catalogoue of Chromosome Abnormalities. 
In additon, when database representations of ensembl and map databases are set, 
it will provide a 'translation' of OMIM and Mitelman genes to ensembl gene predictions 
and their localization in local and global coordinates.   


=head1 AUTHOR - Arek Kasprzyk

Email arek@ebi.ac.uk

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::ExternalData::Disease::DBHandler; 


use strict;
use DBI;
use Bio::Root::RootI;
use Bio::EnsEMBL::ExternalData::Disease::Disease;
use Bio::EnsEMBL::ExternalData::Disease::DiseaseLocation;
use vars qw(@ISA);

@ISA = qw(Bio::Root::RootI);



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



=head2 all diseases

 Title   : all_diseases
 Usage   : my @diseases=$diseasedb->all_diseases;
 Function: gets all diseases from the database
 Example :
 Returns : an array of Bio::EnsEMBL::ExternalData::Disease::Disease objects
 Args    :


=cut







sub all_diseases 
{
    my ($self)=@_;

    my $query_string='select d.disease,g.id,g.gene_symbol,g.omim_id,g.start_cyto,g.end_cyto, 
                      g.chromosome from disease as d,gene as g where d.id = g.id';

    return $self->_get_diseases($query_string);

} 
                         

=head2 diseases on chromosome

 Title   : diseases_on_chromosome
 Usage   : my @diseases=$diseasedb->diseases_on_chromosome(22);
 Function: gets all diseases for a given chromosome
 Example :
 Returns : an array of Bio::EnsEMBL::ExternalData::Disease::Disease objects
 Args    :


=cut



sub diseases_on_chromosome 
{                          
    my ($self,$chromosome_no)=@_;

    $chromosome_no || $self->throw("I need chromosome number");
    
    my $query_string= "select d.disease,g.id,g.gene_symbol,g.omim_id,g.start_cyto,g.end_cyto, 
                       g.chromosome from disease as d,gene as g where d.id = g.id 
                       and g.chromosome='$chromosome_no'";

    return $self->_get_diseases($query_string);
       
}



=head2 diseases with genes

 Title   : diseases_with_genes
 Usage   : my @diseases=$diseasedb->diseases_with_genes;
 Function: gets all diseases associated with genes
 Example :
 Returns : an array of Bio::EnsEMBL::ExternalData::Disease::Disease objects
 Args    :


=cut


                          

sub diseases_with_genes 
    
{
    my ($self)=@_;

    my $query_string= "select d.disease,g.id,g.gene_symbol,g.omim_id,g.start_cyto,g.end_cyto, 
                       g.chromosome from disease as d,gene as g where d.id = g.id 
                       and g.gene_symbol IS NOT NULL";

    return $self->_get_diseases($query_string);


} 




=head2 diseases without genes

 Title   : diseases_without_genes
 Usage   : my @diseases=$diseasedb->diseases_without_genes;
 Function: gets all diseases which have no gene info in the database
 Example :
 Returns : an array of Bio::EnsEMBL::ExternalData::Disease::Disease objects
 Args    :


=cut





sub diseases_without_genes 
{
    my ($self)=@_;

    my $query_string= "select d.disease,g.id,g.gene_symbol,g.omim_id,g.start_cyto,g.end_cyto, 
                       g.chromosome from disease as d,gene as g where d.id = g.id 
                       and g.gene_symbol IS NULL";


    return $self->_get_diseases($query_string);


} 



=head2 disease by name

 Title   : disease_by_name
 Usage   : my $disease=$diseasedb->disease_by_name("DiGeorge syndrome (2)");
 Function: gets disease by name
 Example :
 Returns : Bio::EnsEMBL::ExternalData::Disease::Disease object
 Args    :


=cut



                     
sub disease_by_name
{                          
    my ($self,$disease_name)=@_;

 my $query_string= "select d.disease,g.id,g.gene_symbol,g.omim_id,g.start_cyto,g.end_cyto,
                    g.chromosome from disease as d,gene as g where d.id = g.id 
                    and d.disease='$disease_name'";

    return $self->_get_diseases($query_string);

}





=head2 diseases like

 Title   : diseases_like
 Usage   : my @diseases=$diseasedb->diseases_like("leukemia");
 Function: gets diseases with a name containing given string
 Example :
 Returns : an array of Bio::EnsEMBL::ExternalData::Disease::Disease objects
 Args    :


=cut





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
my $disease;

while ( my $rowhash = $sth->fetchrow_hashref) 
{
 
    if ($id!=$rowhash->{'id'})
    {	
	$disease=new Bio::EnsEMBL::ExternalData::Disease::Disease;
	$disease->name($rowhash->{'disease'});
	push @diseases,$disease;
    }

    my $location=new Bio::EnsEMBL::ExternalData::Disease::DiseaseLocation(
							    -db_id=>$rowhash->{'omim_id'},
							    -cyto_start=>$rowhash->{'start_cyto'},
							    -cyto_end=>$rowhash->{'end_cyto'},
							    -external_gene=>$rowhash->{'gene_symbol'},
							    -chromosome=>$rowhash->{'chromosome'});
  
    if (defined $rowhash->{'gene_symbol'}){$location->has_gene(1);}
    $id=$rowhash->{'id'};

    $disease->add_Location($location);   
}



if (defined $self->_ensdb){@diseases=$self->_link2ensembl(@diseases);}
if (defined $self->_mapdb){@diseases=$self->_link2maps(@diseases);}


return @diseases;


}


                       

sub _link2ensembl
{
    
    my ($self,@diseases)=@_;
    
    foreach my $dis (@diseases){ 
	foreach my $location($dis->each_Location){ 

	    my $ensembl_gene=$self->_ensdb->get_Gene_by_DBLink ($location->external_gene); 
	    $location->ensembl_gene($ensembl_gene);
	}
    }
    
    return @diseases;
}



sub _link2maps
{

    my ($self,@diseases)=@_;

    foreach my $dis (@diseases){ 
	foreach my $location($dis->each_Location){
	    
	    # do sth with a map obj and set global coordinates	
	    $location->global_position("555555 ");	    
	}
    }
    
    return @diseases;

}


sub _db_handle 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_db_handle'} = $value;}
  
  return $self->{'_db_handle'};
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











