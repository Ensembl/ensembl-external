/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_read_h__
#define zoem_read_h__

#include "util/file.h"
#include "util/hash.h"


mcxTing*  yamReadFile
(  mcxIOstream    *xf
,  mcxTing        *filetxt
,  int            masking
)  ;

mcxbool yamInlineFile
(  mcxTing* fname
,  mcxTing* filetxt
)  ;

#endif

