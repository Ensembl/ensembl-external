/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef util_alloc_h__
#define util_alloc_h__

#include <stdlib.h>
#include <stdio.h>

#include "types.h"


void* mcxAlloc
(  int               size
,  mcxOnFail         ON_FAIL
)  ;

void* mcxRealloc
(  void*             object
,  int               new_size
,  mcxOnFail         ON_FAIL
)  ;

void mcxFree
(  void*             object
)  ;

void* mcxNAlloc
(  
   int               n_elem
,  int               elem_size
,  void* (*obInit) (void *)
,  mcxOnFail         ON_FAIL
)  ;

void mcxMemDenied
(  FILE*             channel
,  const char*       requestee
,  const char*       unittype
,  int               n
)  ;


#endif /* UTIL_ALLOC_H */

