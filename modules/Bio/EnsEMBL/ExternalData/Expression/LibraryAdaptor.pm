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

    my $dbname='expression';
    my $lib_ad=Bio::EnsEMBL::ExternalData::Expression::LibraryAdaptor->new($obj);
    $lib_ad->dbname($dbname);

    my @libs=$lib_ad->fetch_by_SeqTag_Synonym("ENSG00000080561"); 

    my @tgs=("AAAAAAAAAA","AAAAAAAAAC");
    my @libs=$lib_ad->fetch_by_SeqTagList(@tgs);



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




=head2 fetch_all

 Title   : fetch_all
 Usage   : $obj->fetch_all
 Function: 
 Example : 
 Returns : array of library objects
 Args    : 


=cut




sub fetch_all {
    my ($self)=shift;

    my $dbname=$self->dbname;
    my $statement="select library_id,source,cgap_id,
                          dbest_id,name,
                          tissue_type,description,total_seqtags
                   from   $dbname.library";

    return $self->_fetch($statement);   

}


=head2 fetch_by_SeqTag_Name

 Title   : fetch_by_SeqTag_Name
 Usage   : $obj->fetch_by_SeqTag_Name
 Function: 
 Example : 
 Returns : array of library objects
 Args    : seqtag name


=cut



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



=head2 fetch_by_SeqTag_Synonym

 Title   : fetch_by_SeqTag_Synonym
 Usage   : $obj->fetch_by_SeqTag_Synonym
 Function: 
 Example : 
 Returns : array of library objects
 Args    : seqtag synonym


=cut





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



=head2 fetch_by_SeqTag_Synonym_above_relative_frequency

 Title   : fetch_by_SeqTag_Synonym_above_relative_frequency
 Usage   : $obj->fetch_by_SeqTag_Synonym_above_reltive_frequency
 Function: 
 Example : 
 Returns : array of library objects
 Args    : seqtag synonym


=cut


sub fetch_by_SeqTag_Synonym_above_relative_frequency {

    my ($self,$name,$frequency)=@_;

    $self->throw("need a seqtag name") unless $name; 
    $self->throw("need a seqtag frequency") unless $frequency; 

    my $dbname=$self->dbname;
    my $multiplier=$self->multiplier; 

    my $statement="select l.library_id,l.source,l.cgap_id,
                          l.dbest_id,l.name,
                          l.tissue_type,l.description,l.total_seqtags
                   from   $dbname.library l,$dbname.seqtag_alias a,$dbname.frequency f 
                   where  l.library_id=f.library_id 
                   and    f.seqtag_id=a.seqtag_id
                   and    ceiling((f.frequency*$multiplier/l.total_seqtags) -1)>$frequency 
                   and    a.external_name='$name'"; 
            
    return $self->_fetch($statement); 


}






=head2 fetch_by_SeqTag_Synonym_above_relative_frequency

 Title   : fetch_by_SeqTag_Synonym_above_relative_frequency
 Usage   : $obj->fetch_by_SeqTag_Synonym_above_reltive_frequency
 Function: 
 Example : 
 Returns : array of library objects
 Args    : seqtag synonym


=cut


sub fetch_by_SeqTag_Synonym_below_relative_frequency {

    my ($self,$name,$frequency)=@_;

    $self->throw("need a seqtag name") unless $name; 
    $self->throw("need a seqtag frequency") unless $frequency; 

    my $dbname=$self->dbname;
    my $multiplier=$self->multiplier; 

    my $statement="select l.library_id,l.source,l.cgap_id,
                          l.dbest_id,l.name,
                          l.tissue_type,l.description,l.total_seqtags
                   from   $dbname.library l,$dbname.seqtag_alias a,$dbname.frequency f 
                   where  l.library_id=f.library_id 
                   and    f.seqtag_id=a.seqtag_id
                   and    ceiling((f.frequency*$multiplier/l.total_seqtags) -1)<$frequency 
                   and    a.external_name='$name'"; 
            
    return $self->_fetch($statement); 


}





=head2 fetch_by_SeqTagList

 Title   : fetch_by_SeqTagList
 Usage   : $obj->fetch_by_SeqTagList
 Function: 
 Example : 
 Returns : array of library objects
 Args    : array of seqtag names


=cut




sub fetch_by_SeqTagList {

    my ($self,@seqtags)=@_;

    $self->throw("need a seqtag name") unless  @seqtags && $#seqtags>=0; 

    my $list=$self->_prepare_list(@seqtags);
    my $dbname=$self->dbname;
    my $statement="select l.library_id,l.source,l.cgap_id,
                          l.dbest_id,l.name,
                          l.tissue_type,l.description,l.total_seqtags
                   from   $dbname.library l,$dbname.seqtag s,$dbname.frequency f 
                   where  l.library_id=f.library_id 
                   and    f.seqtag_id=s.seqtag_id 
                   and    s.name in $list"; 
    
    print "$statement\n";

    return $self->_fetch($statement); 
    
    
}




=head2 fetch_by_SeqTag_SynonymList

 Title   : fetch_by_SeqTag_SynonymList
 Usage   : $obj->fetch_by_SeqTag_SynonymList
 Function: 
 Example : 
 Returns : array of library objects
 Args    : array of seqtag synonyms


=cut





sub fetch_by_SeqTag_SynonymList {

    my ($self,@seqtags)=@_;

    $self->throw("need a seqtag name") unless  @seqtags && $#seqtags>=0; 

    my $list=$self->_prepare_list(@seqtags);
    my $dbname=$self->dbname;
    my $statement="select l.library_id,l.source,l.cgap_id,
                          l.dbest_id,l.name,
                          l.tissue_type,l.description,l.total_seqtags
                   from   $dbname.library l,$dbname.seqtag_alias a,$dbname.frequency f 
                   where  l.library_id=f.library_id 
                   and    f.seqtag_id=a.seqtag_id
                   and    a.external_name in $list"; 
            
    return $self->_fetch($statement); 
}



=head2 fetch_SeqTag_by_dbID

 Title   : fetch_SeqTag_by_dbID
 Usage   : $obj->fetch_SeqTag_by_dbID
 Function: 
 Example : 
 Returns : seqtag object
 Args    :


=cut


sub fetch_SeqTag_by_dbID {
    my ($self,$id)=@_;

    $self->throw("need a seqtag id") unless $id; 

    my $seqtag_ad=Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor->new($self->db);
    $seqtag_ad->dbname($self->dbname);
    
    my $seqtag=$seqtag_ad->fetch_by_dbID($id);
    if (defined $seqtag){
	return $seqtag;
    }else{
	return;
    }
}


=head2 fetch_SeqTag_by_dbID

 Title   : fetch_SeqTag_by_dbID
 Usage   : $obj->fetch_SeqTag_by_dbID
 Function: 
 Example : 
 Returns : seqtag object
 Args    :


=cut


sub fetch_SeqTag_by_dbID {
    my ($self,$library_id,$id)=@_;

    $self->throw("need a library id") unless $library_id; 
    $self->throw("need a seqtag id") unless $id; 

    my $seqtag_ad=Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor->new($self->db);
    $seqtag_ad->dbname($self->dbname);
    
    my $seqtag=$seqtag_ad->fetch_by_dbID($library_id,$id);
    if (defined $seqtag){
	return $seqtag;
    }else{
	return;
    }
}


=head2 fetch_SeqTag_by_Synonym

 Title   : fetch_SeqTag_by_Synonym
 Usage   : $obj->fetch_SeqTag_by_Synonym
 Function: 
 Example : 
 Returns : seqtag object
 Args    :


=cut


sub fetch_SeqTag_by_Synonym {
    my ($self,$library_id,$synonym)=@_;
    
    $self->throw("need a library id") unless $library_id; 
    $self->throw("need a seqtag synonym") unless $synonym; 

    my $seqtag_ad=Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor->new($self->db);
    $seqtag_ad->dbname($self->dbname);
    
    return $seqtag_ad->fetch_by_Synonym($library_id,$synonym);
   
}












=head2 fetch_all_SeqTags

 Title   : fetch_all_SeqTags
 Usage   : $obj->fetch_all_SeqTags
 Function: 
 Example : 
 Returns : array of seqtags objects
 Args    :


=cut


sub fetch_all_SeqTags {
    my ($self,$id)=@_;

    $self->throw("need a library id") unless $id; 

    my $seqtag_ad=Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor->new($self->db);
    $seqtag_ad->dbname($self->dbname);
    return $seqtag_ad->fetch_by_Library_dbID($id);

}



=head2 fetch_all_SeqTags_above_frequency

 Title   : fetch_all_SeqTags_above_frequency
 Usage   : $obj->fetch_all_SeqTags_above_frequency
 Function: returns seqtags with expression above given level 
 Example : 
 Returns : array of seqtags objects
 Args    :


=cut





sub fetch_all_SeqTags_above_frequency {
    my ($self,$id,$frequency)=@_;

    $self->throw("need a library id") unless $id; 
    $self->throw("need a frequency value") unless $frequency;

    my $seqtag_ad=Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor->new($self->db);
    $seqtag_ad->dbname($self->dbname);
    return $seqtag_ad->fetch_by_Library_dbID_above_frequency($id,$frequency);

}




=head2 fetch_all_SeqTags_above_relative_frequency

 Title   : fetch_all_SeqTags_above_relative_frequency
 Usage   : $obj->fetch_all_SeqTags_above_realtive_frequency
 Function: returns seqtags with expression above given level 
 Example : 
 Returns : array of seqtags objects
 Args    :


=cut



sub fetch_all_SeqTags_above_relative_frequency {
    my ($self,$id,$frequency)=@_;

    $self->throw("need a library id") unless $id; 
    $self->throw("need a frequency value") unless $frequency;

    my $seqtag_ad=Bio::EnsEMBL::ExternalData::Expression::SeqTagAdaptor->new($self->db);
    $seqtag_ad->dbname($self->dbname);
    return $seqtag_ad->fetch_by_Library_dbID_above_relative_frequency($id,$frequency);

}




=head2 dbname

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



=head2 multiplier

 Title   : multiplier
 Usage   : $obj->multiplier($newval)
 Function: 
 Example : 
 Returns : value of multiplier
 Args    : newvalue (optional)


=cut

sub multiplier {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_multiplier'} = $value;
  } elsif (!defined$obj->{'_multiplier'})  {
      $obj->{'_multiplier'}=1000000;
  }
    return $obj->{'_multiplier'};
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




sub _prepare_list {
    my ($self,@ids)=@_;
    
    my $string;
    foreach my $id(@ids){
	$string .= $id . "\',\'"; 
    }

    $string="\'".$string;
       
    chop $string;
    chop $string;

    if ($string) { $string = "($string)";} 

    return $string;
    
}








































