# $Id$
# SQL for producing file suitable for Tony's AltaVista indexing
# Used by wrapper script fam-fulltext.sh
SELECT CONCAT(fm.db_id, '|family|', f.description) 
FROM family_members fm, family f 
WHERE fm.family = f.internal_id 
  AND fm.db_name='ENSEMBLGENE' 


