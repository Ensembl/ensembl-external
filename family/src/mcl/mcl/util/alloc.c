/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "alloc.h"
#include "compile.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>



void* mcxRealloc
(  void*             object
,  int               new_size
,  mcxOnFail         ON_FAIL
)
   {  void*          mblock   =  NULL
   ;  int            status   =  0
   ;
      if (new_size < 0)
      {  fprintf
         (  stderr
         ,  "[mcxRealloc PBD] negative amount [%d] requested\n"
         ,  new_size
         )
      ;  status   =  1
   ;  }
      else
      {  mblock      
         =  (object && new_size)
            ?  realloc(object, new_size)
            :     new_size
                  ?   malloc(new_size)
                  :   NULL
   ;  }

      if (new_size && (!mblock))
         mcxMemDenied(stderr, "mcxRealloc", "byte", new_size)
      ,  status   =  1
   ;
      if (status)
      {  if (ON_FAIL == SLEEP_ON_FAIL)
         {  fprintf(stderr, "[mcxRealloc] entering sleep mode\n")
         ;  while(1) sleep(1000)
      ;  }

      ;  if (ON_FAIL == EXIT_ON_FAIL)
         {  fprintf(stderr, "[mcxRealloc] entering sleep mode\n")
         ;  while(1) sleep(1000)
      ;  }
   ;  }

      return mblock
;  }


void* mcxNAlloc
(  int               n_elem
,  int               elem_size
,  void* (*obInit) (void *)
,  mcxOnFail         ON_FAIL
)
   {  char*    ob
   ;  void*    mblock   =  mcxRealloc(NULL, n_elem * elem_size, ON_FAIL)
   ;
      if (!mblock)
      return NULL
   ;
      if (obInit)
      {  ob  =  mblock

      ;  while (--n_elem >= 0)
         {  obInit(ob)
         ;  ob += elem_size
      ;  }
   ;  }

      return (mblock)
;  }


void mcxMemDenied
(  FILE*             channel
,  const char*       requestee
,  const char*       unittype
,  int               n
)
   {  fprintf
      (  channel
      ,  "[%s: Memory shortage] could not alloc [%d] instances of [%s]\n"
      ,  requestee
      ,  n
      ,  unittype
      )
;  }


void mcxFree
(  void*             object
)
   {  if (object) free(object)
;  }


my_inline void* mcxAlloc
(  int               size
,  mcxOnFail         ON_FAIL
)
   {  return mcxRealloc(NULL, size, ON_FAIL)
;  }


