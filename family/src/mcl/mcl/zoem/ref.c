/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "ref.h"

#include "util/txt.h"
#include "util/hash.h"
#include "util/types.h"

static   mcxHash*    refTable_g        =  NULL;    /* references        */
static      int         dangles_g      =  0;


typedef struct refNode_t
{
   mcxTing        *anchor
;  mcxTing        *level
;  mcxTing        *type
;  mcxTing        *counter
;  mcxTing        *caption
;  mcxTing        *misc
;
}  refNode_t      ;


refNode_p refNodeNew
(  const char* anchor
,  const char* level
,  const char* type
,  const char* counter
,  const char* caption
,  const char* misc
)
   {
      refNode_p node    =  mcxAlloc(sizeof(refNode_t), EXIT_ON_FAIL)
   ;  node->anchor      =  mcxTingNew(anchor)
   ;  node->level       =  mcxTingNew(level)
   ;  node->type        =  mcxTingNew(type)
   ;  node->counter     =  mcxTingNew(counter)
   ;  node->caption     =  mcxTingNew(caption)
   ;  node->misc        =  mcxTingNew(misc)
   ;  return node
;  }


void refNodeFree
(  refNode_p*   nodepp
)
   {  refNode_p node    =  *nodepp
   ;  if (node)
      {
         mcxTingFree(&(node->anchor))
      ;  mcxTingFree(&(node->type))
      ;  mcxTingFree(&(node->level))
      ;  mcxTingFree(&(node->counter))
      ;  mcxTingFree(&(node->caption))
      ;  mcxTingFree(&(node->misc))
      ;  mcxFree(&node)
      ;  *nodepp        =  NULL
   ;  }
;  }


mcxbool yamRefNew
(  const char* anchor
,  const char* level
,  const char* type
,  const char* counter
,  const char* caption
,  const char* misc
)
   {
      mcxTing* anchortxt   =  mcxTingNew(anchor)
   ;  mcxKV* kv            =  mcxHashSearch
                              (anchortxt, refTable_g, MCX_DATUM_INSERT)
   ;  if (kv->key != anchortxt)
      {  mcxTingFree(&anchortxt)
      ;  return FALSE
   ;  }
      else
      kv->val = refNodeNew(anchor, level, type, counter, caption, misc)

   ;  return TRUE
;  }


const char*  yamRefMember
(  mcxTing* key
,  char c
)  {
      mcxKV*  kv     =  (mcxKV*) mcxHashSearch(key, refTable_g, MCX_DATUM_FIND)
   ;  refNode_p ref  =  kv ? (refNode_p) kv->val : NULL
   ;  const char* member

   ;  if (!ref)
      {  dangles_g++
      ;  switch(c)
         {  case 'n' : member = "__ctr__" ;  break
         ;  case 't' : member = "__typ__" ;  break
         ;  case 'l' : member = "__lev__" ;  break
         ;  case 'c' : member = "__cap__" ;  break
         ;  case 'm' : member = "__msc__" ;  break
         ;  default  : member = NULL
      ;  }
   ;  }
      else
      {  switch(c)
         {  case 'n' : member = ref->counter->str  ;  break
         ;  case 't' : member = ref->type->str     ;  break
         ;  case 'l' : member = ref->level->str    ;  break
         ;  case 'c' : member = ref->caption->str  ;  break
         ;  case 'm' : member = ref->misc->str     ;  break
         ;  default  : member = NULL
      ;  }
   ;  }
      return member
;  }


refNode_p yamRefGet
(  mcxTing*  key
)  {
      mcxKV*  kv = (mcxKV*) mcxHashSearch(key, refTable_g, MCX_DATUM_FIND)
   ;  if (!kv)
      dangles_g++
   ;  return kv ? (refNode_p) kv->val : NULL
;  }


void yamRefInitialize
(  int n
)
   {  refTable_g           =  mcxHashNew(n, mcxTingHash, mcxTingCmp)
;  }


int yamRefDangles
(  void
)
   {  return dangles_g
;  }

