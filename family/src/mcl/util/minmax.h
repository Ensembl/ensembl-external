
/*
// minmax.h          Inline min/max functions
*/

#ifndef MINMAX_H
#define MINMAX_H

#ifdef __GNUC__

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
#define   int_MIN(a,b) MIN((a),(b))
#define float_MIN(a,b) MIN((a),(b))
#define double_MIN(a,b) MIN((a),(b))
#define   int_MAX(a,b) MIN((a),(b))
#define float_MAX(a,b) MIN((a),(b))
#define double_MAX(a,b) MIN((a),(b))

#else  /* not __GNUC__ */

/* mimic macro-local variables using statics ... */
static int _tmp_int_minmax_a, _tmp_int_minmax_b;
static long _tmp_long_minmax_a, _tmp_long_minmax_b;
static float _tmp_float_minmax_a, _tmp_float_minmax_b;
static double _tmp_double_minmax_a, _tmp_double_minmax_b;

#define int_MIN(a,b) (_tmp_int_minmax_a = (a),\
                      _tmp_int_minmax_b = (b),\
                      _tmp_int_minmax_a < _tmp_int_minmax_b ? \
                      _tmp_int_minmax_a \
                       : _tmp_int_minmax_b)

#define long_MIN(a,b) (_tmp_long_minmax_a = (a),\
                      _tmp_long_minmax_b = (b),\
                      _tmp_long_minmax_a < _tmp_long_minmax_b ? \
                      _tmp_long_minmax_a \
                       : _tmp_long_minmax_b)

#define float_MIN(a,b) (_tmp_float_minmax_a = (a),\
                      _tmp_float_minmax_b = (b),\
                      _tmp_float_minmax_a < _tmp_float_minmax_b ? \
                      _tmp_float_minmax_a \
                       : _tmp_float_minmax_b)

#define double_MIN(a,b) (_tmp_double_minmax_a = (a),\
                      _tmp_double_minmax_b = (b),\
                      _tmp_double_minmax_a < _tmp_double_minmax_b ? \
                      _tmp_double_minmax_a \
                       : _tmp_double_minmax_b)


#define int_MAX(a,b) (_tmp_int_minmax_a = (a),\
                      _tmp_int_minmax_b = (b),\
                      _tmp_int_minmax_a > _tmp_int_minmax_b ? \
                      _tmp_int_minmax_a \
                       : _tmp_int_minmax_b)

#define long_MAX(a,b) (_tmp_long_minmax_a = (a),\
                      _tmp_long_minmax_b = (b),\
                      _tmp_long_minmax_a > _tmp_long_minmax_b ? \
                      _tmp_long_minmax_a \
                       : _tmp_long_minmax_b)

#define float_MAX(a,b) (_tmp_float_minmax_a = (a),\
                      _tmp_float_minmax_b = (b),\
                      _tmp_float_minmax_a > _tmp_float_minmax_b ? \
                      _tmp_float_minmax_a \
                       : _tmp_float_minmax_b)

#define double_MAX(a,b) (_tmp_double_minmax_a = (a),\
                      _tmp_double_minmax_b = (b),\
                      _tmp_double_minmax_a > _tmp_double_minmax_b ? \
                      _tmp_double_minmax_a \
                       : _tmp_double_minmax_b)


#endif /* not __GNUC__ */

#endif   /* MINMAX_H */

