/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "segment.h"
#include "util.h"
#include "iface.h"
#include "parse.h"

#include "util/txt.h"
#include "util/alloc.h"

static int stackidx_g      =  -1;


int yamStackIdx
(  void
)
   {  return stackidx_g
;  }


void yamSegFree
(  yamSeg   **segpp
)
   {
      yamSeg*   seg        =  *segpp

   ;  if (!seg)
      return

   ;  if (seg->idx && !seg->txt)
         fprintf(stderr, "PBD at seg idx <%d>\n", seg->idx)
      ,  exit(1)

   ;  if (seg->idx)                   /* the first segment txt is not freed */
      mcxTingFree(&(seg->txt))

   ;  if (!seg->prev)
      stackidx_g--

   ;  free(seg)
   ;  *segpp               =  NULL
;  }


yamSeg*  yamSegPush
(  yamSeg*  prev_seg
,  mcxTing*  txt
)
   {  yamSeg* next_seg     =  (yamSeg*)  mcxAlloc(sizeof(yamSeg), EXIT_ON_FAIL)
   ;  int idx              =  prev_seg ? prev_seg->idx + 1 : 0 

   ;  if (!prev_seg)
      stackidx_g++

   ;  if (tracing_g & ZOEM_TRACE_SEGS)
      {  fprintf(stdout, "* seg %d stack %d", idx, stackidx_g)  
      ;  traceput('[', txt)
   ;  }

   ;  if (idx > 30)
      yamExit("yamSegPush", "exceeding stacking depth 30")

   ;  next_seg->txt        =  txt
   ;  next_seg->offset     =  0
   ;  next_seg->idx        =  prev_seg ?  idx  :  0
   ;  next_seg->prev       =  prev_seg
   ;  next_seg->flags      =  0
   ;  return next_seg
;  }


