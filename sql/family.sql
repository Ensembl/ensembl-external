# $Id$

# tables for Anton Enrights protein family clustering. 

CREATE TABLE family (
   family_id    int(10) NOT NULL,
   stable_id  varchar(40) NOT NULL, ##  e.g. ENSF0000012345
   description  varchar(255) NOT NULL,
   release      varchar(10) NOT NULL,
   annotation_confidence_score double, 

   PRIMARY KEY(family_id), 
   UNIQUE KEY(stable_id),
   KEY(description),
   KEY(release)
);

CREATE TABLE family_totals (
   family_id int(10) NOT NULL, #foreign key to family table
   external_db_id int(10) NOT NULL, #foreign key to external_db table 
   members_total int(10) NOT NULL,

   PRIMARY KEY (family_id,external_db_id),
   KEY (members_total)
);


CREATE TABLE alignments (
  family_id  int(10) NOT NULL, #foreign key to family table
  alignment  mediumtext NOT NULL,
  PRIMARY KEY(family_id)
);

CREATE TABLE external_db (
  external_db_id int(10) NOT NULL auto_increment,
  name varchar(40) NOT NULL,

  PRIMARY KEY(external_db_id),
  UNIQUE KEY(name)
);


CREATE TABLE family_members (
  family_id	      int(10) NOT NULL,
  external_db_id        int(10) NOT NULL, #foreign key to family_db table 
  external_member_id  varchar(40) NOT NULL, ##  e.g., ENSP000001234
  PRIMARY KEY(family_id, external_db_id, external_member_id),
  UNIQUE KEY(external_db_id, external_member_id),
  KEY(external_db_id),
  KEY(family_id,external_db_id)
);

CREATE TABLE cumulative_distrib (
  family_size int(10) NOT NULL,
  occurrences int(10) NOT NULL,
  cum_fraction_of_peptides float(4) NOT NULL, 
  PRIMARY KEY(family_size)
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
