/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef nonema_float_h__
#define nonema_float_h__


float fltConstant
(  float                   flt
,  void*                   p_constant
)  ;


float fltScale
(  float                   flt
,  void*                   p_scale
)  ;


float fltPropagateMax
(  float                  flt
,  void*                   p_max
)  ;


float fltPower
(  float                   flt
,  void*                   power
)  ;


float fltAdd
(  float                  d1
,  float                  d2
)  ;


float fltSubtract
(  float                  d1
,  float                  d2
)  ;


float fltMultiply
(  float                  d1
,  float                  d2
)  ;


float fltMax
(  float                  d1
,  float                  d2
)  ;


float fltLTrueOrRTrue
(  float                  lft
,  float                  rgt
)  ;



float fltLTrueAndRFalse
(  float                  lft
,  float                  rgt
)  ;


float fltLTrueAndRTrue
(  float                  lft
,  float                  rgt
)  ;


#endif /* NONEMA_FLOAT_H */

