/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef checkbounds_h__
#define checkbounds_h__

#include "txt.h"

extern int checkBoundsPrintDigits;
extern char* flagCheckBoundsCaller;

void flagCheckBounds
(  const char*    flag
,  const char*    type
,  void*          var
,  int            (*lftRlt) (const void*, const void*)
,  void*          lftBound
,  int            (*rgtRlt) (const void*, const void*)
,  void*          rgtBound
)  ;

mcxTing* checkBoundsRange
(  const char*    type
,  void*          var
,  int            (*lftRlt) (const void*, const void*)
,  void*          lftBound
,  int            (*rgtRlt) (const void*, const void*)
,  void*          rgtBound
)  ;

int checkBounds
(  const char*    type
,  void*          var
,  int            (*lftRlt) (const void*, const void*)
,  void*          lftBound
,  int            (*rgtRlt) (const void*, const void*)
,  void*          rgtBound
)  ;

#endif /* CHECKBOUNDS_H */

