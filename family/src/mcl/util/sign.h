
/*
// sign.h
*/

#ifndef SIGN_H
#define SIGN_H


/*
 |    Warning: this macro cannot be used recursively.
 */

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

#endif

