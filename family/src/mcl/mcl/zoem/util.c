/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdarg.h>

#include "segment.h"
#include "key.h"
#include "ops.h"
#include "file.h"
#include "parse.h"

#include "util/txt.h"
#include "util/hash.h"
#include "util/types.h"
#include "util/file.h"


void yamStats
(  void
)
   {
      fprintf(stdout, "Zoem user table stats\n")
   ;  yamKeyStats()
   ;  fprintf(stdout, "Zoem primitive table stats\n")
   ;  yamOpsStats()
;  }


void  yamExit
(  const char  *caller
,  const char  *fmt
,  ...
)
   {
      va_list  args

   ;  fprintf
      (  stderr
      ,  "\n"
         "___ error after [%s] (around input line %d in %s)\n"
         "___ last key seen is [%s]\n"
      ,  caller
      ,  yamInputGetLc()
      ,  yamInputGetName()
      ,  key_g->str
      )

   ;  va_start(args, fmt)
   ;  fprintf(stderr, "___ ")
   ;  vfprintf(stderr, fmt, args)
   ;  fprintf(stderr, "\n")
   ;  va_end(args)

   ;  exit(1)
;  }


