/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef util_link_h__
#define util_link_h__

#include "types.h"
#include "alloc.h"


typedef struct
{
   void*       key
;  void*       val
;
}  mcxKV       ;


mcxKV* mcxKVnew
(  void *key
,  void *val
)  ;


void mcxKVfree
(  mcxKV**     kvpp
)  ;


typedef struct mcxHLink
{  
   struct mcxHLink*  next
;  mcxKV*            kv
;
}  mcxHLink          ;


mcxHLink* mcxHLinkNew
(  mcxHLink*         link
,  void*             ob
)  ;


void mcxHLinkFree
(  mcxHLink          **linkpp
)  ;


void* mcxHLinkInit
(  void              *link
)  ;


int mcxHLinkSize
(  mcxHLink*         link
)  ;


mcxHLink* mcxHLinkSearch
(  
   mcxHLink*         link
,  void*             ob
,  int               (*cmp)(const void* a, const void *b)
,  mcxmode           ACTION
)  ;


/*
 * This is not a user space function, it is used e.g. by hash.c
 * when it doubles its number of buckets (and reuses existing links).
 * The link must be non-NULL with a non-NULL kv member.
*/
mcxHLink* mcxHLinkInsert
(  mcxHLink*         base
,  mcxHLink*         new
,  int               (*cmp)(const void* a, const void *b)
)  ;


#endif

