package Bio::EnsEMBL::ExternalData::Disease::DiseaseLocation; 


use strict;
use Bio::Root::RootI;
use vars qw(@ISA);

@ISA = qw(Bio::Root::RootI);



sub new 
{
    my($class,@args) = @_;
    my $self = bless {}, $class;
    
    my ($db_id,$cyto_start,$cyto_end,$gene_id,$chromosome) = 
      $self->_rearrange([qw(
			    DB_ID
			    CYTO_START
			    CYTO_END
			    EXTERNAL_GENE
			    CHROMOSOME
			    )],@args);
    
   # $db_id  || $self->throw("I need external db id");
   # $cyto_start  || $self->throw("I need cytogenetic position ");
   # $cyto_end  || $self->throw("I need cytogenetic position");

    $self->db_id($db_id);
    $self->cyto_start($cyto_start);  
    $self->cyto_start($cyto_end);
    if (defined $chromosome){$self->chromosome($chromosome);}
    if (defined $gene_id){$self->external_gene($gene_id);}
   	   
  
    
    return $self; 
}



sub db_id 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_db_id'} = $value;}
  
  return $self->{'_db_id'};
}



sub has_gene 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_has_gene'} = $value;}
  
  return $self->{'_has_gene'};
}



sub external_gene 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_gene_id'} = $value;}
  
  return $self->{'_gene_id'};
}

sub ensembl_gene 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'ensembl_gene'} = $value;}
  
  return $self->{'ensembl_gene'};
}


sub DB_link 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'DB_link'} = $value;}
  
  return $self->{'DB_link'};
}

sub cyto_start 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_cyto_start'} = $value;}
  
  return $self->{'_cyto_start'};
}

sub cyto_end 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'_cyto_end'} = $value;}
  
  return $self->{'_cyto_end'};
}

sub chromosome 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'chromosome'} = $value;}
  
  return $self->{'chromosome'};
}


sub global_position 
{
  my ($self,$value) = @_;
  if( defined $value) {$self->{'global_position'} = $value;}
  
  return $self->{'global_position'};
}



