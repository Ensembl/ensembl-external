
#ifndef util_link__
#define util_link__

#include "util/types.h"
#include "util/alloc.h"


typedef struct mcxLink
{  
   struct mcxLink*   next
;  void*             ob
;
}  mcxLink           ;


void mcxLinkFree
(  void             *linkpp
)  ;


void mcxLinkRelease
(  void            *link
)  ;


void* mcxLinkInit
(  void              *link
)  ;


int mcxLinkSize
(  mcxLink*        link
)  ;


mcxLink* mcxLinkNew
(  mcxLink*          link
,  void*             ob
)  ;


mcxLink* mcxLinkSearch
(  
   mcxLink*          link
,  void*             ob
,  int               (*cmp)(const void* a, const void *b)
,  mcxmode           ACTION
)  ;


#endif

