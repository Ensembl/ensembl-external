/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <stdarg.h>

#include "key.h"
#include "read.h"
#include "util.h"

#include "util/txt.h"
#include "util/file.h"
#include "util/minmax.h"
#include "util/types.h"
#include "util/array.h"
#include "util/hash.h"


const char *strPredefines
=
   "\\$device        name of device (given by -d)\n"
   "\\$base          base name of entry file (given by -i)\n"
   "\\$file          name of current file\n"
;


typedef struct keyScope
{  struct keyScope*   down
;  mcxHash*           table
;
}  keyScope           ;


static   keyScope*    usrScope_g        =  NULL;    /* user keys         */
static   keyScope*    usrScope_top      =  NULL;    /* user keys         */

static   int          n_usrScopes_g        =  0;

static   keyScope*    dollarScope_g     =  NULL;    /* dollar keys       */
static   keyScope*    dollarScope_top   =  NULL;    /* dollar keys       */

static   int          n_dollarScopes_g  =  0;


void yamKeyList
(  const char* mode
)
   {  mcxbool listAll = strstr(mode, "all") != NULL
   ;  if (listAll || strstr(mode, "session"))  
      {  fprintf(stdout, "\nPredefined session variables\n%s", strPredefines)
   ;  }
;  }


void  yamKeySet
(  const char* key
,  const char* val
)
   {
      mcxTing*  keytxt   =  mcxTingNew(key)

   ;  if (yamKeyInsert(keytxt, val) != keytxt)
      {  fprintf
         (  stderr
         ,  "[yamKeySet] overwriting key <%s>\n"
         ,  keytxt->str
         )
      ;  mcxTingFree(&keytxt)
   ;  }
;  }


mcxTing* yamKeyInsert
(  mcxTing*        key
,  const char*    valstr
)
   {  keyScope* scope = *(key->str) == '$' ? dollarScope_top : usrScope_top
   ;  mcxKV* kv   =  mcxHashSearch
                     (  key
                     ,  scope->table
                     ,  MCX_DATUM_INSERT
                     )
   ;  if (!kv)
      yamExit("yamKeyInsert", "panic &or PBD cannot insert key")

   ;  else
      {  if (kv->val)
         mcxTingWrite((mcxTing*) (kv->val), valstr)
      ;  else
         kv->val     =  mcxTingNew(valstr)
   ;  }

   ;  return (mcxTing*) kv->key
;  }


mcxTing* yamKeyDelete
(  mcxTing*  key
)
   {  keyScope* scope = *(key->str) == '$' ? dollarScope_top : usrScope_top
   ;  mcxKV*   kv
            =  (mcxKV*) mcxHashSearch
               (  key
               ,  scope->table
               ,  MCX_DATUM_DELETE
               )
   ;  if (kv)
      {  mcxTing* val = (mcxTing*) kv->val
      ;  mcxTing* key = (mcxTing*) kv->key
      ;  mcxTingFree(&key)
      ;  mcxKVfree(&kv)
      ;  return val
   ;  }
      return NULL
;  }


mcxTing* yamKeyGetLocal
(  mcxTing*  key
)
   {  keyScope* scope = *(key->str) == '$' ? dollarScope_top : usrScope_top
   ;  mcxKV*   kv
      =  (mcxKV*) mcxHashSearch
         (  key
         ,  scope->table
         ,  MCX_DATUM_FIND
         )
   ;  if (kv)
      return (mcxTing*) kv->val
   ;  return NULL
;  }


mcxTing* yamKeyGet
(  mcxTing*  key
)
   {  keyScope* scope = *(key->str) == '$' ? dollarScope_top : usrScope_top

   ;  while (scope)
      {  mcxKV*   kv
         =  (mcxKV*) mcxHashSearch
            (  key
            ,  scope->table
            ,  MCX_DATUM_FIND
            )
      ;  if (kv)
         return (mcxTing*) kv->val
      ;  scope = scope->down
   ;  }
   ;  return NULL
;  }


void yamKeyInitialize
(  int n
)
   {  usrScope_g           =  mcxAlloc(sizeof(keyScope), EXIT_ON_FAIL)
   ;  usrScope_g->table    =  mcxHashNew(n, mcxTingHash, mcxTingCmp)
   ;  usrScope_g->down     =  NULL
   ;  usrScope_top         =  usrScope_g
   ;  n_usrScopes_g        =  1

   ;  dollarScope_g        =  mcxAlloc(sizeof(keyScope), EXIT_ON_FAIL)
   ;  dollarScope_g->table =  mcxHashNew(16, mcxTingHash, mcxTingCmp)
   ;  dollarScope_g->down  =  NULL
   ;  dollarScope_top      =  dollarScope_g
   ;  n_dollarScopes_g     =  1
;  }


void yamScopePush
(  char type
)
   {  keyScope* top        =  mcxAlloc(sizeof(keyScope), EXIT_ON_FAIL)
   ;  top->table           =  mcxHashNew(16, mcxTingHash, mcxTingCmp)

   ;  if (type == 'u')
      {  top->down         =  usrScope_top
      ;  usrScope_top      =  top
      ;  n_usrScopes_g++
      ;  if (n_usrScopes_g > 100)
         yamExit("yamScopePush", "no more than 100 nested user scopes allowed")
   ;  }
      else if (type == '$')
      {  top->down         =  dollarScope_top
      ;  dollarScope_top   =  top
      ;  n_dollarScopes_g++
      ;  if (n_dollarScopes_g > 100)
         yamExit("yamScopePush", "no more than 100 nested dollar scopes allowed")
   ;  }
;  }


void yamScopePop
(  char type
)
   {  keyScope* top        =  type == '$' ? dollarScope_top : usrScope_top

   ;  if (!top->down)
      yamExit
      (  "yamScopePop"
      ,  "You rascal is trying to pop the main %s scope!"
      ,  type == '$' ? "dollar" : "user"
      )

   ;  mcxHashFree(&(top->table), mcxTingFree_v, mcxTingFree_v)

   ;  if (type == 'u')
      {  usrScope_top       =  usrScope_top->down
      ;  n_usrScopes_g--
   ;  }
      else if (type == '$')
      {  dollarScope_top    =  dollarScope_top->down
      ;  n_dollarScopes_g--
   ;  }

   ;  mcxFree(top)
;  }


void yamKeyStats
(  void
)
   {  mcxHashStats(usrScope_g->table)
;  }

