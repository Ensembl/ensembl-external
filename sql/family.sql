# $Id$

# tables for Anton Enrights protein family clustering. 

CREATE TABLE family (
   internal_id   int(10) NOT NULL,
   id            varchar(40) NOT NULL, ##  e.g. ENSF0000012345
   description   varchar(255) NOT NULL,
   release       varchar(10) NOT NULL,
   annotation_confidence_score double, 

   num_ens_pepts int(10) DEFAULT '0' NOT NULL,
    
   PRIMARY KEY(internal_id), 
   UNIQUE KEY(id)
);

CREATE TABLE alignments (
  family              int(10) NOT NULL,
  alignment           mediumtext NOT NULL,
  PRIMARY KEY(FAMILY)
);

CREATE TABLE family_members (
  family	      int(10) NOT NULL,
  db_name             varchar(12) NOT NULL, 
                                 ## currently ENSEMBLPEP, SPTREMBL, SWISSPROT
  db_id               varchar(40) NOT NULL, ##  e.g., ENSP000001234 or P12345
    PRIMARY KEY(family, db_name, db_id),
    UNIQUE KEY(db_name, db_id)
);

CREATE TABLE cumulative_distrib (
  family_size int(10) NOT NULL,
  occurrences int(10) NOT NULL,
  cum_fraction_of_peptides float(4) NOT NULL, 
  PRIMARY KEY(family_size)
); 

CREATE TABLE meta (
    meta_id INT unsigned not null auto_increment,
    meta_key varchar( 40 ) not null,
    meta_value varchar( 255 ) not null,

    PRIMARY KEY( meta_id ),
    KEY meta_key_index ( meta_key ),
    KEY meta_value_index ( meta_value )
);

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
