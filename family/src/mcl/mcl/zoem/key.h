/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_key_h
#define zoem_key_h

#include "filter.h"

#include "util/txt.h"
#include "util/file.h"
#include "util/types.h"
#include "util/hash.h"


void yamScopePush
(  char type
)  ;

void yamScopePop
(  char type
)  ;

void  yamKeySet
(  const char* key
,  const char* val
)  ;

mcxTing* yamKeyDelete
(  mcxTing*  key
)  ;

mcxTing* yamKeyGet
(  mcxTing*  key
)  ;

mcxTing* yamKeyGetLocal
(  mcxTing*  key
)  ;

mcxTing* yamKeyInsert
(  mcxTing*      key
,  const char*  valstr
)  ;

void yamKeyInitialize
(  int n
)  ;

void yamKeyStats
(  void
)  ;

void yamKeyList
(  const char* mode
)  ;

#endif


