/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <math.h>

#include "floatops.h"


float fltConstant
(  float                   d
,  void*                   arg
)  {  return d ? (*((float*)arg)) : 0
;  }

float fltScale
(  float                   d
,  void*                   arg
)  {  return d * (*((float*)arg))
;  }

float fltPower
(  float                   flt
,  void                    *power
)  {  return pow(flt, *((float*) power))
;  }


float fltPropagateMax
(  float                   d
,  void*                   arg
)  {  if (d > ((float*)arg)[0])
         ((float*)arg)[0] = d

   ;  return d
;  }


float fltAdd
(  float                  d1
,  float                  d2
)  {  return d1 + d2
;  }

float fltSubtract
(  float                  d1
,  float                  d2
)  {  return d1 - d2
;  }

float fltMultiply
(  float                  d1
,  float                  d2
)  {  return d1 * d2
;  }

float fltMax
(  float                  d1
,  float                  d2
)  {  return (d1 > d2) ? d1 : d2
;  }

float fltLTrueOrRTrue
(  float                  lft
,  float                  rgt
)  {  if (lft) return lft
   ;  else if (rgt) return rgt
   ;  else return 0.0
;  }

float fltLTrueAndRFalse
(  float                  lft
,  float                  rgt
)  {  if (rgt) return 0.0
   ;  else if (lft) return lft
   ;  else return 0.0
;  }

float fltLTrueAndRTrue
(  float                  lft
,  float                  rgt
)  {  if (lft && rgt) return lft
   ;  else return 0.0
;  }

