
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "util/types.h"
#include "util/link.h"
#include "util/hash.h"
#include "util/txt.h"
#include "util/file.h"


int main
(  int   argc
,  char* argv[]
)  {
      int            i
   ;  int            ct    =  0
   ;  int            buckets= 0
   ;  mcxTxt*        txt
   ;  mcxKV*         kv
   ;  mcxTxt*        txts  =  mcxTxtEmptyString(NULL)
   ;  mcxmode        rlmode=  READLINE_CHOMP | READLINE_SKIP_EMPTY

   ;  mcxIOstream*   xf
   ;  mcxHash*       hash

   ;  if (argc < 3)
         fprintf
         (  stdout
         ,  "Usage: hashfile <int n> <file fname> [str]*\n"
            "   hashfile inserts each line (newline removed) from fname\n"
            "   into a hash with 2^[ceil(2log(n))] buckets,\n"
            "   searches subsequent arguments (from [str]*) in the hash,\n"
            "   prints some statistics, and deletes the hash.\n"
            "   You may want to try it on path/name/dict/words.\n"
         )
      ,  exit(0)

   ;  buckets              =  atoi(argv[1])
   ;  xf                   =  mcxIOstreamNew(argv[2], "r")
   ;  hash                 =  mcxHashNew(buckets, mcxTxtHash, mcxTxtCmp)

   ;  mcxIOstreamOpen(xf, EXIT_ON_FAIL)

   ;  printf("building hash ..\n")
   ;  while((txt = mcxIOstreamReadLine(xf, NULL, rlmode)))
      mcxHashSearch(txt, hash, DATUM_INSERT), ct++
   ;  printf("done building hash (%d insertions, %d lines).\n", ct, xf->lc)

   ;  for (i=3;i<argc;i++)
      {
         mcxTxtWrite(txts, argv[i])
      ;  kv                =  mcxHashSearch(txts, hash, DATUM_FIND)

      ;  if (kv)
         printf("present: <%s>\n", ((mcxTxt*)kv->key)->str)
      ;  else
         printf("absent:  <%s>\n", txts->str)
   ;  }

   ;  mcxHashStats(hash)

   ;  printf("deleting hash ..\n")
   ;  mcxHashFree(&hash, mcxTxtFree, NULL)
   ;  printf("done deleting hash.\n")

   ;  return 0
;  }



