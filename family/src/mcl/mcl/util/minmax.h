/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef minmax_h__
#define minmax_h__

#include "compile.h"

#if MCX_GNUC_OK && MCX_UTIL_TYPED_MINMAX
/* these buggers do not nest, which I dislike */
#define MAX(x,y)                                   \
   (  {  const typeof(x) _x = x;                   \
         const typeof(y) _y = y;                   \
         (void) (&_x == &_y);                      \
         _x > _y ? _x : _y;                        \
   }  )
#define MIN(x,y)                                   \
   (  {  const typeof(x) _x = x;                   \
         const typeof(y) _y = y;                   \
         (void) (&_x == &_y);                      \
         _x < _y ? _x : _y;                        \
   }  )
#else
/* The usual brain-damaged min and max, which do nest though. */
#define  MAX(a,b)  ((a)>(b) ? (a) : (b))
#define  MIN(a,b)  ((a)<(b) ? (a) : (b))
#endif

#endif   /* MINMAX_H */

