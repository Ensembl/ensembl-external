# $Id$

# tables for Anton Enright's protein family clustering. 
# this is preliminary  still!

CREATE TABLE family (
   internal_id   int(10) NOT NULL,
   id            varchar(40) NOT NULL, -- ENSF0000012345 or whatever ?
   description   varchar(200) NOT NULL, -- check length
   release       varchar(10) NOT NULL,
   annotation_confidence_score double, 
    
   PRIMARY KEY(id)
);

-- table to hold keywords
CREATE TABLE family_keywords (
  family     int(10) NOT NULL,
  keyword    varchar(100) NOT NULL,

  PRIMARY KEY(family)
);

CREATE TABLE family_members (
  family	      int(10) NOT NULL,
  db_name             varchar(12) NOT NULL, 
                      -- currently ENSEMBL, SPTREMBL, SWISSPROT
  db_id               varchar(40) NOT NULL, -- e.g., ENSP000001234 or P12345
--  score double ? -- ie., some confidence in likelyhood of cluster assignment ?
    PRIMARY KEY(family, db_name, db_id)
);

CREATE TABLE dbxrefs (
   family_id      varchar(40) NOT NULL,
   external_db  varchar(40) NOT NULL,
   external_id  varchar(40) NOT NULL,
   
   PRIMARY KEY(family_id,external_db,external_id)
);
