
#
# BioPerl module for DB::Clone
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::Expression::Library

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


package Bio::EnsEMBL::ExternalData::Expression::Library;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::RootI

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



sub fetch_all_SeqTags {
    my ($self)=shift;

    return $self->adaptor->fetch_all_SeqTags($self->id);

}


sub fetch_all_SeqTags_above_frequency {
    my ($self,$frequency)=@_;

    return $self->adaptor->fetch_all_SeqTags_above_frequency($self->id,$frequency);


}


sub fetch_all_SeqTags_above_relative_frequency {
    my ($self,$frequency,$multiplier)=@_;


 return $self->adaptor->fetch_all_SeqTags_above_relative_frequency($self->id,$frequency,$multiplier);


}










=head2 id

 Title   : id
 Usage   : $obj->id($newval)
 Function: 
 Example : 
 Returns : value of id
 Args    : newvalue (optional)


=cut

sub id {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_library_id'} = $value;
    }
    return $obj->{'_library_id'};

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




=head2 cgap_id

 Title   : cgap_id
 Usage   : $obj->cgap_id($newval)
 Function: 
 Example : 
 Returns : value of cgap_id
 Args    : newvalue (optional)


=cut

sub cgap_id {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_cgap_id'} = $value;
    }
    return $obj->{'_cgap_id'};

}






=head2 dbest_id

 Title   : dbest_id
 Usage   : $obj->dbest_id($newval)
 Function: 
 Example : 
 Returns : value of dbest_id
 Args    : newvalue (optional)


=cut

sub dbest_id {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_dbest_id'} = $value;
    }
    return $obj->{'_dbest_id'};

}




=head2 name

 Title   : name
 Usage   : $obj->name($newval)
 Function: 
 Example : 
 Returns : value of name
 Args    : newvalue (optional)


=cut

sub name {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_name'} = $value;
    }
    return $obj->{'_name'};

}



=head2 tissue_type

 Title   : tissue_type
 Usage   : $obj->tissue_type($newval)
 Function: 
 Example : 
 Returns : value of tissue_type
 Args    : newvalue (optional)


=cut

sub tissue_type {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_tissue_type'} = $value;
    }
    return $obj->{'_tissue_type'};

}



=head2 description

 Title   : description
 Usage   : $obj->description($newval)
 Function: 
 Example : 
 Returns : value of tissue_type
 Args    : newvalue (optional)


=cut

sub description {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_description'} = $value;
    }
    return $obj->{'_description'};

}



=head2 total_seqtags

 Title   : total_seqtags
 Usage   : $obj->total_seqtags($newval)
 Function: 
 Example : 
 Returns : value of tissue_type
 Args    : newvalue (optional)


=cut

sub total_seqtags {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_total_seqtags'} = $value;
    }
    return $obj->{'_total_seqtags'};

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

    my ($library_id,$source,$cgap_id,$dbest_id,$name,$tissue_type,$description,$total_seqtags)=@args;

    $self->id($library_id);
    $self->source($source);
    $self->cgap_id($cgap_id);
    $self->dbest_id($dbest_id);
    $self->name($name);
    $self->tissue_type($tissue_type);
    $self->description($description);
    $self->total_seqtags($total_seqtags);


}







