/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef util_iomagic_h
#define util_iomagic_h

#include <stdlib.h>
#include <stdio.h>


int IoExpectMagicNumber
(  FILE*                f_in
,  int                  number
)  ;

void IoWriteMagicNumber
(  FILE*                f_out
,  int                  number
)  ;

int IoReadInteger
(  FILE*                f_in
)  ;

int IoWriteInteger
(  FILE*                f_out
,  int                  val
)  ;

char* IoReadString
(  FILE*                f_in
)  ;

void IoWriteString
(  FILE*                f_out
,  const char*          val
)  ;

#endif /* UTIL_IOMAGIC_H */

