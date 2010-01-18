package Bio::EnsEMBL::ExternalData::CDSTrack::DBSQL::InterpretationAdaptor; 

use strict;
use Bio::EnsEMBL::Storable;
use Bio::EnsEMBL::ExternalData::CDSTrack::Interpretation;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::ExternalData::CDSTrack::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw( deprecate throw warning stack_trace_dump );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use vars '@ISA';
@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


sub _tables {
  my $self = shift;
  return (['Interpretations' , 'i'],['InterpretationSubtypes', 'isub']);
}

sub _columns {
  my $self = shift;
  return ( 'i.interpretation_uid', 'i.ccds_uid', 'i.group_uid', 'i.group_version_uid', 'i.accession_uid', 
  'i.parent_interpretation_uid', 'i.date_time', 'i.comment', 'i.val_description', 'i.char_val', 'i.integer_val', 
  'i.float_val', 'i.interpretation_type_uid', 'i.interpretation_subtype_uid', 'i.acc_rejection_uid', 'i.interpreter_uid', 
  'i.program_uid', 'i.reftrack_uid',  'isub.interpretation_subtype');
}

sub _left_join {
  return ( [ 'InterpretationSubtypes', "i.interpretation_subtype_uid = isub.interpretation_subtype_uid" ]);
}

sub fetch_by_dbID {
  my $self = shift;
  my $int_id = shift;
  
  throw("Require dbID for fetch_by_dbID")
         unless ($int_id);
  
  my $constraint = "i.interpretation_uid = '$int_id'";
  my ($int_obj) = @{ $self->generic_fetch($constraint) };
  
  return $int_obj;
}

sub fetch_all_by_GroupVersion_and_CcdsID {
  my $self = shift;
  my $gv = shift;
  my $ccds_uid = shift;
  my @interpretations;

  if (!ref $gv || !$gv->isa('Bio::EnsEMBL::ExternalData::CDSTrack::GroupVersion') ) {
    throw("Must provide a Bio::EnsEMBL::ExternalData::CDSTrack::GroupVersion object");
  }

  print STDERR "Fetching interpretations for ccds_uid ".$ccds_uid.", group_version_uid ".$gv->dbID."\n";
  my $group_version_uid = $gv->dbID;
  if (!$ccds_uid || !$group_version_uid) { 
    throw("Need ccds_uid and group_version_uid");
  }

  my $sql = "SELECT i.interpretation_uid ".
            "FROM Interpretations i, GroupVersions gv ".
            "WHERE i.group_version_uid = $group_version_uid ".
            "AND i.ccds_uid = $ccds_uid ".
            "AND i.group_version_uid = gv.group_version_uid";
  
  print "SQL: $sql\n";
  my $sth = $self->prepare($sql);
  $sth->execute();

  while ( my $id = $sth->fetchrow()) {
    print "$id, ";
    push @interpretations, $self->fetch_by_dbID($id);
  }
  print "\ngot ".scalar(@interpretations)." interpretations\n";
  return \@interpretations;
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  my @out;
  my ($dbid, $ccds_id, $group_id, $group_version_id, $accession_id); 
  my ($parent_interpretation_id, $date_time, $comment, $val_description, $char_val, $integer_val);
  my ($float_val, $interpretation_type_id, $interpretation_subtype_id, $acc_rejection_id, $interpreter_id);
  my ($program_id, $reftrack_id, $interpretation_subtype);
  
  $sth->bind_columns( \$dbid, \$ccds_id, \$group_id, \$group_version_id, \$accession_id, 
  \$parent_interpretation_id, \$date_time, \$comment, \$val_description, \$char_val, \$integer_val, 
  \$float_val, \$interpretation_type_id, \$interpretation_subtype_id, \$acc_rejection_id, \$interpreter_id,
  \$program_id, \$reftrack_id, \$interpretation_subtype); 


  while($sth->fetch()) {
    
    push @out, Bio::EnsEMBL::ExternalData::CDSTrack::Interpretation->new(
              -dbID                      => $dbid,
              -ccds_id                   => $ccds_id,
              -group_id                  => $group_id,
              -group_version_id          => $group_version_id,
              -accession_id              => $accession_id,
              -parent_interpretation_id  => $parent_interpretation_id,
              -date_time                 => $date_time,
              -comment                   => $comment,
              -val_description           => $val_description,
              -char_val                  => $char_val,
              -integer_val               => $integer_val,
              -float_val                 => $float_val,
              -interpretation_type_id    => $interpretation_type_id,
              -interpretation_subtype_id => $interpretation_subtype_id,
              -acc_rejection_id          => $acc_rejection_id,
              -interpreter_id            => $interpreter_id,
              -program_id                => $program_id,
              -reftrack_id               => $reftrack_id,
              -interpretation_subtype    => $interpretation_subtype,
              -adaptor                   => $self 
    );
  
    
  }
  return \@out;
}


1;
