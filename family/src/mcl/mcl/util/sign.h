/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef mcx_sign_h__
#define mcx_sign_h__

#include "compile.h"


/* The first version cannot be used recursively.
 * I don't like this at all I think, which is why I turned it off.
*/

#if 0 && MCX_GNUC_OK
#define  SIGN(a)                                   \
         __extension__                             \
         (  {  typedef  _ta   =  (a)               \
            ;  _ta      _a    =  (a)               \
            ;  _a > 0                              \
               ?  1                                \
               :  _a < 0                           \
                  ?  -1                            \
                  :  0                             \
         ;  }                                      \
         )
#else
#define  SIGN(a)                                   \
         ((a) > 0 ? 1 : !(a) ? 0 : -1)
#endif
#endif

