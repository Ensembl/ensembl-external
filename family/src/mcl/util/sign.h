
/*
// sign.h
*/

#ifndef SIGN_H
#define SIGN_H


/*
 |    Warning: this macro cannot be used recursively.
 */

#ifdef __GNUC__
#define  _SIGN(a)                                   \
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

#define    int_SIGN(a) _SIGN((a))
#define   long_SIGN(a) _SIGN((a))
#define  float_SIGN(a) _SIGN((a))
#define double_SIGN(a) _SIGN((a))

#else  /* not __GNUC__  */
/* mimic macro-local variables using statics ... */

static int _tmp_int_sign_a;
static long _tmp_long_sign_a;
static float _tmp_float_sign_a;
static double _tmp_double_sign_a;

#define int_SIGN(a) (_tmp_int_sign_a = (a),\
                      _tmp_int_sign_a > 0 ?\
                      +1 : \
                      (_tmp_int_sign_a < 0 ? \
                        -1 : \
                         0))

#define long_SIGN(a) (_tmp_long_sign_a = (a),\
                      _tmp_long_sign_a > 0 ?\
                      +1 : \
                      (_tmp_long_sign_a < 0 ? \
                        -1 : \
                         0))

#define float_SIGN(a) (_tmp_float_sign_a = (a),\
                      _tmp_float_sign_a > 0 ?\
                      +1 : \
                      (_tmp_float_sign_a < 0 ? \
                        -1 : \
                         0))

#define double_SIGN(a) (_tmp_double_sign_a = (a),\
                      _tmp_double_sign_a > 0 ?\
                      +1 : \
                      (_tmp_double_sign_a < 0 ? \
                        -1 : \
                         0))
#endif /* not __GNUC__ */

#endif /* SIGN_H */
