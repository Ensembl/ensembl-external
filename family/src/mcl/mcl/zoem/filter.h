/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_filter_h__
#define zoem_filter_h__

#include <stdio.h>

#include "segment.h"

#include "util/txt.h"

typedef struct
{
   int            indent
;  int            n_newlines
;  int            s_spaces
;  int            doformat
;  FILE*          fp
;
}  yamFilterData    ;



yamFilterData* yamFilterDataNew
(  FILE* fp
)  ;


int   yamFilterPlain
(  yamFilterData* fp
,  mcxTing*       txt
,  int            offset
,  int            bound
)  ;


typedef int  (*fltfnc)(yamFilterData* fd, mcxTing* txt, int offset, int length);


void yamputc
(  yamFilterData*   fd
,  unsigned char  c
,  int            atcall
)  ;

void yamSpecialSet
(  unsigned int c
,  const char* str
)  ;


void yamFilterInitialize
(  int            n
)  ;

void yamFilterList
(  const char* mode
)  ;

void yamFilterSetDefaults
(  fltfnc         filter
,  yamFilterData*   fd
)  ;

fltfnc yamFilterGet
(  mcxTing* label
)  ;

yamFilterData* yamFilterGetDefaultFd
(  void
)  ;
         
fltfnc yamFilterGetDefaultFilter
(  void
)  ;

#endif

