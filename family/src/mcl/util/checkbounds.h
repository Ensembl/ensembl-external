
#ifndef CHECKBOUNDS_H
#define CHECKBOUNDS_H        

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

mcxTxt* checkBoundsRange
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

