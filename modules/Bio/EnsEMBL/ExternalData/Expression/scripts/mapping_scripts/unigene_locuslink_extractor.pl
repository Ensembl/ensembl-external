


#extracts unigene_locuslink mapping from an NCBI's Hs. file
#download the NCBI's file from the NCBI's ftp



while (<>)
{
chomp;
if (/ID\s+Hs.(\d+)/) {print "\n", $1, "\t"}
if (/LOCUSLINK\s+(\d+)/) {print $1}
}
