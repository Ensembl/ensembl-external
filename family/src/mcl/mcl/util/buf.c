/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdio.h>
#include <stdlib.h>

#include "buf.h"
#include "minmax.h"


void mcxBufInit
(  mcxBuf*  buf
,  void*    mempptr
,  int      size
,  int      n_alloc
)
   {  char **caccess    =     (char **) mempptr
   ;  buf->mempptr      =     mempptr

   ;  *caccess          =     (void *) mcxRealloc
                              (  *caccess
                              ,  n_alloc * size
                              ,  RETURN_ON_FAIL
                              )

   ;  if (n_alloc && !*caccess)
         mcxMemDenied(stderr, "mcxBufInit", "char", n_alloc * size)
      ,  exit(1)

   ;  buf->size         =     size
   ;  buf->n_alloc      =     n_alloc
   ;  buf->n            =     0
   ;  buf->bFinalized   =     0
   ;  buf->factor       =     1.41
;  }


void* mcxBufExtend
(  mcxBuf*  buf
,  int      n_request
)
   {  int   oldsize     =     buf->n
   ;  char **caccess    =     (char **) buf->mempptr

   ;  if (buf->bFinalized)
      fprintf
      (  stderr
      ,  "[mcxBufExtend PBD warning] Extending finalized buffer\n"
      )

   ;  if (buf->n_alloc < buf->n + n_request)
      {
         int n_new    
         =  MAX
            (  (int) (buf->n_alloc * buf->factor + 8)
            ,  (int) (buf->n + n_request)
            )

      ;  *caccess   
         =  (void *) mcxRealloc
                     (  *caccess
                     ,  n_new * buf->size
                     ,  RETURN_ON_FAIL
                     )

      ;  if (n_new && !*caccess)
            mcxMemDenied(stderr,"mcxBufExtend","char",buf->n*buf->size)
         ,  exit(1)

      ;  buf->n_alloc   =     n_new
   ;  }

      buf->n     +=     n_request
   ;  return   *caccess + (oldsize * buf->size)
;  }


int mcxBufFinalize
(  mcxBuf*    buf
)
   {  char **caccess    =  (char **) buf->mempptr

   ;  if (buf->bFinalized)
      fprintf
      (  stderr
      ,  "[mcxBufFinalize PBD warning] Buffer already finalized!\n"
      )
   ;  else
      buf->bFinalized   =  1

   ;  *caccess          =  (void *) mcxRealloc
                           (  *caccess
                           ,  buf->n * buf->size
                           ,  RETURN_ON_FAIL
                           )

   ;  if (buf->n && !*caccess)
         mcxMemDenied
         (stderr, "mcxBufFinalize", "char", buf->n * buf->size)
      ,  exit(1)

   ;  buf->n_alloc      =  buf->n

   ;  return buf->n
;  }


void mcxBufReset
(  mcxBuf*     buf
,  void*       mempptr
)
   {  if (!buf->bFinalized)
      fprintf
      (  stderr
      ,  "[mcxBufReset PBD warning] Buffer not finalized!\n"
      )

   ;  buf->mempptr      =     mempptr
   ;  buf->n            =     0
   ;  buf->n_alloc      =     0
   ;  buf->bFinalized   =     0
;  }


