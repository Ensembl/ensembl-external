
#
# BioPerl module for Bio::EnsEMBL::ExternalData::Expression::ExpressionAdaptor
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::Expression::ExpressionAdaptor

=head1 SYNOPSIS

    # $db is Bio::EnsEMBL::DB::Obj 

    my $da= Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor->new($obj);
    my $clone=$da->fetch($id);

    @contig = $clone->get_all_Contigs();
    @genes    = $clone->get_all_Genes();

=head1 DESCRIPTION

Represents information on one Clone

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor;
use Bio::EnsEMBL::ExternalData::BaseAdaptor;
use Bio::EnsEMBL::ExternalData::Expression::SeqTag;
use vars qw(@ISA);
use strict;

@ISA = qw(Bio::EnsEMBL::ExternalData::BaseAdaptor);





sub fetch_all {
    my ($self)=shift;

    my $dbname=$self->dbname;
    my $statement="select seqtag_id,source,cgap_id,name 
                   from   $dbname.seqtag";

    return $self->_fetch($statement);   

}



sub fetch_by_dbID {

    my ($self,$id)=@_;
}



sub fetch_by_Library_dbID 
{
    my ($self,$id)=@_;

    $self->throw("need a library id") unless defined $id;

    my $dbname=$self->dbname;

    my $statement="select s.seqtag_id,s.source,s.name 
                   from   $dbname.seqtag s,$dbname.frequency f
                   where  s.seqtag_id=f.seqtag_id and f.library_id='$id'";

    return $self->_fetch($statement);  


}



sub fetch_by_Library_dbID_above_frequency {
    my ($self,$id,$frequency)=@_;

    $self->throw("need a library id") unless defined $id;
    $self->throw("need a frequency value") unless defined $frequency;

    my $dbname=$self->dbname;


    my $statement="select s.seqtag_id,s.source,s.name,f.frequency  
                   from   $dbname.seqtag s,$dbname.frequency f
                   where  s.seqtag_id=f.seqtag_id 
                   and    f.library_id='$id' and f.frequency>$frequency";


    return $self->_fetch_with_frequency($statement);  


}




sub fetch_by_Library_dbID_above_relative_frequency {
    my ($self,$id,$frequency,$multiplier)=@_;

    $self->throw("need a library id") unless defined $id;
    $self->throw("need a frequency value") unless defined $frequency;
    $multiplier=1000000 unless defined $multiplier;

    my $dbname=$self->dbname;
    my $statement="select   s.seqtag_id,s.source,s.name,
                            ceiling((f.frequency*$multiplier/l.total_seqtags) -1) as frequency
                   from     $dbname.seqtag s,$dbname.frequency f,$dbname.library l 
                   where    s.seqtag_id=f.seqtag_id                                    
                   and      l.library_id=f.library_id 
                   and      f.library_id='$id' and frequency>$frequency
                   order by frequency";


    return $self->_fetch_with_frequency($statement);  

}


sub fetch_by_Library_Name 
{
    my ($self,$id)=@_;
}


sub fetch_by_LibraryList_dbIDs 
{
    my ($self,@ids)=@_;
}



sub fetch_by_LibraryList_Name 
{
    my ($self,@ids)=@_;
}





=head2 dbaname

 Title   : dbname
 Usage   : $obj->dbname($newval)
 Function: 
 Example : 
 Returns : value of dbname
 Args    : newvalue (optional)


=cut

sub dbname {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_dbname'} = $value;
    }
    return $obj->{'_dbname'};

}





sub _fetch {

    my ($self,$statement)=@_;

    my @tags;
    my $sth = $self->prepare($statement);    
    $sth->execute();
    
    my ($library_id,$source,$name);

    $sth->bind_columns(undef,\$library_id,\$source,\$name);

    while ($sth->fetch){	
	my @args=($library_id,$source,$name);	
	push @tags,Bio::EnsEMBL::ExternalData::Expression::SeqTag->new($self,@args);
    }
    
    return @tags;
    
}



sub _fetch_with_frequency {

    my ($self,$statement)=@_;

    my @tags;
    my $sth = $self->prepare($statement);    
    $sth->execute();
    
    my ($library_id,$source,$name,$frequency);

    $sth->bind_columns(undef,\$library_id,\$source,\$name,\$frequency);

    while ($sth->fetch){	
	my @args=($library_id,$source,$name,$frequency);	
	push @tags,Bio::EnsEMBL::ExternalData::Expression::SeqTag->new($self,@args);
    }
    
    return @tags;
    
}



















