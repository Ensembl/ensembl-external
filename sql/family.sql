# $Id$

# Tables for protein family clustering.

CREATE TABLE family (
   family_id			int(10) NOT NULL auto_increment,
   stable_id			varchar(40) NOT NULL, # e.g. ENSF0000012345
   description			varchar(255) NOT NULL,
   release			varchar(10) NOT NULL,
   annotation_confidence_score	double, 
   size        			int(10) NOT NULL,

   PRIMARY KEY(family_id), 
   UNIQUE KEY(stable_id),
   KEY(description),
   KEY(release)
);

CREATE TABLE external_db (
  external_db_id	int(10) NOT NULL auto_increment,
  name varchar(40) 	NOT NULL,

  PRIMARY KEY(external_db_id),
  UNIQUE KEY(name)
);

CREATE TABLE family_members (
  family_member_id	int(10) NOT NULL auto_increment,
  family_id		int(10) NOT NULL, # foreign key from family table
  external_db_id        int(10) NOT NULL, # foreign key from external_db table 
  external_member_id	varchar(40) NOT NULL, # e.g. ENSP000001234 or P31946
  taxon_id		int(10) NOT NULL, # foreign key from taxon table

  PRIMARY KEY(family_member_id),
  UNIQUE KEY(family_id,external_db_id,external_member_id,taxon_id),

  KEY(external_db_id,external_member_id),
  KEY(external_db_id),
  UNIQUE KEY(external_member_id),
  KEY(family_id,external_db_id)
);

CREATE TABLE taxon (
  taxon_id		int(10) NOT NULL,
  genus			varchar(50),
  species	        varchar(50),
  sub_species		varchar(50),
  common_name		varchar(100),
  classification	mediumtext,

  PRIMARY KEY(taxon_id),
  KEY(genus,species),
  KEY(common_name)
);

CREATE TABLE alignments (
  family_id  int(10) NOT NULL, #foreign key to family table
  alignment  mediumtext NOT NULL,
  PRIMARY KEY(family_id)
);

#### deprecated ##########
#CREATE TABLE cumulative_distrib (
#  family_size int(10) NOT NULL,
#  occurrences int(10) NOT NULL,
#  cum_fraction_of_peptides float(4) NOT NULL, 
#  PRIMARY KEY(family_size)
#); 

#### deprecated ##########
#CREATE TABLE family_totals (
#   family_id		int(10) NOT NULL, #foreign key to family table
#   external_db_id	int(10) NOT NULL, #foreign key to external_db table 
#   taxon_id		int(10) NOT NULL, # foreign key from taxon table
#   members_total	int(10) NOT NULL,
#
#   PRIMARY KEY (family_id,external_db_id,taxon_id),
#   KEY (members_total)
#);

#### deprecated ##########
#CREATE TABLE meta (
#    meta_id INT unsigned not null auto_increment,
#    meta_key varchar( 40 ) not null,
#    meta_value varchar( 255 ) not null,
#
#    PRIMARY KEY( meta_id ),
#    KEY meta_key_index ( meta_key ),
#    KEY meta_value_index ( meta_value )
#);

### not yet implemented:
# ## table to hold keywords
# CREATE TABLE family_keywords (
#   family     int(10) NOT NULL,
#   keyword    varchar(100) NOT NULL,
# 
#   PRIMARY KEY(family)
# );

### not yet implemented:
# CREATE TABLE dbxrefs (
#    family_id    int(10) NOT NULL,
#    external_db  varchar(40) NOT NULL,
#    external_id  varchar(40) NOT NULL,
#    
#    PRIMARY KEY(family_id,external_db,external_id)
# );
