/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_curly_h__
#define zoem_curly_h__

#include "segment.h"

#include "util/txt.h"
#include "util/types.h"

#define  CURLY_NOLEFT       -1
#define  CURLY_NORIGHT      -2

/*
 *    txt->str[offset] must be '{', returns CURLY_NOLEFT if not.
 *    otherwise returns l such that txt->str[offset+l] is matching '}',
 *    or CURLY_NORIGHT if the latter does not exist.
 *    Keeps track of things in global variables.
*/

int   closingcurly
(
   mcxTing     *txt
,  int         offset
,  int*        linect
,  mcxOnFail   ON_FAIL
)  ;


void  scopeErr
(
   yamSeg      *seg
,  const char  *caller
,  int         error
)  ;

#endif

