/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_file_h__
#define zoem_file_h__

#include "filter.h"

#include "util/file.h"
#include "util/txt.h"

/*
 * The xfout arg should be the result from a yamOutputNew call.
 * It has a yamFilterData object as its ufo member.
*/
void yamOutputAlias
(  const char*    str
,  mcxIOstream*   xfout
)  ;
mcxIOstream* yamOutputNew
(  const char*  fname
)  ;


/*
 * This module maintains a stack of input files. The files are parsed
 * depth-first.
*/

mcxstatus yamInputPush
(  const char* str
,  const mcxTing* txt
)  ;
mcxstatus yamInputPop
(  void
)  ;
void yamInputIncrLc
(  const mcxTing* txt
,  int   d
)  ;
int yamInputGetLc
(  void
)  ;
const char* yamInputGetName
(  void
)  ;
mcxbool yamInputCanPush
(  void
)  ;

void yamFileInitialize
(  int   n
)  ;

#endif

