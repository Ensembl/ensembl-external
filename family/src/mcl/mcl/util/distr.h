/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef util_distr_h__
#define util_distr_h__

#include <stdlib.h>
#include <stdio.h>


typedef struct
{
   float*      db
;  int         N
;  float       av
;  float       dv
;  int         allocated
;  int         av_true
;  int         dv_true
;  
}  mcxDistr    ;


mcxDistr* mcxDistrNew
(  int      storage
)  ;

void mcxDistrFree
(  mcxDistr**  db
)  ;

/*
 *   Empty mcxDistribution. Does not affect memory usage.
 *   Distribution can be used again by using StoreValue etc.
*/

void mcxDistrClear
(  mcxDistr*   db
)  ;


void mcxDistrStoreValue
(  mcxDistr*   db
,  float    val
)  ;


float mcxDistrGetAverage
(  mcxDistr*   db
)  ;


float mcxDistrGetDeviation
(  mcxDistr*   db
)  ;


#endif /* UTIL_DISTR_H */

