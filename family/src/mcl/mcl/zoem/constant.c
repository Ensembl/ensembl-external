/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "constant.h"
#include "filter.h"

#include "util/hash.h"
#include "util/txt.h"

static   mcxHash*    cstTable_g        =  NULL;    /* constants         */


int   eoconstant
(  mcxTing     *txt
,  int         offset
)
   {  char* o     =  txt->str + offset
   ;  char* p     =  o
   ;  char* z     =  txt->str + txt->len

   ;  if (*p != '*')
      return(CONSTANT_NOLEFT)

   ;  while(++p < z)
      {
         if (*p == '\\' || *p == '{' || *p == '}')
         return (CONSTANT_ILLCHAR)

      ;  if (*p == '*')
         break
   ;  }
   ;  return(*p == '*' ? p-o : CONSTANT_NORIGHT)
;  }


mcxTing* yamConstantGet
(  mcxTing* key
)
   {  mcxKV*   kv =  (mcxKV*) mcxHashSearch(key, cstTable_g, MCX_DATUM_FIND)
   ;  return kv ? (mcxTing*) kv->val : NULL
;  }


mcxTing* yamConstantNew
(  mcxTing* key
,  const char* val
)
   {  mcxKV*   kv =  (mcxKV*) mcxHashSearch(key, cstTable_g, MCX_DATUM_INSERT)

   ;  if ((mcxTing*) kv->key != key)
      mcxTingWrite((mcxTing*)kv->val, val)
   ;  else
      kv->val = mcxTingNew(val)

   ;  return (mcxTing*) kv->key
;  }


void yamConstantInitialize
(  int n
)
   {  cstTable_g           =  mcxHashNew(n, mcxTingHash, mcxTingCmp)
;  }


