/*
//
*/

#ifndef UTIL_PARSE_H
#define UTIL_PARSE_H

#include <stdio.h>
#include "util/file.h"
#include "util/types.h"

mcxstatus mcxFpParse
(  mcxIOstream*         xf
,  const char*          str
,  const char*          caller
,  mcxOnFail            ON_FAIL
)  ;

/*
*/
float mcxFpParseNumber
(  mcxIOstream*         xf
,  const char*          caller
)  ;

/*
//    Returns next non-white space char,
//    which is pushed back onto stream after reading.
*/

int mcxFpSkipSpace
(  mcxIOstream*         xf
,  const char*          caller
)  ;

/*
*/
mcxstatus mcxFpFindInFile
(  mcxIOstream*         xf
,  const char*          str
,  const char*          caller
,  mcxOnFail            ON_FAIL
)  ;



#endif   /* UTIL_PARSE_H */


