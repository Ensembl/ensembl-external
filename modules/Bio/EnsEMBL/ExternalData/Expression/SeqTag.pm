
#
# BioPerl module for 
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::Expression::SeqTag

=head1 SYNOPSIS

    # $db is Bio::EnsEMBL::DB::Obj 

    @contig = $db->get_Contigs();

    $clone = $db->get_Clone();

    @genes    = $clone->get_all_Genes();

=head1 DESCRIPTION

Represents information on one Clone

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::ExternalData::Expression::SeqTag;
use vars qw(@ISA);
use strict;
use Bio::Root::RootI;

@ISA = qw(Bio::Root::RootI);


sub new {
    my ($class,$adaptor,@args) = @_;

    my $self = {};
    bless $self,$class;

    $self->adaptor($adaptor);
    $self->_set_from_args(@args);

    return $self;
   
}



=head2 seqtag_id

 Title   : seqtag_id
 Usage   : $obj->tissue_type($newval)
 Function: 
 Example : 
 Returns : value of tissue_type
 Args    : newvalue (optional)


=cut

sub id {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_id'} = $value;
    }
    return $obj->{'_id'};

}




=head2 source

 Title   : source
 Usage   : $obj->source($newval)
 Function: 
 Example : 
 Returns : value of source
 Args    : newvalue (optional)


=cut

sub source {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_source'} = $value;
    }
    return $obj->{'_source'};

}



=head2 name

 Title   : name
 Usage   : $obj->name($newval)
 Function: 
 Example : 
 Returns : value  of name
 Args    : newvalue (optional)


=cut

sub name {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_name'} = $value;
    }
    return $obj->{'_name'};

}




=head2 frequency

 Title   : frequency
 Usage   : $obj->frequency($newval)
 Function: 
 Example : 
 Returns : value  of frequency
 Args    : newvalue (optional)


=cut

sub frequency {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_frequency'} = $value;
    }
    return $obj->{'_frequency'};

}














=head2 adaptor

 Title   : adaptor
 Usage   : $obj->adaptor($newval)
 Function: 
 Example : 
 Returns : value of adaptor
 Args    : newvalue (optional)


=cut

sub adaptor {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'adaptor'} = $value;
    }
    return $obj->{'adaptor'};

}





sub _set_from_args {

    my ($self,@args)=@_;

    my ($library_id,$source,$name,$frequency)=@args;

    $self->id($library_id);
    $self->source($source);
    $self->name($name);
    $self->frequency($frequency);
    
}














