/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_env_h__
#define zoem_env_h__

#include "segment.h"

#include "util/txt.h"

void yamEnvNew
(  const char* tag
,  const char* openstr
,  const char* closestr
)  ;

const char* yamEnvOpenScope
(  mcxTing* key
,  yamSeg*  seg
)  ;

const char* yamEnvCloseScope
(  const char* str
,  yamSeg*  seg
)  ;

void yamEnvInitialize
(  int n
)  ;

#endif

