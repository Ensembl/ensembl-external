/*
// alloc.h
*/

#ifndef UTIL_ALLOC_H
#define UTIL_ALLOC_H

#include <stdlib.h>
#include <stdio.h>
#include "util/types.h"


void* rqAlloc
(  int               size
,  mcxOnFail         ON_FAIL
)  ;

void* rqRealloc
(  void*             object
,  int               new_size
,  mcxOnFail         ON_FAIL
)  ;

void rqFree
(  void*             object
)  ;

void mcxMemDenied
(  FILE*             channel
,  const char*       requestee
,  const char*       unittype
,  int               n
)  ;


extern __inline__ void* rqAlloc
(  int               size
,  mcxOnFail         ON_FAIL
)  {  
      return rqRealloc(NULL, size, ON_FAIL)
;  }


#endif /* UTIL_ALLOC_H */

