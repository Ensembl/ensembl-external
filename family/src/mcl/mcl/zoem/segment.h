/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_segment_h__
#define zoem_segment_h__

#include "util/txt.h"

#define SEGMENT_CONSTANT 1

typedef struct yamSeg
{
   mcxTing           *txt
;  int               offset   /* consider txt only from offset onwards  */
;  int               idx      /* index of seg itself */
;  struct yamSeg*    prev
;  int               flags    /* magic/miscellaneous. hacked in later */
;
}  yamSeg            ;


yamSeg*  yamSegPush
(  yamSeg*     prev_seg
,  mcxTing      *txt
)  ;

void  yamSegFree
(  yamSeg   **segpp
)  ;

int yamStackIdx
(  void
)  ;

typedef yamSeg* (*xpnfnc)(yamSeg* seg);

#endif

