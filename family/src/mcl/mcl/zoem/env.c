/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "env.h"
#include "util.h"
#include "segment.h"
#include "parse.h"

#include "util/txt.h"
#include "util/hash.h"


/* Note: the whole scopeStack thing is now disabled,
 * (in order to enable \${html}{\begin{vbt}}
 * so maybe it should be thrown away.
*/


static   mcxHash*    envTable_g        =  NULL;    /* environment keys  */

static   const char* openTags_g[10]    =  {  "__",  "$1",  "$2",  "$3"
                                          ,  "$4",  "$5",  "$6"
                                          ,  "$7",  "$8",  "$9"
                                          }  ;

static   const char* closeTags_g[10]   =  {  "__", "$1_", "$2_", "$3_"
                                          ,  "$4_", "$5_", "$6_"
                                          ,  "$7_", "$8_", "$9_"
                                          }  ;

static const char* n_openTags_g        =  "$0";
static const char* n_closeTags_g       =  "$0_";

static const char* digits_g[10]        =  {  "0", "1", "2", "3", "4"
                                          ,  "5", "6", "7", "8", "9"
                                          }  ;

typedef struct
{
   mcxTing           *key
;  yamSeg            *seg
;
}  envScope          ;

#define     SCOPE_STACK_SIZE  32
static      envScope    scopeStack[SCOPE_STACK_SIZE];
static      int         scopeCount_g     =  0;


void yamEnvNew
(  const char* tag
,  const char* openstr
,  const char* closestr
)
   {  mcxTing*  opentag     =  mcxTingNew(tag)
   ;  mcxTing*  closetag    =  mcxTingNew(tag)
   ;  mcxKV*   kv

   ;  mcxTingAppend(closetag, "!_")

  /*
   *  scopeStack contains mcxTing key member, which is also stored
   *  in the envTable_g. First thought I could not redefine it,
   *  right now I think it is possible, because overwriting key
   *  does not change the key pointer.
  */
   ;  if (scopeCount_g)
      {  yamExit
         ("\\env#3"
         ,  "(re)define not allowed within environment\n"
            "  now within environment <%s>"
         ,  scopeStack[scopeCount_g-1].key->str
         )
   ;  }

   ;  kv =  mcxHashSearch(opentag, envTable_g, MCX_DATUM_INSERT)
   ;  if (kv->key != opentag)
      {  fprintf(stderr, "[\\env#3] overwriting key <%s>\n",opentag->str)
      ;  mcxTingFree(&opentag)
   ;  }
   ;  if (kv->val)
      mcxTingWrite((mcxTing*) (kv->val), openstr)
   ;  else
      kv->val = mcxTingNew(openstr)

   ;  kv =  mcxHashSearch(closetag, envTable_g, MCX_DATUM_INSERT)
   ;  if (kv->key != closetag)
      mcxTingFree(&closetag)
   ;  if (kv->val)
      mcxTingWrite((mcxTing*) (kv->val), closestr)
   ;  else
      kv->val = mcxTingNew(closestr)
;  }


const char* yamEnvOpenScope
(  mcxTing* open
,  yamSeg*  seg
)
   {  char*    curly    =  strchr(open->str, '{')
   ;  int      lblen    =  curly ? curly - open->str : open->len
   ;  mcxTing* label    =  mcxTingNNew(open->str, lblen)
  /*  done with open  from here; open could be arg1_g */ 
   ;  mcxTing* data     =  curly ? mcxTingNew(curly) : NULL
   ;  yamSeg*  argseg   =  curly ? yamSegPush(NULL, data) : NULL

   ;  mcxKV* kv = mcxHashSearch(label, envTable_g, MCX_DATUM_FIND)

/*
;fprintf(stderr, "label <%s> found\n", label->str)
;fprintf(stderr, "data <%s> found\n", data ? data->str : "NONE")
*/
   ;  if (argseg)
      {  
         int i, n_args
      ;  n_args = parsescopes(argseg, 9, 0)

      ;  for (i=1;i<=n_args;i++)
         yamKeySet(openTags_g[i], key_and_args_g[i].str)

      ;  yamSegFree(&argseg)
      ;  mcxTingFree(&data)
      ;  yamKeySet(n_openTags_g, digits_g[n_args])
   ;  }
      else
      yamKeySet(n_openTags_g, digits_g[0])

   ;  if (kv)
      {  if (scopeCount_g < SCOPE_STACK_SIZE)
         {  scopeStack[scopeCount_g].seg = seg
         ;  scopeStack[scopeCount_g].key = (mcxTing*) kv->key
         ;  scopeCount_g++
         ;  return ((mcxTing*) kv->val)->str
      ;  }
         else
         yamExit
         (  "\\begin#1"
         ,  "no more than %d nested scopes allowed (at open request for <%s>)"
         ,  SCOPE_STACK_SIZE
         ,  label->str
         )
   ;  }
      else
      yamExit("\\begin#1", "env <%s> not found\n", label->str)

   ;  mcxTingFree(&label)
   ;  return NULL
;  }


const char* yamEnvCloseScope
(  const char* close
,  yamSeg*  seg
)
   {  char*    curly    =  strchr(close, '{')
   ;  int      lblen    =  curly ? curly - close : strlen(close)
   ;  mcxTing* label    =  mcxTingNNew(close, lblen)
  /*  done with close  from here; close could be arg1_g->str */ 
   ;  mcxTing* data     =  curly ? mcxTingNew(curly) : NULL
   ;  yamSeg*  argseg   =  curly ? yamSegPush(NULL, data) : NULL
   ;  mcxKV* kv

   ;  mcxTingAppend(label, "!_")

   ;  if (argseg)
      {
         int i, n_args
      ;  n_args = parsescopes(argseg, 9, 0)

      ;  for (i=1;i<=n_args;i++)
         yamKeySet(closeTags_g[i], key_and_args_g[i].str)

      ;  yamSegFree(&argseg)
      ;  mcxTingFree(&data)
      ;  yamKeySet(n_closeTags_g, digits_g[n_args])
   ;  }
      else
      yamKeySet(n_closeTags_g, digits_g[0])

   ;  scopeCount_g--

   ;  if (scopeCount_g < 0)
      {  mcxTing* env = mcxTingNNew(label->str, label->len-2)
      ;  yamExit
         (  "\\end#1"
         ,  "close request for <%s> scope that was never opened\n"
         ,  env->str
         )
   ;  }

   ;  if
      (  scopeCount_g < SCOPE_STACK_SIZE
      && (  strncmp(label->str, scopeStack[scopeCount_g].key->str, label->len-2)
      )  )
         /* || seg != scopeStack[scopeCount_g].seg
          * disabled this condition in order to allow \${html}{\begin{vbt}}
         */
      {  mcxTing* env = mcxTingNNew(label->str, label->len-2)
      ;  yamExit
         (  "\\end#1"
         ,  "close request for <%s> scope while inner scope <%s> still open"
         ,  env->str
         ,  scopeStack[scopeCount_g].key->str
         )
   ;  }

   ;  kv = mcxHashSearch(label, envTable_g, MCX_DATUM_FIND)
   ;  mcxTingFree(&label)  
   ;  return kv ? ((mcxTing*) kv->val)->str : NULL
;  }


void yamEnvInitialize
(  int n
)
   {  envTable_g           =  mcxHashNew(n, mcxTingHash, mcxTingCmp)
;  }

