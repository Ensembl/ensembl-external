/*
//                      Print utilities
*/

#include "print.h"
#include "include/portab.h"

#if 1
int print_int
(  char*       str   
,  int         k     
)  {  int      s     =  0
   ;  int      l     =  0  
   
   ;  if (k < 0)
      {  *(str++) = '-'
      ;  s = 1
      ;  k = -k
   ;  }  
   
   ;  if (k >= 10)
      {  char* begin
      ;  char* end
    
      ;  do
         {  str[l++] = '0' + (k % 10)
         ;  k /= 10  
      ;  }  while (k)

      ;  k = 0
      ;  begin    =  str
      ;  end      =  str + l
      ;  while (begin < --end)
         {  short c = begin[0]
         ;  begin[0] = end[0] 
         ;  end[0] = c
         ;  begin++
   ;  }  }
      else
         str[l++] = k + '0'

   ;  str[l] = 0
   ;  return s + l
;  }
#else

int print_int
(  char*       str
,  int         k
)  {  int      l     =  0

   ;  if (k < 0)
      {  str[l++] = '-'
      ;  k = -k
   ;  }

   ;  if (k >= 10)
      {  int      d     =  10
      ;  int      e

      ;  while
         (  e = d * 10
         ,  k >= e
         )  d = e

      ;  for (;;)
         {  int   t     =  k / d
         ;  str[l++] = '0' + t
         ;  k -= t * d
         ;  if (d == 10) break
         ;  d /= 10
   ;  }  }

   ;  str[l++] = '0' + k
   ;  str[l] = 0

   ;  return l
;  }
#endif

int print_float
(  char*       str
,  double      x
)  {  int      k     =  (x += 0.005, (int)x)
   ;  int      n     =  print_int(str, k)
   ;  double   r     =  (x - k)
   ;  int      q1
   ;  int      q2

   ;  r *= 10
   ;  q1 = r
   ;  r -= q1
   ;  r *= 10
   ;  q2 = r
   ;  if (q1 || q2)
      {  str[n++] = '.'
      ;  str[n++] = '0' + q1
      ;  if (q2) str[n++] = '0' + q2
   ;  }

   ;  str[n] = 0

   ;  return n
;  }

