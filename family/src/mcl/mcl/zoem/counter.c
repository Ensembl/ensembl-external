/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "counter.h"

#include "util/hash.h"
#include "util/txt.h"
#include "util/types.h"


static   mcxHash*    ctrTable_g        =  NULL;    /* counters          */


/*
 *    The return value of yamGetCtr should never be freed by caller
*/ 

mcxTing* yamCtrGet
(  mcxTing*  key
)  {
      mcxKV*   kv
      =  (mcxKV*) mcxHashSearch(key, ctrTable_g, MCX_DATUM_FIND)

   ;  return kv ? (mcxTing*) kv->val : NULL
;  }


void yamCounterInitialize
(  int   n
)
   {  ctrTable_g           =  mcxHashNew(n, mcxTingHash, mcxTingCmp)
;  }


void yamCtrWrite
(  mcxTing* ctr
,  const char* str
)
   {  mcxTingWrite(ctr, str)
;  }


void yamCtrSet
(  mcxTing* ctr
,  int   c
)
   {  char     cstr[20]
   ;  sprintf(cstr, "%d", c)
   ;  mcxTingWrite(ctr, cstr)
;  }


mcxTing* yamCtrMake
(  mcxTing* label
)
   {
      mcxKV* kv =  mcxHashSearch(label, ctrTable_g, MCX_DATUM_INSERT)

   ;  if (kv->key != label)
      fprintf(stderr, "___ PBD counter exists (and fix this design pls\n")
   ;  else
      kv->val =  mcxTingNew("0")

   ;  return kv->val
;  }


