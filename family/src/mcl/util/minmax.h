
/*
// minmax.h          Inline min/max functions
*/

#ifndef MINMAX_H
#define MINMAX_H


/*
 *    Warning: these macros cannot be nested, except that
 *    MAX(MIN(),..) and MIN(MAX(),..) are possible.
 */

#define  MAX(a,b)                                  \
         __extension__                             \
         (  {   typedef _ta=(a)  ,  _tb=(b)        \
            ;   _ta _a=(a)       ;  _tb _b = (b)   \
            ;   _a > _b ? _a : _b                  \
         ;  }                                      \
         )

#define  MIN(c,d)                                  \
         __extension__                             \
         (  {   typedef _tc=(c),  _td=(d)          \
            ;   _tc _c=(c)       ;  _td _d = (d)   \
            ;   _c < _d ? _c : _d                  \
         ;  }                                      \
         )


#endif   /* MINMAX_H */

