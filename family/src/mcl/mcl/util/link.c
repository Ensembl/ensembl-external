/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "link.h"
#include "types.h"
#include "compile.h"
#include "alloc.h"
#include "pool.h"


static MP* linkPool_g   =  NULL;
static MP* kvPool_g     =  NULL;


mcxKV* mcxKVnew
(  void *key
,  void *val
)
   {
#if MCX_UTIL_THREADED
      mcxKV*   kv       =  (mcxKV*) mcxAlloc(sizeof(mcxKV), EXIT_ON_FAIL)
#else
      mcxKV*   kv
   ;  if (!kvPool_g)
      kvPool_g          =  mp_init(4096, MP_EXPONENTIAL, sizeof(mcxKV), 0)
   ;  kv                =  (mcxKV*) mp_alloc(kvPool_g)
#endif
   ;  kv->key           =  key
   ;  kv->val           =  val
   ;  return kv
;  }


void mcxKVfree
(  mcxKV**  kvpp
)
   {  if (*kvpp)
      {
#if MCX_UTIL_THREADED
         mcxFree(*kvpp)
#else
         mp_free(kvPool_g, *kvpp)
#endif
      ;  *kvpp = NULL
   ;  }
;  }


void* mcxHLinkInit
(  void          *link
)
   {  if ( !link)
      {
#if MCX_UTIL_THREADED
         link           =  (mcxHLink*) mcxAlloc(sizeof(mcxHLink), EXIT_ON_FAIL)
#else
         if (!linkPool_g)
         linkPool_g = mp_init(4096, MP_EXPONENTIAL, sizeof(mcxHLink), 0)
      ;  link = (mcxHLink*) mp_alloc(linkPool_g)
#endif
   ;  }
   ;  ((mcxHLink*) link)->kv       =  NULL
   ;  ((mcxHLink*) link)->next     =  NULL
   ;  return(link)
;  }


int mcxHLinkSize
(  mcxHLink*        link
)
   {  int   s        =  0
   ;  while((link = link->next))
      s++
   ;  return(s)
;  }


void mcxHLinkFree
(  mcxHLink        **linkpp
)
   {  if (*linkpp)
      {
#if MCX_UTIL_THREADED
         mcxFree(*linkpp)
#else
         mp_free(linkPool_g, *linkpp)
#endif
      ;  *linkpp = NULL
   ;  }
;  }


mcxHLink* mcxHLinkNew
(  mcxHLink*         link
,  void*             ob
)
   {
      if (!link)
      link           =  mcxHLinkInit(NULL)
   ;  link->kv       =  mcxKVnew(ob, NULL)
   ;  link->next     =  NULL
   ;  return link
;  }


/*
 *    The first link is the handle to the list and will never be deleted.
 *    It's kv member is never inspected.
*/

mcxHLink* mcxHLinkSearch
(  mcxHLink*         link
,  void*             ob
,  int               (*cmp)(const void* a, const void *b)
,  mcxmode           ACTION
)
   {  int      c           =  1
   ;  mcxHLink* prev       =  link

   ;  while
      (  (link =  prev->next)
      &&  link->kv
      &&  link->kv->key
      && (c    =  cmp(ob, link->kv->key)) > 0
      ) 
      prev = link
   ;

      if (!c)
      {
         if (ACTION == MCX_DATUM_DELETE)
         {
            mcxHLink* next =  link->next
         ;  prev->next     =  next
      ;  }
      ;  return link
   ;  }

      else if (!link || c < 0)
      {
         if (ACTION == MCX_DATUM_FIND || ACTION == MCX_DATUM_DELETE)
         return NULL

      ;  else if (ACTION == MCX_DATUM_INSERT)
         {
            mcxHLink* new  =  mcxHLinkNew(NULL, ob)
         ;  prev->next     =  new
         ;  new->next      =  link
         ;  return new
      ;  }
   ;  }

   ;  return NULL
;  }


mcxHLink* mcxHLinkInsert
(  mcxHLink*          this        /* initally base link */
,  mcxHLink*          new
,  int               (*cmp)(const void* a, const void *b)
)
   {  int         c    =  1
   ;  mcxHLink*   prev =  this
   ;  mcxKV*      kv

   ;  if (!new || !new->kv)
      return NULL

   ;  kv = new->kv

   ;  while
      (   (this =  prev->next)
      &&  this->kv          /* safety check */
      &&  this->kv->key
      &&  (c = cmp(new->kv->key, this->kv->key)) > 0
      ) 
      prev = this
   ;

      if (!c)               /* equally comparing key present */
      return this
   ;  else if (!this || c < 0)
      {
         prev->next     =  new
      ;  new->next      =  this
      ;  return new
   ;  }

   ;  return NULL
;  }


