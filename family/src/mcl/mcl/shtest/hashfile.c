/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "util/types.h"
#include "util/link.h"
#include "util/hash.h"
#include "util/txt.h"
#include "util/types.h"
#include "util/file.h"


int main
(  int   argc
,  char* argv[]
)  {
      int            a
   ;  int            ct          =  0
   ;  int            found       =  0
   ;  int            n_buckets   =  1024
   ;  float          load        =  1.0
   ;  mcxbool        consthash   =  FALSE
   ;  mcxbool        buildonly   =  FALSE
   ;  mcxbool        walkhash    =  FALSE
   ;  mcxbool        egg         =  FALSE
   ;  mcxbool        show        =  TRUE
   ;  const char*    pattern     =  "egg"
   ;  mcxTing*        txts       =  mcxTingEmpty(NULL, 30)
   ;  mcxmode        rlmode      =  MCX_READLINE_CHOMP | MCX_READLINE_SKIP_EMPTY
   ;  u32            (*strhash)(const void* str)   =  mcxTingDPhash
   ;  mcxTing*        txt
   ;  mcxKV*         kv

   ;  mcxIOstream*   xf
   ;  mcxHash*       hash

   ;  if (argc < 2 || !strcmp(argv[1], "-h"))
      goto help

   ;  xf =  mcxIOstreamNew(argv[1], "r")
   ;  mcxIOstreamOpen(xf, EXIT_ON_FAIL)

   ;  a = 2
   ;  while (a < argc)
      {  if (!strcmp(argv[a], "-b"))
         {  if (a++ + 1 <argc)
            n_buckets = atoi(argv[a]) 
         ;  else
            goto arg_missing
      ;  }
         else if (!strcmp(argv[a], "-lb"))
         {  if (a++ + 1 <argc)
            {  int   l_buckets = atoi(argv[a]) 
            ;  n_buckets   =  2
            ;  while (--l_buckets)
               n_buckets <<=  1
         ;  }
            else
            goto arg_missing
      ;  }
         else if (!strcmp(argv[a], "--const"))
         {  consthash = TRUE
      ;  }
         else if (!strcmp(argv[a], "--build"))
         {  buildonly = TRUE
      ;  }
         else if (!strcmp(argv[a], "--walk"))
         {  walkhash = TRUE
      ;  }
         else if (!strcmp(argv[a], "--show"))
         {  show = TRUE
         ;  walkhash = TRUE 
      ;  }
         else if (!strcmp(argv[a], "-egg"))
         {  if (a++ + 1 <argc)
            pattern = argv[a] 
         ;  else
            goto arg_missing
         ;  egg = TRUE
      ;  }
         else if (!strcmp(argv[a], "-load"))
         {  if (a++ + 1 <argc)
            load = atof(argv[a]) 
         ;  else
            goto arg_missing
      ;  }
         else if (!strcmp(argv[a], "-lload"))
         {  if (a++ + 1 <argc)
            {  int iload = 2
            ;  int x = atoi(argv[a]) 
            ;  while (--x)
               iload <<= 1
            ;  load = iload
         ;  }
            else
            goto arg_missing
      ;  }
         else if (!strcmp(argv[a], "-f"))
         {  if (a++ + 1 <argc)
            {  if (!strcmp(argv[a], "dp"))
               strhash = mcxTingDPhash
            ;  else if (!strcmp(argv[a], "bj"))
               strhash = mcxTingBJhash
            ;  else if (!strcmp(argv[a], "elf"))
               strhash = mcxTingELFhash
            ;  else if (!strcmp(argv[a], "djb"))
               strhash = mcxTingDJBhash
            ;  else if (!strcmp(argv[a], "bdb"))
               strhash = mcxTingBDBhash
            ;  else if (!strcmp(argv[a], "svd"))
               strhash = mcxTingSvDhash
            ;  else if (!strcmp(argv[a], "svd2"))
               strhash = mcxTingSvD2hash
            ;  else if (!strcmp(argv[a], "svd1"))
               strhash = mcxTingSvD1hash
            ;  else if (!strcmp(argv[a], "ct"))
               strhash = mcxTingCThash
            ;  else
                  fprintf
                  (  stderr
                  ,  "[hashfile] hash option <%s> not supported\n", argv[a]
                  )
               ,  exit(1)
         ;  }
            else
            goto arg_missing
      ;  }
         else if (!strcmp(argv[a], "-h"))
         {  help:
fprintf
(  stdout
,
"Usage: hashfile <file fname> [options]* [search-strings]*\n"
"   Options:\n"
"   -b <#buckets>, -lb <2log-of-#buckets>\n"
"        Number of buckets initially created.\n"
"   -f <dp|bj|ct|bd|djb|elf|svd1|svd2|svd>\n"
"        Hash function to use:\n"
"        o  Daniel Philips (default)\n"
"        o  Bob Jenkins\n"
"        o  Chris Torek\n"
"        o  Berkely Databse\n"
"        o  Dan Bernstein\n"
"        o  UNIX ELF\n"
"        o  Some random and less random attempts of mine\n"
"   -load <load>, -lload <2log-of-load>\n"
"        Hash doubles when *average* bucket size exceeds load.\n"
"   --build    Exit after building hash.\n"
"   --const    Disable hash growing (how un-Dutch).\n"
"   --walk     Walk entire hash after creation.\n"
"   --show     Walk entire hash after creation, print all buckets.\n"
"   -egg <string> Look for an egg dressed in string.\n"
)
         ,  exit(0)
      ;  }
         else if (0)
         {  arg_missing:
         ;  fprintf
            (  stderr
            ,  "[hashfile] Flag %s needs argument; see help (-h)\n" 
            ,  argv[argc-1]
            )
         ;  exit(1)
      ;  }
         else
         break

      ;  a++
   ;  }

   ;  hash                 =  mcxHashNew(n_buckets, strhash, mcxTingCmp)

   ;  n_buckets            =  hash->n_buckets
   ;  hash->load           =  load

   ;  if (consthash)
      hash->options |= MCX_HASH_OPT_CONSTANT

   ;  fprintf(stderr, "\n---> building hash ..\n")
   ;  while((txt = mcxIOstreamReadLine(xf, NULL, rlmode)))
      {  mcxKV*   kv =  mcxHashSearch(txt, hash, MCX_DATUM_INSERT)
      ;  if (!kv)
         fprintf(stderr, ">>> >>> void kv!\n")
      ;  else if ((mcxTing*)kv->key != txt)
         fprintf(stderr, ">>> >>> [%.50s] overwrite!\n", txt->str)
      ;  else if (strcmp(((mcxTing*)kv->key)->str, txt->str))
         fprintf(stderr, ">>> >>> string diff!\n")
      ;  ct++
   ;  }

   ;  fprintf
      (stderr, "done building hash (%d insertions, %d lines).\n", ct, xf->lc)
   ;  fprintf
      (  stderr
      ,  "hash stats %d entries, %d buckets initial, %d buckets final\n"
      ,  hash->n_entries
      ,  n_buckets
      ,  hash->n_buckets
      )
   ;  fprintf
      (  stderr
      ,  "hash settings: [load %.3f] [mask %d] [bits %d]\n"
      ,  hash->load
      ,  hash->mask
      ,  hash->n_bits
      )

   ;  if (buildonly)
      exit(0)

   ;  if (walkhash)
      {
         mcxHashWalk*   hashwalk =  mcxHashWalkNew(hash)
      ;  int bucketidx = -1

      ;  fprintf(stderr, "---> walking hash ..\n")
      ;  ct =  0
      ;  found =  0

      ;  while((kv = mcxHashWalkStep(hashwalk)))
         {  ct++
         ;  if (mcxHashSearch((mcxTing*) kv->key, hash, MCX_DATUM_FIND))
            found++
         ;  if (egg && strstr(((mcxTing*)kv->key)->str, pattern))
            fprintf(stderr, "() %s\n", ((mcxTing*)kv->key)->str)
         ;  else if (show)
            {  if (hashwalk->bucket > bucketidx)
               {  bucketidx =  hashwalk->bucket
               ;  fprintf(stdout, "%d @ %s\n",bucketidx,((mcxTing*)kv->key)->str)
            ;  }
               else
               fprintf(stdout, "* %s\n", ((mcxTing*)kv->key)->str)
         ;  }
      ;  }
      ;  fprintf(stderr, "done walking hash (%d walked, %d found).\n", ct, found)
      ;  mcxHashWalkFree(&hashwalk)
   ;  }

   ;  while (a < argc)
      {
         mcxTingWrite(txts, argv[a])
      ;  kv                =  mcxHashSearch(txts, hash, MCX_DATUM_FIND)

      ;  if (kv)
         fprintf(stderr, "---> present: <%s>\n", ((mcxTing*)kv->key)->str)
      ;  else
         fprintf(stderr, "--->  absent:  <%s>\n", txts->str)

      ;  a++
   ;  }

   ;  mcxHashStats(hash)

   ;  fprintf(stderr, "---> deleting hash ..\n")
   ;  mcxHashFree(&hash, mcxTingFree_v, NULL)
   ;  fprintf(stderr, "done deleting hash.\n")
   ;  fprintf(stderr, "\n")

   ;  return 0
;  }



