/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdio.h>

#include "entry.h"
#include "iface.h"
#include "util.h"
#include "ops.h"
#include "key.h"
#include "filter.h"

#include "util/file.h"
#include "util/txt.h"
#include "util/types.h"


int main
(  int   argc
,  char* argv[]
)  {
      mcxTing     *fbase       =  mcxTingNew("-")
   ;  mcxTing     *device      =  NULL
   ;  mcxTing     *fnout       =  NULL
   ;  mcxTing     *listees     =  mcxTingEmpty(NULL, 1)

   ;  int         a            =  1
   ;  mcxflags    flags        =  0
   ;  mcxbool     printstats   =  FALSE

   ;  while(a < argc)
      {  if (!strcmp(argv[a], "-d"))
         {  if (a++ + 1 < argc)
            {  device = mcxTingNew(argv[a])
         ;  }
            else goto arg_missing;
      ;  }
         else if (!strcmp(argv[a], "--trace"))
         {  flags |= ZOEM_TRACE_DEFAULT
      ;  }
         else if (!strcmp(argv[a], "--stats"))
         {  printstats = TRUE
      ;  }
         else if (!strcmp(argv[a], "-trace"))
         {  if (a++ + 1 < argc)
            {  unsigned int k = (unsigned int) atoi(argv[a])
            ;  if (k == -1)
               flags = ZOEM_TRACE_ALL
            ;  else if (k == -2)
               flags = ZOEM_TRACE_ALL_LONG
            ;  else
               flags |= (ZOEM_TRACE_KEYS | k)
         ;  }
            else goto arg_missing;
      ;  }
         else if (!strcmp(argv[a], "-i"))
         {  if (a++ + 1 < argc)
            {  mcxTingWrite(fbase, argv[a])
         ;  }
            else goto arg_missing;
      ;  }
         else if (!strcmp(argv[a], "-o"))
         {  if (a++ + 1 < argc)
            {  fnout = mcxTingNew(argv[a])
         ;  }
            else goto arg_missing;
      ;  }
         else if (!strcmp(argv[a], "-l"))
         {  if (a++ + 1 < argc)
            {  mcxTingAppend(listees, argv[a])
            ;  mcxTingAppend(listees, ";")
         ;  }
            else goto arg_missing;
      ;  }
         else if (!strcmp(argv[a], "-h"))
         {  help:
fprintf
(  stdout
,  "Usage: zoem -i fname[.azm] [options]\n"
   "options:\n"
   "-l {all, zoem, legend, macro, session, filter} (list, then exit)\n"
   "-o <fnout>    default output file name: <fname.device> or <fname.ozm>\n"
   "-d <device>   set zoem key \\$device to <device>)\n"
   "--stats       when done, print statistics on user symbol table (keys)\n"
   "--trace       trace all keys encountered, print (truncated) args\n"
   "-trace <k>    bit 1: set long mode, nothing is truncated\n"
   "                  2: print the name of each key encountered\n"
   "                  4: print the arguments of each key encountered\n"
   "                  8: print the definition of each key encountered\n"
   "                 16: show parsing of vararg elements\n"
   "                 32: show information about segments (zoem internals)\n"
   "                 64: trace output (redirected to stdout) \n"
   "              -1   : set all options in truncate mode\n" 
   "              -2   : set all options in long mode\n" 
)
         ;  exit(0)
      ;  }
         else if (0)
         {  arg_missing:
         ;  fprintf(stderr, "Flag %s needs argument\n", argv[argc-1])
         ;  exit(1)
      ;  }
         else
         {  goto help
      ;  }
      ;  a++
   ;  }

   ;  if (listees->len > 0)
      {  yamOpList(listees->str)
      ;  yamFilterList(listees->str)
      ;  yamKeyList(listees->str)
      ;  exit(0)
   ;  }

      if ((flags & ZOEM_TRACE_OUTPUT || flags < 0) && !fnout)
      fnout = mcxTingNew("-")

   ;  if (strstr(fbase->str, ".azm") == fbase->str + fbase->len -4)
      mcxTingDelete(fbase, -5, 4)

   ;  yamEntry
      (  fbase->str
      ,  fnout ? fnout->str : NULL
      ,  device ? device->str : NULL
      ,  yamFilterPlain
      ,  flags
      )

   ;  if (printstats)
      yamStats()

   ;  return 0
;  }


