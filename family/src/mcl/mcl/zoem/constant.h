/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_constant_h__
#define zoem_constant_h__

#include "util/txt.h"

#define  CONSTANT_NOLEFT    -1
#define  CONSTANT_NORIGHT   -2
#define  CONSTANT_ILLCHAR   -3

int  eoconstant
(  mcxTing      *txt
,  int         offset
)  ;

void yamConstantInitialize
(  int n
)  ;

mcxTing* yamConstantGet
(  mcxTing* label
)  ;

mcxTing* yamConstantNew
(  mcxTing* key
,  const char* val
)  ;

#endif

