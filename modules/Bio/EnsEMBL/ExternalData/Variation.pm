
#
# BioPerl module for Bio::EnsEMBL::ExternalData::Variation
#
# Cared for by Heikki Lehvaslaiho <heikki@ebi.ac.uk>
#
# Copyright Heikki Lehvaslaiho
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::Variation - Variation SeqFeature

=head1 SYNOPSIS

    $feat = new Bio::EnsEMBL::ExternalData::Variation
                (-start => 10, -end => 10,
		 -strand => 1,
		 -source => 'The SNP Consortium',
		 -score  => 99,           #new meaning
		 -status = > 'suspected', #new
		 -alleles => 't|c'        #new
		 );

   # add it to an annotated sequence

   $annseq->add_SeqFeature($feat);



=head1 DESCRIPTION

Bio::EnsEMBL::ExternalData::Variation redifines and extends
L<Bio::SeqFeature::Generic> for (genomic) sequence variations.

Attribute 'source' is used to give the source database string.
Attribute 'score' is used to give the code number for uniquesness of
the SNP. Lower values are better. 1 is best.  'status' has two values:
'suspected' or 'proven'. 'alleles' lists all known, typically two,
allelic variants in the given position.

This class has methods to store and return database cross references
(L<Bio::Annotation::DBLink>).

This class is designed to provide light weight objects for sequence
annotation. Classes implementing L<Bio::Variation::SeqChangeI> interface
facilitate full description of mutation events at DNA, RNA and AA
levels. A collection of SeqChangeI compliant objects can be linked together by
L<Bio::Variation::Haplotype> or L<Bio::Variation::Genotype>objects.

The attibute 'primary_tag' is set to "Variation" by the
constructor. It is recommended that it is not changed although
inherited method primary_tag can be used.

=head1 CONTACT

Heikki Lehvaslaiho <heikki@ebi.ac.uk>

Address:

     EMBL Outstation, European Bioinformatics Institute
     Wellcome Trust Genome Campus, Hinxton
     Cambs. CB10 1SD, United Kingdom

=cut

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::ExternalData::Variation;
use vars qw(@ISA);
use strict;

# Object preamble - inheritance

use Bio::SeqFeature::Generic;
use Bio::DBLinkContainerI;
use Bio::Annotation::DBLink;

@ISA = qw(Bio::SeqFeature::Generic  Bio::DBLinkContainerI);

sub new {
    my($class,@args) = @_;
    my $self;
    $self = {};
    bless $self, $class;

    my ($start, $end, $strand, $primary_tag, $source,
	$frame, $score, $gff_string, $status, $alleles,
	$upstreamseq, $dnstreamseq) =
	    $self->_rearrange([qw(START
				  END
				  STRAND
				  PRIMARY_TAG
				  SOURCE
				  FRAME
				  SCORE
				  GFF_STRING
				  STATUS
				  ALLELES
				  UPSTREAMSEQ
				  DNSTREAMSEQ
				)],@args);

    $self->primary_tag("Variation");

    $start && $self->SUPER::start($start);
    $end   && $self->SUPER::end($end);
    $start && $self->start_in_clone_coord($start);
    $end   && $self->end_in_clone_coord($end);
    $strand && $self->SUPER::strand($strand);
    $primary_tag && $self->SUPER::primary_tag($primary_tag);
    $source  && $self->SUPER::source_tag($source);
    $frame   && $self->SUPER::frame($frame);
    $score   && $self->SUPER::score($score);
    $gff_string && $self->SUPER::_from_gff_string($gff_string);
    $status  && $self->status($status);
    $alleles && $self->alleles($alleles);
    $upstreamseq  && $self->upStreamSeq($upstreamseq);
    $dnstreamseq  && $self->dnStreamSeq($dnstreamseq);

    $self->{ 'link' } = [];

    # set stuff in self from @args
    return $self; # success - we hope!
}



=head2 id

 Title   : id
 Usage   : $obj->id
 Function:

           Read only method. Returns the id of the variation object.
           The id is derived from the first DBLink object attached to
           this object.

 Example :
 Returns : scalar
 Args    : none

=cut


sub id {
    my ($obj) = @_;

    my @ids = $obj->each_DBLink;
    my $id = $ids[0];
    return  $id->primary_id;
}

=head2 clone_name

 Title   : clone_name
 Usage   : $obj->clone_name
 Function:

           Read only method.

 Example :
 Returns : scalar
 Args    : none

=cut

sub clone_name {
    my ($obj) = @_;

    my @names = $obj->each_DBLink;
    my $name = $names[0];
    return  $name->optional_id;
}

=head2 start_in_clone_coord

 Title   : start_in_clone_coord
 Usage   : $obj->start_in_clone_coord();
 Function:

            Sets and returns the start in the original coordinate
            system The start attribute will be reset to other
            cooerdiante systems. If value is not set, returns undef.

 Example :
 Returns : integer or undef
 Args    : integer

=cut

sub start_in_clone_coord {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'start_in_clone_coord'} = $value;
    }
   if( ! exists $obj->{'start_in_clone_coord'} ) {
       return undef;
   }
   return $obj->{'start_in_clone_coord'};

}

=head2 end_in_clone_coord

 Title   : end_in_clone_coord
 Usage   : $obj->end_in_clone_coord();
 Function:

            Sets and returns the end in the original coordinate
            system.  The end attribute will be reset to other
            cooerdiante systems.  If value is not set, returns undef.

 Example :
 Returns : integer or undef
 Args    : integer

=cut

sub end_in_clone_coord {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'end_in_clone_coord'} = $value;
    }
   if( ! exists $obj->{'end_in_clone_coord'} ) {
       return undef;
   }
   return $obj->{'end_in_clone_coord' };

}

=head2 status

 Title   : status
 Usage   : $obj->status()
 Function:

           Returns the status of the variation object.
           Valid values are: 'suspected' and 'proven'

 Example : $obj->status('proven');
 Returns : scalar
 Args    : valid string (optional, for setting)


=cut


sub status {
   my ($obj,$value) = @_;
   my %status = (suspected => 1,
		 proven => 1
		 );

   if( defined $value) {
       $value = lc $value;
       if ($status{$value}) {
	   $obj->{'status'} = $value;
       }
       else {
	   $obj->throw("$value is not valid status value!");
       }
    }
   if( ! exists $obj->{'status'} ) {
       return undef;
   }
   return $obj->{'status'};
}


=head2 alleles

 Title   : alleles
 Usage   : @alleles = split ('|', $obj->alleles);
 Function:
           Returns the a string where all known alleles for this position
           are listed separated by '|' characters

 Returns : A string
 Args    : A string (optional, for setting)

=cut

sub alleles {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'alleles'} = $value;
    }
   if( ! exists $obj->{'alleles'} ) {
       return undef;
   }
   return $obj->{'alleles'};

}

=head2 position_problem

 Title   : position_problem
 Usage   :
 Function:
           Returns a value if the there are known problems in mapping
	   the variation from internal coordinates to EMBL clone
	   coordinates.

 Returns : A string
 Args    : A string (optional, for setting)

=cut

sub position_problem {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'position_problem'} = $value;
    }
   if( ! exists $obj->{'position_problem'} ) {
       return undef;
   }
   return $obj->{'position_problem'};
}


=head2 upStreamSeq

 Title   : upStreamSeq
 Usage   : $obj->upStreamSeq();
 Function:

            Sets and returns upstream flanking sequence string.
            If value is not set, returns undef.

 Example :
 Returns : string or undef
 Args    : string

=cut


sub upStreamSeq {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'upstreamseq'} = $value;
  }
   if( ! exists $obj->{'upstreamseq'} ) {
       return undef;
   }
   return $obj->{'upstreamseq'};

}


=head2 dnStreamSeq

 Title   : dnStreamSeq
 Usage   : $obj->dnStreamSeq();
 Function:

            Sets and returns dnstream flanking sequence string.
            If value is not set, returns undef.

 Example :
 Returns : string or undef
 Args    : string

=cut


sub dnStreamSeq {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'dnstreamseq'} = $value;
  }
   if( ! exists $obj->{'dnstreamseq'} ) {
       return undef;
   }
   return $obj->{'dnstreamseq'};

}

=head2 add_DBLink

 Title   : add_DBLink
 Usage   : $self->add_DBLink($ref)
 Function: adds a link object
 Example :
 Returns :
 Args    :


=cut

sub add_DBLink{
   my ($self,$com) = @_;
   if( ! $com->isa('Bio::Annotation::DBLink') ) {
       $self->throw("Is not a link object but a  [$com]");
   }
   push(@{$self->{'link'}},$com);
}

=head2 each_DBLink

 Title   : each_DBLink
 Usage   : foreach $ref ( $self->each_DBlink() )
 Function: gets an array of DBlink of objects
 Example :
 Returns :
 Args    :


=cut

sub each_DBLink{
   my ($self) = @_;

   return @{$self->{'link'}};
}


1;
