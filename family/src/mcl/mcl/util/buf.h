/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef util_buf_h__
#define util_buf_h__

#include <stdlib.h>

#include "alloc.h"
#include "minmax.h"
#include "types.h"


typedef struct
{  
   void*       mempptr
;  int         size
;  int         n
;  int         n_alloc
;  float       factor
;  mcxbool     bFinalized
;
}  mcxBuf      ;


/*    
 *    *mempptr should be peekable; NULL or valid memory pointer. 
*/

void mcxBufInit
(  mcxBuf*     buf
,  void*       mempptr
,  int         size
,  int         n
)  ;


/*
 *    Extends the buffer by n_request unitialized chunks and returns a pointer
 *    to this space. It is the caller's responsibility to treat this space
 *    consistently. The counter buf->n is increased by n_request.
*/


void* mcxBufExtend
(  mcxBuf*     buf
,  int         n_request
)  ;


/*
 *    Make superfluous memory reclaimable by system,
 *    prepare for discarding buf (but not *(buf->memptr)!)
*/


int mcxBufFinalize
(  mcxBuf*  buf
)  ;


/*
 *    Make buffer refer to a new variable. Size cannot be changed,
 *    so variable should be of same type as before.
*/

void mcxBufReset
(  mcxBuf*  buf
,  void*    mempptr
)  ;


#endif

