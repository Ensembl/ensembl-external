#!/bin/sh

### do statistics on the conflicts found when loading TRIBE families:

usage="Usage: $0 file-with-output-from-family-input.pl"
if [ $# -ne 1  ]; then
     echo $usage; exit 1;
fi

file=$1

echo -n Totals:
grep "^inserted" $file

echo -n Total number of conflicts:
grep "^### assigning" $file| wc -l

echo -n "UNKNOWN, replaced by other description:"
grep "^### replacing previous.*, desc: UNKNOWN" $file | wc -l
echo -n "other, _not_ replaced by UNKNOWN:"
grep "^### alternative would be: UNKNOWN" $file | wc -l

echo -n "other, replaced by (hopefully better) descriptions:"
grep "^### replacing previous.*, desc: " $file | grep -v UNKNOWN | wc -l

echo -n "other, _not_ replaced by (probably worse, but not UNKNOWN) others:"
grep "^### alternative would be:" $file  | grep -v UNKNOWN | wc -l

echo -n "remaining UNKNOWN":
grep "^### leaving as is; desc: UNKNOWN" $file | wc -l

echo -n "remaining not-UNKNOWNs (i.e., different families with same annots)":
grep "^### leaving as is; desc:" $file | grep -v "UNKNOWN" | wc -l
