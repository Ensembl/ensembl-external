/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_parse_h__
#define zoem_parse_h__

#include "segment.h"

#include "util/txt.h"


extern mcxTing      key_and_args_g[];

extern mcxTing*     key_g;

extern mcxTing*     arg1_g;
extern mcxTing*     arg2_g;
extern mcxTing*     arg3_g;
extern mcxTing*     arg4_g;
extern mcxTing*     arg5_g;
extern mcxTing*     arg6_g;
extern mcxTing*     arg7_g;
extern mcxTing*     arg8_g;
extern mcxTing*     arg9_g;
extern mcxTing*     arg10_g;

extern int          n_args_g;
extern int          tracing_g;

yamSeg*  dokey
(  yamSeg *seg
)  ;


int   findkey
(  yamSeg*  seg
)  ;


int   parsescopes
(  yamSeg*  seg
,  int      n
,  int      delta
)  ;


int  parsekey
(  yamSeg    *line
)  ;


yamSeg*   expandkey
(  yamSeg*   seg
)  ;


int checkusrsig
(  char* p
,  int   len
,  int*  k
)  ;

int checkusrname
(  char* p
,  int   len
)  ;

int checkusrtag
(  char* p
,  int   len
,  int*  k
)  ;

int checkblock
(  mcxTing* txt
,  int len
)  ;


int seescope
(  char* p
,  int   len
)  ;


void yamParseInitialize
(  int   traceflags
)  ;

int yamTracingSet
(  int  traceflags
)  ;

void traceputlines
(  const char* s
,  int len
)  ;

#endif

