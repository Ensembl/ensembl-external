/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/


#ifndef util_compile_h__
#define util_compile_h__

#define MCX_UTIL_THREADED     1
#define MCX_UTIL_TYPED_MINMAX 0

#ifndef __GNUC__
#  define   my_inline
#  define   MCX_GNUC_OK       0
#else
/* don't put anything below just yet,
 * my_inline concerns functions that used to be declared with 'extern inline'
 * in header files; they have now moved to the source files.
*/
#  define   my_inline
#  define   MCX_GNUC_OK       1
#endif

#endif

