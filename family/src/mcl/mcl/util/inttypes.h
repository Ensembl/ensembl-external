/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef util_inttypes_h__
#define util_inttypes_h__

#include <limits.h>

#if UINT_MAX >= 4294967295
#  define UINT32 unsigned int
#else
#  define UINT32 unsigned long
#endif

typedef  UINT32         u32 ;
typedef unsigned char   u8  ;

#endif

