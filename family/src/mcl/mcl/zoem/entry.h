/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_entry_h__
#define zoem_entry_h__

#include "filter.h"

#include "util/txt.h"
#include "util/types.h"

/*
 * fbase always gets the '.azm' appended without check.
 * If fnout != NULL it will be the output name, otherwise the output
 * name is constructed from fbase and device.
*/

void yamEntry
(
   const char* fbase
,  const char* fnout
,  const char* device
,  int         filter(yamFilterData* fp, mcxTing* txt, int offset, int length)
,  mcxflags    flags
)  ;

#endif

