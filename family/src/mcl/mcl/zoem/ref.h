/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_ref_h__
#define zoem_ref_h__

#include "util/txt.h"
#include "util/types.h"


typedef struct refNode_t* refNode_p;

/*
 * Returns whether the ref was *not* already present.
*/
mcxbool yamRefNew
(  const char* anchor
,  const char* level
,  const char* type
,  const char* counter
,  const char* caption
,  const char* misc
)  ;


refNode_p yamRefGet
(  mcxTing*  key
)  ;

/*
 * If key is not found as ref, returns replacement string if second arg
 * is ok. (one of nltcm).
 * It returns NULL if and only if second arg is not [nltcm].
*/
const char*  yamRefMember
(  mcxTing*  key
,  char c
)  ;

int yamRefDangles
(  void
)  ;

void yamRefInitialize
(  int n
)  ;

#endif

