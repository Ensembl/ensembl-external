package Bio::EnsEMBL::ExternalData::Disease::Disease; 

use strict;
use Bio::Root::RootI;
use vars qw(@ISA);

@ISA = qw(Bio::Root::RootI);



sub new 
{
    my($class,@locations) = @_;
    my $self = bless {}, $class;
         
    $self->{'_disease_location_array'} = [];
    
    foreach my $location (@locations){$self->add_location($location);}

    return $self; 
}


sub name
{
    my ($self,$value)=@_;

  if( defined $value) {$self->{'name'} = $value;}  
  return $self->{'name'};
}




sub add_Location 
{                          
 my ($self,$location)=@_;

 if( ! $location->isa("Bio::EnsEMBL::ExternalData::Disease::DiseaseLocation") ) {
       $self->throw("$location is not a Bio::EnsEMBL::Disease::DiseaseLocation!");
   }

   push(@{$self->{'_disease_location_array'}},$location);

}

sub each_Location{
   my ($self) = @_;

   return @{$self->{'_disease_location_array'}};
}








