# MySQL dump 7.1
#
# Host: localhost    Database: disease
#--------------------------------------------------------
# Server version	3.22.32

#
# Table structure for table 'disease'
#
CREATE TABLE disease (
  id int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
  disease varchar(60),
  PRIMARY KEY (id)
);

#
# Table structure for table 'gene'
#
CREATE TABLE gene (
  id int(10) DEFAULT '0' NOT NULL,
  gene_symbol varchar(30),
  omim_id int(10),
  start_cyto varchar(20),
  end_cyto varchar(20),
  chromosome varchar(5)
);

