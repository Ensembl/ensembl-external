/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef util_parse_h__
#define util_parse_h__

#include <stdio.h>

#include "file.h"
#include "types.h"

mcxstatus mcxFpParse
(  mcxIOstream*         xf
,  const char*          str
,  const char*          caller
,  mcxOnFail            ON_FAIL
)  ;

float mcxFpParseNumber
(  mcxIOstream*         xf
,  const char*          caller
)  ;


/*
 *    Returns next non-white space char,
 *    which is pushed back onto stream after reading.
*/

int mcxFpSkipSpace
(  mcxIOstream*         xf
,  const char*          caller
)  ;

mcxstatus mcxFpFindInFile
(  mcxIOstream*         xf
,  const char*          str
,  const char*          caller
,  mcxOnFail            ON_FAIL
)  ;


#endif   /* UTIL_PARSE_H */


