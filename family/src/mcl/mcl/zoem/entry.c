/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <string.h>
#include <stdio.h>

#include "counter.h"

#include "key.h"
#include "env.h"
#include "counter.h"
#include "ref.h"
#include "ops.h"
#include "file.h"
#include "read.h"
#include "constant.h"
#include "filter.h"
#include "key.h"
#include "digest.h"
#include "parse.h"

#include "util/txt.h"
#include "util/file.h"
#include "util/types.h"

void yamEntry
(
   const char*    fbase
,  const char*    fnout_user
,  const char*    device
,  int            filter(yamFilterData* fp, mcxTing* txt, int offset, int length)
,  mcxflags       trace_flags
)
   {
      mcxTing*  fnin       =  mcxTingNew(fbase)
   ;  mcxTing*  fnout      =  mcxTingNew(fnout_user ? fnout_user : fbase)

   ;  mcxIOstream *xfin, *xfout
   ;  mcxTing *filetxt

   ;  if (strcmp(fnin->str, "-"))
      mcxTingAppend(fnin, ".azm")
   ;  else
      fprintf(stderr, "=== reading from stdin\n")

   ;  if (strcmp(fnout->str, "-") && !fnout_user)
         mcxTingAppend(fnout, ".")
      ,  mcxTingAppend(fnout, device ? device : "ozm")
   ;  else if (!strcmp(fnout->str, "-"))
      fprintf(stderr, "=== writing to stdout\n")

   ;  xfin     =  mcxIOstreamNew(fnin->str, "r")

   ;  mcxIOstreamOpen(xfin, EXIT_ON_FAIL)
   ;  filetxt  =  yamReadFile(xfin, NULL, 0)

   ;  yamKeyInitialize     ( 200 )
   ;  yamEnvInitialize     (  20 )
   ;  yamCounterInitialize (  50 )
   ;  yamRefInitialize     (  50 )
   ;  yamOpsInitialize     ( 120 )
   ;  yamFileInitialize    (  10 )
   ;  yamConstantInitialize(  50 )
   ;  yamFilterInitialize  (  10 )

   ;  yamParseInitialize(trace_flags)
   ;
      {  int prev = yamTracingSet(0)
      ;  yamOpsMakeComposites()
      ;  yamTracingSet(prev)
   ;  }

      if (device)
      yamKeySet("$device", device)
   ;  yamKeySet("$base", fbase)

   ;  xfout = yamOutputNew(fnout->str)
   ;  yamOutputAlias("default", xfout)

   ;  yamFilterSetDefaults(filter, (yamFilterData*) xfout->ufo)

   ;  yamInputPush(xfin->fn->str, filetxt)
   ;  yamOutput(filetxt, filter, (yamFilterData*) xfout->ufo)
   ;  yamInputPop()

   ;  if (yamRefDangles())
      fprintf
      (stderr, ">>> There were %d undefined references\n", yamRefDangles())
;  }

