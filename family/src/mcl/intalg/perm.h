
#ifndef INTALG_PERM__
#define INTALG_PERM__

#include "intalg/ilist.h"


typedef struct
{  int      n              /* the size of the permutation               */
;  Ilist*   next           /* the image of a number                     */
;  int      n_cycle           
;  Ilist*   i_cycle        /* the cycle index of a number, may be NULL  */
;  Ilist*   cycles         /* decomposition into cycles; may be NULL    */
;  }  
   Pmt   
;


Pmt*  pmtNew
(  int      N
)  ;

void pmtFree
(  Pmt**       pmt
)  ;

Pmt*  pmtRand
(  int      N
)  ;

Pmt*  pmtGetCycles
(  Pmt*     pmt
)  ;

Ilist*  pmtGetCycleSizes
(  Pmt*     pmt
)  ;

void  pmtPrint
(  Pmt*     pmt
)  ;

#endif

