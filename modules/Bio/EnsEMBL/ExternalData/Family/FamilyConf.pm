# BioPerl Bio::Pipeline::FamilyConf
#
# configuration information

=head1 NAME
Bio::Pipeline::FamilyConf

=head1 DESCRIPTION
FamilyConf is a copy of humConf written by James Gilbert.

humConf is based upon ideas from the standard perl Env environment
module.

It imports and sets a number of standard global variables into the
calling package, which are used in many scripts in the human sequence
analysis system.  The variables are first decalared using "use vars",
so that it can be used when "use strict" is in use in the calling
script.  Without arguments all the standard variables are set, and
with a list, only those variables whose names are provided are set.
The module will die if a variable which doesn\'t appear in its
C<%FamilyConf> hash is asked to be set.

The variables can also be references to arrays or hashes.

All the variables are in capitals, so that they resemble environment
variables.

=head1

=cut


package Bio::EnsEMBL::ExternalData::Family::FamilyConf;
use strict;
use vars qw(%FamilyConf);


%FamilyConf = ( 


    ENSEMBL_SPECIES =>"human,mouse,fugu,zebrafish",

    HUMAN_TAXON     =>"PREFIX=ENSP;taxon_id=9606;taxon_common_name=Human;taxon_classification=sapiens:Homo:Hominidae:Catarrhini:Primates:Eutheria:Mammalia:Euteleostomi:Vertebrata:Craniata:Chordata:Metazoa:Eukaryota",

    MOUSE_TAXON     =>"PREFIX=ENSMUSP;taxon_id=10090;taxon_common_name=Mouse;taxon_classification=musculus:Mus:Murinae:Muridae:Sciurognathi:Rodentia:Eutheria:Mammalia:Euteleostomi:Vertebrata:Craniata:Chordata:Metazoa:Eukaryota",

    FUGU_TAXON      =>"PREFIX=FRUP;taxon_id=31033;taxon_common_name=Japanese Pufferfish;taxon_classification=rubripes:Fugu:Takifugu:Tetraodontidae:Tetraodontiformes:Percomorpha:Acanthopterygii:Acanthomorpha:Neoteleostei:Euteleostei:Teleostei:Neopterygii:Actinopterygii:Euteleostomi:Vertebrata:Craniata:Chordata:Metazoa:Eukaryota",
    
    ZEBRAFISH_TAXON =>"PREFIX=ENSDARP;taxon_id=7955;taxon_common_name=Zebrafish;taxon_classification=rerio:Brachydanio:Danio:Cyprinidae:Cypriniformes:Ostariophysi:Teleostei:Neopterygii:Actinopterygii:Euteleostomi:Vertebrata:Craniata:Chordata:Metazoa:Eukaryota",

    FAMILY_PREFIX   =>"ENSF",

    FAMILY_START    =>1,

    EXTERNAL_DBNAME =>"ensembl",

    RELEASE         =>"9",

);

1;
