/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdlib.h>
#include <stdio.h>
#include <time.h>

#include "perm.h"

#include "util/alloc.h"
#include "util/types.h"


Pmt*  pmtNew
(  int      N
)
   {  Pmt*     pnew

   ;  if (N < 0)
         fprintf(stderr, "[pmtNew] negative request [%d]\n", N)
      ,  exit(1)

   ;  if (N == 0)
      fprintf(stderr, "[pmtNew warning] zero request [0]\n")

   ;  pnew           =     (Pmt *) mcxAlloc(sizeof(Pmt), EXIT_ON_FAIL)

   ;  pnew->n        =     N
   ;  pnew->next     =     ilNew(N, NULL, -1)
   ;  pnew->i_cycle  =     NULL
   ;  pnew->n_cycle  =     0
   ;  pnew->cycles   =     NULL

   ;  return pnew
;  }


void pmtFree
(  Pmt      **pmt
)
   {  Pmt  *this  =  *pmt
   ;  int      i

   ;  if (this->next != (void*) 0)
      {  ilFree(&(this->next))
   ;  }

   ;  if (this->n_cycle)
      {  for (i=0;i<this->n_cycle;i++)
         {  mcxFree((this->cycles+i)->list)
      ;  }

      ;  mcxFree(this->cycles)
   ;  }

      if (this->i_cycle != (void*) 0)
      {  ilFree(&(this->i_cycle))
   ;  }

   ;  mcxFree(*pmt)
   ;  *pmt = (void*) 0
;  }


Pmt*  pmtRand
(  int      N
)
   {  Pmt*     pmt         =  pmtNew(N)

   ;  pmt->next            =  ilRandPermutation(0, N)
   ;  pmtGetCycles(pmt)
   ;  return pmt
;  }


Ilist*  pmtGetCycleSizes
(  Pmt*     pmt
)
   {  Ilist  *il            =  ilNew(pmt->n_cycle, (void*) 0, -1)
   ;  int   i  
   ;  for (i=0;i<pmt->n_cycle;i++)
      {  *(il->list+i) = (pmt->cycles+i)->n
   ;  }
   ;  return il  
;  }


Pmt*  pmtGetCycles
(  Pmt*     pmt
)
   {  int   l_uncl, i
   ;  int   N              =  pmt->n
   ;  int   n_cycle        =  0              /* index of current cycle     */
   ;  Ilist*   i_cycle
   ;  Ilist*   il_next     =  pmt->next
   ;  Ilist*   cyclebuf    =  ilNew(N, (void*) 0, -1)

   ;  pmt->i_cycle         =  ilNew(N, (void*) 0, -1)
   ;  i_cycle              =  pmt->i_cycle

                                             /* over-allocate cycle structs */
   ;  pmt->cycles          =  (Ilist*) mcxAlloc
                              (  N * sizeof(Ilist)
                              ,  RETURN_ON_FAIL
                              )

   ;  if (N && !pmt->cycles)
         mcxMemDenied(stderr, "pmtGetCycles", "Ilist", N)
      ,  exit(1)

   ;  for(i=0;i<N;i++)
      ilInit(pmt->cycles+i)
                                             /* initialize cycle structs   */

   ;  l_uncl   =  0
                                             /* least unclassified node    */

   ;  while (l_uncl < N)
      {  int   next                 =  *(il_next->list + l_uncl)

                                             /*    index of current cycle,
                                              *    buffer initialization,
                                              *    buffer size.
                                              */
      ;  *(i_cycle->list+l_uncl)    =  n_cycle
      ;  *(cyclebuf->list+0)        =  l_uncl
      ;  cyclebuf->n                =  1

      ;  if (next < 0 || next >= N)
         {  fprintf
            (  stderr
            ,  "[pmtGetCycles fatal] index %d out of bounds [0, %d)\n"
            ,  next
            ,  N
            )
         ;  exit(1)
      ;  }

      ;  while (*(i_cycle->list+next) < 0)    /* not in previous cycle      */
         {
            *(cyclebuf->list + cyclebuf->n) = next
         ;  cyclebuf->n++
         ;  *(i_cycle->list+next)       =  n_cycle

         ;  next = *(il_next->list+next)

         ;  if (next < 0 || next >= N)
            {  fprintf
               (  stderr
               ,  "[pmtGetCycles fatal] index %d out of bound [0, %d)\n"
               ,  next
               ,  N
               )
            ;  exit(1)
         ;  }
      ;  }

                                             /* current cycle completed */
         if (*(i_cycle->list+next) == n_cycle)
         {  
            ilStore(pmt->cycles+n_cycle, cyclebuf->list, cyclebuf->n)
         ;  n_cycle++
      ;  }
                                             /*    closing element belongs to
                                              *    other cycle
                                              */
         else if (*(i_cycle->list+next) != n_cycle)
         {  
            fprintf(stderr, "[pmtGetCycles fatal] permutation not 1-1\n")
         ;  ilPrint(il_next, "")
         ;  exit(1)
      ;  }

      ;  while (*(i_cycle->list+l_uncl) >= 0 && l_uncl < N)  
            l_uncl++
   ;  }

   ;  ilFree(&cyclebuf)
   ;  pmt->n_cycle = n_cycle
   ;  return pmt
;  }


void  pmtPrint
(  Pmt*     pmt
)
   {  int   i
   ;  fprintf(stdout, "Dimension %d Cycles %d\n", pmt->n, pmt->n_cycle)
   ;  ilPrint(pmt->next, "bijection")

   ;  for (i=0;i<pmt->n_cycle;i++)
      ilPrint(pmt->cycles+i, "cycle")
;  }



