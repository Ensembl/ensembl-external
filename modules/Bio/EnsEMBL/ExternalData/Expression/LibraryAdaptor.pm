#
# EnsEMBL module for Bio::EnsEMBL::ExternalData::Expression::ExpressionAdaptor
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::Expression::LibraryAdaptor

=head1 SYNOPSIS

    # $db is Bio::EnsEMBL::DB::Obj 

    my $da= Bio::EnsEMBL::ExternalData::Expression::LibraryAdaptor->new($obj);
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







package Bio::EnsEMBL::ExternalData::Expression::LibraryAdaptor;
use Bio::EnsEMBL::ExternalData::BaseAdaptor;
use Bio::EnsEMBL::ExternalData::Expression::Library;
use Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor;
use vars qw(@ISA);
use strict;

@ISA = qw(Bio::EnsEMBL::ExternalData::BaseAdaptor);

# new in Bio::EnsEMBL::ExternalData::BaseAdaptor


sub fetch_all {
    my ($self)=shift;

    my $dbname=$self->dbname;
    my $statement="select library_id,source,cgap_id,
                          dbest_id,name,
                          tissue_type,description,total_seqtags
                   from   $dbname.library";

    return $self->_fetch($statement);   

}



sub fetch_by_SeqTag_Name {

    my ($self,$name)=@_;

    $self->throw("need a seqtag name") unless $name; 

    my $dbname=$self->dbname;
    my $statement="select l.library_id,l.source,l.cgap_id,
                          l.dbest_id,l.name,
                          l.tissue_type,l.description,l.total_seqtags
                   from   $dbname.library l,$dbname.seqtag s,$dbname.frequency f 
                   where  l.library_id=f.library_id 
                   and    f.seqtag_id=s.seqtag_id 
                   and    s.name='$name'"; 
            
    return $self->_fetch($statement); 

}



sub fetch_by_SeqTag_Synonym {

    my ($self,$name)=@_;

    $self->throw("need a seqtag name") unless $name; 

    my $dbname=$self->dbname;
    my $statement="select l.library_id,l.source,l.cgap_id,
                          l.dbest_id,l.name,
                          l.tissue_type,l.description,l.total_seqtags
                   from   $dbname.library l,$dbname.seqtag_alias a,$dbname.frequency f 
                   where  l.library_id=f.library_id 
                   and    f.seqtag_id=a.seqtag_id
                   and    a.external_name='$name'"; 
            
    return $self->_fetch($statement); 


}



sub fetch_by_SeqTagList {

    my ($self,@genes)=@_;

}


sub fetch_by_SeqTag_SynonymList {

    my ($self,@transcripts)=@_;

}




sub fetch_all_SeqTags {
    my ($self,$id)=@_;

    $self->throw("need a library id") unless $id; 

    my $seqtag_ad=Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor->new($self->db);
    $seqtag_ad->dbname($self->dbname);
    return $seqtag_ad->fetch_by_Library_dbID($id);

}



sub fetch_all_SeqTags_above_frequency {
    my ($self,$id,$frequency)=@_;

    $self->throw("need a library id") unless $id; 
    $self->throw("need a frequency value") unless $frequency;

    my $seqtag_ad=Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor->new($self->db);
    $seqtag_ad->dbname($self->dbname);
    return $seqtag_ad->fetch_by_Library_dbID_above_frequency($id,$frequency);

}

sub fetch_all_SeqTags_above_relative_frequency {
    my ($self,$id,$frequency)=@_;

    $self->throw("need a library id") unless $id; 
    $self->throw("need a frequency value") unless $frequency;

    my $seqtag_ad=Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor->new($self->db);
    $seqtag_ad->dbname($self->dbname);
    return $seqtag_ad->fetch_by_Library_dbID_above_relative_frequency($id,$frequency);

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

    my @libs;
    my $sth = $self->prepare($statement);    
    $sth->execute();
    
    my ($library_id,$source,$cgap_id,$dbest_id,
	$name,$tissue_type,$description, $total_seqtags);

    $sth->bind_columns(undef,\$library_id,\$source,\$cgap_id,\$dbest_id,
		   \$name,\$tissue_type,\$description,\$total_seqtags);

    while ($sth->fetch){	
	my @args=($library_id,$source,$cgap_id,$dbest_id,$name,$tissue_type,$description,$total_seqtags);	
	push @libs,Bio::EnsEMBL::ExternalData::Expression::Library->new($self,@args);
    }
    
    return @libs;
    
}












































