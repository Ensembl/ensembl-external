#!/bin/sh
# $Id$

# script producing file suitable for Tony's AltaVista indexing
# Used by wrapper script fam-fulltext.sh

usage="Usage: $0 -h host -u user databasename >  file.txt"

if [ $# -lt 5 ] ; then
    echo $usage
    exit 1
fi

sql=./fam-fulltext.sql
mysql=mysql
mysql_extra_flags='--batch'

(cat <<EOF
# SQL for producing file suitable for Tony's AltaVista indexing
SELECT CONCAT(fm.db_id, '|family|', f.description) 
FROM family_members fm, family f 
WHERE fm.family = f.internal_id 
  AND fm.db_name='ENSEMBLGENE' 
EOF
) | $mysql $mysql_extra_flags "$@"
# ) | cat
exit 0
