#!/usr/local/bin/perl

# Cared for by Michele Clamp  <michele@sanger.ac.uk>
#
# Copyright Michele Clamp
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::ExternalData

=head1 SYNOPSIS
my $gene1 = Bio::EnsEMBL::ExternalData::Locus->new (-GDB => 'GDB:119655'); 
my $gene2 = Bio::EnsEMBL::ExternalData::Locus->new (-NAME => 'ADSL');
my $gene3 = Bio::EnsEMBL::ExternalData::Locus->new (-ACC => 'AF067853');

$gene1->web_fetch();    #fetch ftp and search for gene
$gene2->web_fetch();
$gene3->web_fetch();

$gene1->printace();     #print locus object in ace format
$gene2->printace();
$gene3->printace();
    
=head1 DESCRIPTION

Object to store the details of external OMIM and gdbid numbers taken from
Locuslink

=head2 Methods:
    new,
    name           (e.g. ADSL)
    full_name      (e.g. adenylosuccinate lyase)
    gdbid          (e.g. GDB:119655)
    omim           (e.g. 103050)
    location       (22q11.2)
    llid           (locus link number)
    species        (e.g. Homo sapiens)
    chromosome     (e.g. X)
       
    print_ace      returns an ace string for a locus object 

    web_fetch       Uses either the gene name or the GDB 
                  id (depending on which one is present) to fill in the
                  rest of the data.  

                  The data is fetched using the CPAN module LWP. The file LL.out
                  is ftp-ed from the NCBI and stored locally.

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

=cut
use strict;
package Bio::EnsEMBL::ExternalData::Locus;
use vars qw(@ISA);

use Bio::Root::Object;
use HTML::Parser;
use LWP;
use URI::URL;
use HTTP::Request::Common qw(POST);
use Data::Dumper;

@ISA = qw(Bio::Root::Object);

=head2 new
    Title   :   new
    Usage   :   my obj = Bio::EnsEMBL::ExternalData::Locus->new (-GDB => 'GDB:119655');
    Function:   Initialises Locus object
    Returns :   a Locus object
    Args    :   A GDB id (-GDB), Name (-NAME) or Accession number (-ACC)

=cut
sub _initialize {
    my ($self,@args) = @_;
    my $make = $self->SUPER::_initialize(@_);
    
    #member variables
    $self->{_name} = undef;           #four letter code
    $self->{_fullname} = undef;       #full gene name
    $self->{_llid} = undef;           #locus link id
    $self->{_gdbid} = undef;          #gdb or other id
    $self->{_species} = undef;        #species of locus
    $self->{_omim} = [];              #can have more than one value for omim
    $self->{_chromosome} = undef;     #chromosome
    $self->{_location} = undef;       #location    
    $self->{_agent} = undef;          #LWP::UserAgent object
    $self->{_locuslink_url} = undef;  #url to locus link ftp site
    $self->{_locuslink_file} = undef; #locus link file for searching (LL.out)
    $self->{_path} = undef;           #location of locally stored LL.out
    $self->{_accession} =undef;       #accession number (for searching EMBL)
    $self->{_match} = undef;          #flag for match found in LL.out
    
    #set operations
    $self->set_agent(); 
    $self->locuslink_url('ncbi.nlm.nih.gov/refseq/LocusLink/');
    $self->locuslink_file('LL.out');
    my ($gdbid, $name, $accession) = $self->_rearrange(['GDB', 'NAME', 'ACC'],@args);
    $self->gdbid($gdbid) if ($gdbid);
    $self->name($name) if ($name);
    $self->accession($accession) if ($accession); 
    
    return $self; # success - we hope!
}

##########################
#get/set functions
##########################

sub set_agent {
    my ($self) = @_;
    $self->{_agent} = LWP::UserAgent->new() or 
        $self->throw ("Unable to create user agent: $!");
    $self->{_agent}->agent("Locuslink fetcher/0.1");
} 

sub agent {
    my ($self) = @_;
    return $self->{_agent};
}

sub path {
    my ($self, $path) = @_;
    if ($path)
    {
        $self->{_path} = $path;
    }
    return $self->{_path};        
}
=head2 accession
    Title   :   accession
    Usage   :   my obj->accession()
    Function:   get/set method for accession
    Returns :   accession
    Args    :   accession (optional)

=cut
sub accession {
    my ($self, $accession) = @_;
    if ($accession)
    {
        $self->{_accession} = $accession;
    }
    return $self->{_accession};
}    

sub locuslink_url {
    my ($self, $url) = @_;
    if ($url)
    {
        $self->{_locuslink_url} = $url;
    }
    return $self->{_locuslink_url};        
}

sub locuslink_file {
    my ($self, $filename) = @_;
    if ($filename)
    {
        $self->{_locuslink_file} = $filename;
    }
    return $self->{_locuslink_file};        
}

=head2 gdbid
    Title   :   gdbid
    Usage   :   my obj->gdbid()
    Function:   get/set method for gdbid
    Returns :   gdbid
    Args    :   gdbid (optional)

=cut
sub gdbid {
    my ($self, $gdbid) = @_;
    if ($gdbid)
    {
        $self->{_gdbid} = $gdbid;
    }
    return $self->{_gdbid};        
}

=head2 name
    Title   :   name
    Usage   :   my obj->name()
    Function:   get/set method for name
    Returns :   name
    Args    :   name (optional)

=cut
sub name {
    my ($self, $name) = @_;
    if ($name)
    {
        $self->{_name} = $name;
    }
    return $self->{_name};
}

sub matched {
    my ($self, $flag) = @_;
    if ($flag)
    {
        $self->{_match} = $flag;
    }
    return $self->{_match};
}

sub llid {
    my ($self, $llid) = @_;
    if ($llid)
    {
        $self->{_llid} = $llid;
    }
    return $self->{_llid};
}

sub omim {
my ($self, $omim) = @_;
    if ($omim)
    {
       push (@{$self->{_omim}}, $omim);
    }
    return @{$self->{_omim}};
}

sub location {
my ($self, $location) = @_;
    if ($location)
    {
        $self->{_location} = $location;
    }
    return $self->{_location};
}

sub fullname {
my ($self, $fullname) = @_;
    if ($fullname)
    {
        $self->{_fullname} = $fullname;
    }
    return $self->{_fullname};
}

sub species {
my ($self, $tax_id) = @_;
my %species = ('9606', 'Homo sapiens', '10090', 'Mus musculus', '10116', 'rat');
    if ($tax_id)
    {
        $self->{_species} = $species{$tax_id};
    }
    return $self->{_species};
}

sub chromosome {
my ($self, $chromosome) = @_;
    if ($chromosome)
    {
        $self->{_chromosome} = $chromosome;
    }
    return $self->{_chromosome};
}

######################
#web query and parsing
######################
sub get_ftp {
    my ($self, $url, $file) = @_;
    print "$url, $file\n";
    my $request = HTTP::Request->new 
            (GET => 'ftp://'.$url.'/'.$file);
    print "Connecting to ftp://$url\n";
    $request->header(Accept => 'text/html, */*;q=0.1');
    my $result = $self->agent->request($request, $file, $self->path);
    if ($result->is_success)
    {
        print "$file downloaded from $url OK\n";
    }
    else 
    {
        $self->throw ("ftp access to $file failed\n");
    }
}

sub grep_locuslink {
    my ($self, $filename, $search) = @_;
    #search using grep and parse results (possibly multi-line return)
    my @matches = `grep $search $filename` 
            or (print "Name/ID $search not found in $filename\n");
    foreach my $line (@matches)
    {
       $self->parse_locus($line, $search);
    }    
}

sub parse_locus {
    my ($self, $line, $search) = @_;
    my ($locusid, $symbol, $interim, $mim, $chromosome, $location, $default_name,
        $tax_id, $id) = split (/\t/,$line);
    chomp ($id);    #removes terminal return character
    #find match
    if ($search eq $symbol || $search eq $id)
    {
        $self->llid($locusid);
        $self->name($symbol);
        $self->omim($mim);
        $self->chromosome($chromosome);
        $self->location($location);
        $self->fullname($default_name);
        $self->species($tax_id);
        $self->gdbid($id);
        $self->matched('True');
    }    
}

sub search_embl {
    my ($self) = @_;
    print "searching embl for ".$self->accession."\n";
    open (EMBL, "efetch ".$self->accession."|") or warn ("Couldn't use efetch");
    
    foreach my $line (<EMBL>)
    {
        if ($line =~ m'/gene="'g)
        {
            chomp($line);
            $line =~ s/.*="//; #strip away right side text
            $line =~ s/".*//;  #strip away left side text
            $self->name($line);            
            close EMBL;
            return; #Don't parse remaining lines for speed
        }
    }
    close EMBL;
}
#####################
# public output/fetch functions
#####################
=head2 web_fetch
    Title   :   web_fetch
    Usage   :   my obj->web_fetch()
    Function:   Searches LL.out using data provided during initialisation
    Returns :   none
    Args    :   none

=cut

sub web_fetch {
    my ($self) = @_;
    #test if object set (needs name or gdbid)    
    unless ($self->name || $self->gdbid || $self->accession)
    {
        print "A locus name, GDB id or embl accession is needed";
        return;
    }
    
    if ($self->accession)
    {
        #Find gene name from embl using accession
        $self->search_embl();
        unless ($self->name)
        {
            print "Unable to find accession ".$self->accession." using efetch\n";
            return;
        }
    }
    
    my $filepath; #set directory location of 'LL.out'
    if ($self->path)
        {   $filepath = $self->path.$self->locuslink_file;    }
    else
        {   $filepath = $self->locuslink_file;  }
    
    unless (-e $filepath || -C $filepath > 7)
    {
        print "LL.out not present or out of date. Fetching....\n";
        $self->get_ftp($self->locuslink_url, $self->locuslink_file);
    }
    
    my $searchstring; #set string to search against 'LL.out'
    if ($self->name)
        {  $searchstring = $self->name; }
    else
        { $searchstring = $self->gdbid; }
    #run search and set variables if match is found
    $self->grep_locuslink($self->locuslink_file, $searchstring);          
}

=head2 printace
    Title   :   printace
    Usage   :   my obj->printace()
    Function:   Prints member variables of Locus object in ace format. 
                Only if match was found using webfetch.
    Returns :   List of variables in ace format
    Args    :   none

=cut
sub printace {
my ($self, $name) = @_;
    if ($self->matched)
    {
        print "\n";
        print "Locus \"".$self->name."\"\n";    #object name
        print "Full_name \"".$self->fullname."\"\n" if ($self->fullname);
        print "LL_id \""..$self->llid."\"\n" if ($self->llid);
        print "Chromosome \"".$self->chromosome."\"\n" if ($self->chromosome);
        print "Location \"".$self->location."\"\n" if ($self->location);
        foreach my $entry ($self->omim)
        {
            print "OMIM \"".$entry."\"\n";
        }
        print "GBI_id \"".$self->gdbid."\"\n" if ($self->gdbid);
        print "Species \"".$self->species."\"\n" if ($self->species);
    }
}
