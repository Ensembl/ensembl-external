/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef mcx_util_h__
#define mcx_util_h__

#include "util/types.h"


void zmTell
(  int   mode
,  const char* fmt
,  ...
)  ;


void zmNotSupported1
(  const char* who
,  int utype1
)  ;


void zmNotSupported2
(  const char* who
,  int utype1
,  int utype2
)  ;

extern mcxflags v_g;
extern int digits_g;

#define  V_STACK (1 << 0)
#define  V_HDL   (1 << 1)
#define  V_TRACE (1 << 2)

#endif

