
# BioPerl module for Greg Schuler's contig xml file
#
# Cared for by Ewan Birney <birney@sanger.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::ExternalData::Schuler

=head1 SYNOPSIS

    my $schuler = new Bio::EnsEMBL::ExternalData::Schuler(-file => $file,
							  -db   => $db,
							  )

    $schuler->parse          # Read the file and parse
    $schuler->write          # Write the data in the database
    $schuler->print          # Print the data out

=head1 DESCRIPTION



=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...

package Bio::EnsEMBL::ExternalData::Schuler;
use vars qw(@ISA);
use strict;

# Object preamble - inherits from Bio::Root::Object

require LWP::UserAgent;



use Bio::Root::Object;
use Bio::EnsEMBL::ContigOverlap;

@ISA = qw(Bio::Root::Object);

# new() is inherited from Bio::Root::Object

# _initialize is where the heavy stuff will happen when new is called

sub _initialize {
  my($self,@args) = @_;

  my $make = $self->SUPER::_initialize;

  my ($file,$db) = $self->_rearrange([qw(FILE
					 DB
					)],@args);

  $file  || $self->throw("Need an input file");

  $self->file($file);
  $self->_dbobj($db);


# set stuff in self from @args
  return $make; # success - we hope!
}

sub _dbobj {
    my ($self,$arg) = @_;
    
    if (defined($arg)) {
	$self->throw("Not a Bio::EnsEMBL::DBSQL::Obj") unless $arg->isa("Bio::EnsEMBL::DBSQL::Obj");
	$self->{_dbobj} = $arg;
    }

    return $self->{_dbobj};
}

sub file {
    my ($self,$arg) = @_;
    
    if (defined($arg)) {
	$self->{_file} = $arg;
    }
    return $self->{_file};
    
}


sub parse {
    my ($self) = @_;

    $self->throw("No file input") unless defined($self->file);

    open(IN,"<" . $self->file) || $self->throw("Can't open file " . $self->file);

    my $acc;
    my $sv;
    my $name;
    my $title;
    my $seqlen;
    my $chr;
    my $pos;
    my $labs;
    my @parts;
    
    my %contig;
    
    my $insts;
    

    LINE : while (<IN>) {

	if ($_ =~ /<stslist>/) {
	    $insts = 1;
	} 
	
	if ($_ =~ /<\/stslist>/) {
	    $insts = 0;
	} 
	
	if ($insts == 1) {
	    next LINE;
	}
	
	if (/<acc>(.*)\.(.*)<\/acc>/) {
	    $acc = $1;
	    $sv  = $2;
	}
	
	if (/<name>(.*)<\/name>/) {
	    print ("\n");
	    $name = $1;
	}
	
	
	$title  = $1 if /<title>(.*)<\/title>/;
	$seqlen = $1 if /<seqlen>(.*)<\/seqlen>/;
	$chr    = $1 if /<chr>(.*)<\/chr>/;
	$pos    = $1 if /<pos>(.*)<\/pos>/;
	$labs   = $1 if /<labs>(.*)<\/labs>/;
	
	if ($_ =~ /<part>/) {
	    my $cpos1;
	    my $cpos2;
	    my $ori;
	    my $acc;
	    my $gi;
	    my $length;
	    my $clone;
	    my $cloneacc;
	    my $clonesv;
	    my $ctype;
	    my $cpos;
	    my $lab;
	    
	    while (($_ = <IN>) !~ /<\/part>/) {
		$cpos1 = $1 if /<cpos1>(.*)<\/cpos1>/;
		$cpos2 = $1 if /<cpos2>(.*)<\/cpos2>/;
		$ori   = $1 if /<ori>(.*)<\/ori>/;
		$clone = $1 if /<clone>(.*)<\/clone>/;
		if (/<acc>(.*)\.(.*)<\/acc>/) {
		    $cloneacc = $1;
		    $clonesv  = $2;
		}
		$length = $1 if /<seqlen>(.*)<\/seqlen>/;
	    }
	    
	    my %clone;
	    
	    $clone{cpos1}  = $cpos1;
	    $clone{cpos2}  = $cpos2;
	    $clone{length} = $length;
	    $clone{ori}    = $ori;
	    $clone{acc}    = $cloneacc;
	    $clone{sv}     = $clonesv;
	    
	    $contig{$name}{clone}{$clone} = \%clone;
	}
	
	if ($_ =~ /<\/contig>/) {
	    $contig{$name}{acc}    = $acc;
	    $contig{$name}{title}  = $title;
	    $contig{$name}{seqlen} = $seqlen;
	    $contig{$name}{chr}    = $chr;
	    $contig{$name}{pos}    = $pos;
	    $contig{$name}{labs}   = $labs;
	    
	    my @clones = sort {$contig{$name}{clone}{$a}{cpos1} <=> $contig{$name}{clone}{$b}{cpos1}} keys %{$contig{$name}{clone}};

	    $self->make_overlaps($contig{$name}{clone},$name);

	    foreach my $cl (@clones) {
		printf("%15s %15s %15s %15s %10d %10d %5d %5d %15s\n",$name,$acc,$cl,
		       $contig{$name}{clone}{$cl}{acc},
		       $contig{$name}{clone}{$cl}{cpos1},
		       $contig{$name}{clone}{$cl}{cpos2},
		       $contig{$name}{clone}{$cl}{sv},
		       $contig{$name}{clone}{$cl}{ori},
	     $contig{$name}{labs});
	    }
	}
    }
}

sub check_dna {
    my ($self,$contigid,$sv,$length) = @_;

    $self->throw("No database handle defined. Can't check dna") unless defined($self->_dbobj);

    my $clone   = $self->_dbobj->get_Clone($contigid);
    my @contig  = $clone->get_all_Contigs;

    if ($#contig > 0) {
	$self->throw("More than one contig in clone.");
    }

    my $version = $contig[0]->seq_version;
    my $dna     = $contig[0]->primary_seq;

    $self->throw("No dna defined for $contigid")              unless defined($dna);
    $self->throw("No sequence version defined for $contigid") unless defined($version);

    my $ok = 1;

    if ($version == $sv) {
	print(STDERR "version match for $contigid = [$version][$sv]\n");

    } else {
	print(STDERR "version mismatch for $contigid [$version][$sv]\n");
	$ok = 0;
    }

    if ($dna->length != $length) {
	print(STDERR "Dna length mismatch for $contigid [".$dna->length."][$length]\n");
	$ok = 0;
    } else {
	print(STDERR "Dna length match for $contigid [".$dna->length."][$length]\n");
    }

    if ($ok == 0) {
	$self->throw("Dna checks failed for $contigid");
    }
	
}
    
    
sub make_overlaps {
    my ($self,$contig,$name) = @_;

    print(STDERR "Name is $name\n");

    my @clones = sort {$contig->{$a}{cpos1} <=> $contig->{$b}{cpos1}} keys %{$contig};
    my $numclones = scalar(@clones);
    print(STDERR "Numclones = $numclones\n");
    return unless $numclones > 1;

    for (my $i = 0; $i < $numclones-1; $i++) {
	eval {
	    my $clonea = $contig->{$clones[$i]};
	    my $cloneb = $contig->{$clones[$i+1]};
	    
	    my $contiga = $clonea->{acc};
	    my $contigb = $cloneb->{acc};
	    
	    my $lengtha = $clonea->{cpos2} - $clonea->{cpos1} + 1;
	    my $lengthb = $cloneb->{cpos2} - $cloneb->{cpos1} + 1;
	    
	    my $sva     = $clonea->{sv};
	    my $svb     = $cloneb->{sv};
	    
	    my $versiona = $self->check_dna($contiga,$sva,$lengtha);
	    my $versionb = $self->check_dna($contigb,$svb,$lengthb);
	    
	    my $oria    = $clonea->{ori};
	    my $orib    = $cloneb->{ori};
	    
	    
	    my $type;
	    my $posa;
	    my $posb;
	    
	    if ($oria == 1) {
		$posa = $lengtha;
		if ($orib == 1) {
		    $type = 'right2left';
		    $posb = $clonea->{cpos2} - $cloneb->{cpos1} + 1;
		} else {
		    $posb = $lengthb - ($clonea->{cpos2} - $cloneb->{cpos1});
		    $type = 'right2right';
		    
		}
	    } else {
		$posa = 1;
		if ($orib == 1) {
		    $type = 'left2left';
		    $posb = $clonea->{cpos2} - $cloneb->{cpos1} + 1;		
		} else {
		    $type = 'left2right';
		    $posb = $lengthb - ($clonea->{cpos2} - $cloneb->{cpos1});
		}
	    }
	    
	    print(STDERR "OVERLAP $contiga\t$contigb\t$posa\t$posb\t$type\n");
	    
	    my $contigobja = $self->get_Contig($contiga);
	    my $contigobjb = $self->get_Contig($contigb);
	    
	    my $overlap = new Bio::EnsEMBL::ContigOverlap(-contiga      => $contigobja,
							  -contigb      => $contigobjb,
							  -positiona    => $posa,
							  -positionb    => $posb,
							  -overlap_type => $type);
	    
	    $self->_dbobj->write_ContigOverlap($overlap,"SCHULER");
	    
	};
	if ($@) {
	    print("Error creating overlap [$@]\n");
	}
    }
	    
}


sub get_Contig {
    my ($self,$contigid) = @_;

    $self->throw("No database handle defined. Can't check dna") unless defined($self->_dbobj);

    my $clone   = $self->_dbobj->get_Clone($contigid);
    my @contig  = $clone->get_all_Contigs;

    if ($#contig > 0) {
	$self->throw("More than one contig in clone $contigid");
    }
    
    return $contig[0];
}

1;



