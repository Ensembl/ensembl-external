/*
// alloc.c
*/

#include "util/alloc.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>



void* rqRealloc
(  void*             object
,  int               new_size
,  mcxOnFail         ON_FAIL
)  {  
      void*          mblock   =  NULL
   ;  int            status   =  0

   ;  if (new_size < 0)
      {  fprintf
         (  stderr
         ,  "[rqRealloc PBD] negative amount [%d] requested\n"
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

   ;  if (new_size && (!mblock))
         mcxMemDenied(stderr, "rqRealloc", "byte", new_size)
      ,  status   =  1

   ;  if (status)
      {  if (ON_FAIL == SLEEP_ON_FAIL)
         {  fprintf(stderr, "[rqRealloc] entering sleep mode\n")
         ;  while(1) sleep(1000)
      ;  }

      ;  if (ON_FAIL == EXIT_ON_FAIL)
         {  fprintf(stderr, "[rqRealloc] entering sleep mode\n")
         ;  while(1) sleep(1000)
      ;  }
   ;  }

   ;  return mblock
;  }


void mcxMemDenied
(  FILE*             channel
,  const char*       requestee
,  const char*       unittype
,  int               n
)  {
      fprintf
      (  channel
      ,  "[%s: Memory shortage] could not alloc [%d] instances of [%s]\n"
      ,  requestee
      ,  n
      ,  unittype
      )
;  }


void rqFree
(  void*             object
)  {
   ;  if (object) free(object)
;  }

