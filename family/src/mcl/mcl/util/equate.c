/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdio.h>

#include "equate.h"


int fltCmp
(  const void*           f1      
,  const void*           f2
)
   {  return
      (  *((float*)f1) < *((float*)f2)
      ?  -1
      :  *((float*)f1) > *((float*)f2)
         ?  1
         :  0
      )
;  }


int fltRevCmp
(  const void*           f1      
,  const void*           f2
)
   {  return
      (  *((float*)f1) > *((float*)f2)
      ?  -1
      :  *((float*)f1) < *((float*)f2)
         ?  1
         :  0
      )
;  }


int intCmp
(  const void*           i1      
,  const void*           i2
)
   {  return ( *((int*)i1) - *((int*)i2))
;  }


int intRevCmp
(  const void*           i1      
,  const void*           i2
)
   {  return ( *((int*)i2) - *((int*)i1))
;  }


int intnCmp
(  const int*          i1
,  const int*          i2
,  int   n
)
   {  const int*              i1max =  i1+n
   ;  while (i1<i1max)
      {  if (*i1 - *i2)
            return *i1 - *i2
      ;  i1++
      ;  i2++
   ;  }
   ;  return 0
;  }


int intLt
(  const void*             i1
,  const void*             i2
)
   {  return ( *((int*) i1) < *((int*) i2) );
;  }


int intLq
(  const void*             i1
,  const void*             i2
)
   {  return ( *((int*) i1) <= *((int*) i2) );
;  }


int intGt
(  const void*             i1
,  const void*             i2
)
   {  return ( *((int*) i1) > *((int*) i2) );
;  }


int intGq
(  const void*             i1
,  const void*             i2
)
   {  return ( *((int*) i1) >= *((int*) i2) );
;  }


int fltLt
(  const void*             f1
,  const void*             f2
)
   {  return ( *((float*) f1) < *((float*) f2) );
;  }


int fltLq
(  const void*             f1
,  const void*             f2
)
   {  return ( *((float*) f1) <= *((float*) f2) );
;  }


int fltGt
(  const void*             f1
,  const void*             f2
)
   {  return ( *((float*) f1) > *((float*) f2) );
;  }


int fltGq
(  const void*             f1
,  const void*             f2
)
   {  return ( *((float*) f1) >= *((float*) f2) );
;  }



