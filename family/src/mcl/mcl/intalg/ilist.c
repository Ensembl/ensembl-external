/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdarg.h>
#include <string.h>

#include "ilist.h"
#include "perm.h"

#include "util/compile.h"
#include "util/buf.h"
#include "util/alloc.h"
#include "util/types.h"
#include "util/equate.h"
#include "util/iomagic.h"


void voidIlAlert
(  const char*       msg
)  ;


int ilWriteFile
(  const Ilist*   src_il
,  FILE*          f_out
)
   {  int   k  =  IoWriteInteger(f_out, src_il->n)
   ;  k       +=  fwrite(src_il->list, sizeof(int), src_il->n, f_out)
   ;  if (k != src_il->n + 1)
      {  fprintf
         (  stderr
         ,  "[ilWriteFile fatal] wrote %d, should be %d\n"
         ,  k
         ,  src_il->n + 1
         )
      ;  exit(1)
   ;  }
   ;  return 0
;  }


Ilist*   ilVA
(  Ilist*   il
,  int      k
,  ...
)
   {  va_list     ap
   ;  mcxBuf      ibuf
   ;  int         i

   ;  if (!il)
      il    =  ilInit(NULL)

   ;  mcxBufInit(&ibuf, &(il->list), sizeof(int), 8)

   ;  {  va_start(ap, k)

      ;  for (i=0;i<k;i++)
         {  int  *xp =  mcxBufExtend(&ibuf, 1)
         ;  *xp      =  va_arg(ap, int)
      ;  }

      ;  va_end(ap)
   ;  }

   ;  il->n =  mcxBufFinalize(&ibuf)
   ;  return(il)
;  }


Ilist*   ilComplete
(  Ilist*   il
,  int      n
)
   {  int   i

   ;  il = ilInstantiate(il, n, NULL, -1)

   ;  for (i=0;i<n;i++)
      *(il->list+i)  =  i

   ;  return(il)
;  }


Ilist*    ilReadFile
(  Ilist*         dst_il
,  FILE*          f_in
)
   {  int n    =  IoReadInteger(f_in)
   ;  if (!n)
      {  fprintf(stderr, "[ilReadFile warning] empty list\n")
   ;  }
   ;  dst_il = ilInstantiate(dst_il, n, NULL, -1)
   ;  fread(dst_il->list, sizeof(int), n, f_in)
   ;  return dst_il
;  }


Ilist*   ilInit
(  Ilist*   il
)
   {  if (!il)
      il = (Ilist *) mcxAlloc(sizeof(Ilist), EXIT_ON_FAIL)

   ;  il->list =  NULL
   ;  il->n    =  0

   ;  return il
;  }


Ilist*   ilInstantiate
(  Ilist*   dst_il
,  int      n
,  int*     ints
,  int      c
)
   {  if (!dst_il) dst_il = ilInit(NULL)

   ;  dst_il->list   =  (int*) mcxRealloc
                        (  dst_il->list
                        ,  n * sizeof(int)
                        ,  RETURN_ON_FAIL
                        )

   ;  if (n && !dst_il->list)
         mcxMemDenied(stderr, "ilInstantiate", "int", n)
      ,  exit(1)

   ;  if (n && ints)
      {  memcpy(dst_il->list, ints, n * sizeof(int))
   ;  }
      else
      {  int i    =  0
                                    /* c is used only if ints == NULL */
      ;  while (i < n) *(dst_il->list+i++) = c
   ;  }

   ;  dst_il->n     =  n
   ;  return dst_il
;  }


Ilist*   ilStore
(  Ilist*   dst
,  int*     ints
,  int      n
)
   {  if (!dst)
      {  
         dst         =  ilNew(n, ints, -1)
      ;  return dst
   ;  }
      else
      {  
         int i       =  0
      ;  dst->list   =  (int*) mcxRealloc
                        (  dst->list
                        ,  n * sizeof(int)
                        ,  RETURN_ON_FAIL
                        )

      ;  if (n && !dst->list)
            mcxMemDenied(stderr, "ilStore", "int", n)
         ,  exit(1)

      ;  while (i<n)
         *(dst->list+i) = *(ints+i), i++

      ;  dst->n      =  n
   ;  }
   ;  return dst
;  }


Ilist*   ilCon
(  Ilist*   dst
,  int*     list
,  int      n
)
   {  if (!dst)
      return ilNew(n, list, -1)

   ;  dst->list      =  (int*) mcxRealloc
                        (  dst->list
                        ,  (dst->n + n) * sizeof(int)
                        ,  RETURN_ON_FAIL
                        )

   ;  if ((dst->n + n) && !dst->list)
         mcxMemDenied(stderr, "ilCon", "int", (dst->n + n))
      ,  exit(1)

   ;  if (0)
      {  int   i
      ;  for (i=0;i<n;i++)
         {  *(dst->list+dst->n-n+i) = *(list+i)
      ;  }
   ;  }
      else
      {  memcpy((dst->list)+dst->n, list, n * sizeof(int))
   ;  }

   ;  dst->n    = dst->n + n

   ;  return dst
;  }


void     ilResize
(  Ilist*   il
,  int      n
)
   {  if (!il) voidIlAlert("ilResize")
   ;  {  
         int   i  =  il->n

      ;  if (n > il->n)
         {  
            il->list =  (int*) mcxRealloc
                        (  il->list
                        ,  n * sizeof(int)
                        ,  RETURN_ON_FAIL
                        )

         ;  if (n && !il->list)
               mcxMemDenied(stderr, "ilResize", "int", n)
            ,  exit(1)
      ;  }

      ;  while (i<n)
         {  *(il->list+i) = 0
      ;  }

      ;  il->n    =  n
   ;  }
;  }


Ilist*   ilInvert
(  Ilist*   src
)  {  int      i
   ;  Ilist*   inv
   ;  if (!src) voidIlAlert("ilInvert")

   ;  inv      =  ilNew(src->n, NULL, -1)
   ;  for (i=0;i<src->n;i++)
      {  int   next        =  *(src->list+i)
      ;  if (next < 0 || next >= src->n)
         {  fprintf
            (  stderr
            ,  "[ilInvert] index %d out of range (0, %d>\n"
            ,  next
            ,  src->n
            )
         ;  exit(1)
      ;  }
      ;  *(inv->list+next) =  i
   ;  }
   ;  return inv
;  }


int   ilIsMonotone
(  Ilist*   src
,  int      gradient
,  int      min_diff
)
   {  int   i
   ;  if (!src) voidIlAlert("ilIsMonotone")

   ;  for(i=1;i<src->n;i++)
      {  if ( (*(src->list+i) - *(src->list+i-1)) * gradient < min_diff)
            return 0
   ;  }
   ;  return 1
;  }


int   ilIsOneOne
(  Ilist*   src
)
   {  int   d
   ;  Ilist*   inv   =  ilInvert(src)
   ;  Ilist*   invv  =  ilInvert(inv)
   ;  d = intnCmp(src->list, invv->list, src->n)
   ;  ilFree(&inv)
   ;  ilFree(&invv)
   ;  return d ? 0 : 1
;  }


void   ilAccumulate
(  Ilist*   il
)  {  int   i     =  0
   ;  int   prev  =  0
   ;  if (!il) voidIlAlert("ilIsMonotone")

   ;  for (i=0;i<il->n;i++)
      {  *(il->list+i) +=  prev
      ;  prev           =  *(il->list+i)
   ;  }
;  }
      

int ilSum
(  Ilist*   il
)
   {  int   sum   =  0
   ;  int   i
   ;  if (!il) voidIlAlert("ilSum")

   ;  i          =  il->n
   ;  while(--i >= 0)
      {  sum += *(il->list+i)
   ;  }
   ;  return sum
;  }


void ilPrint
(  Ilist*   il
,  const char msg[]
)
   {  int      i
   ;  if (!il) voidIlAlert("ilPrint")

   ;  for (i=0;i<il->n;i++)
      {  printf(" %-8d", *(il->list+i))
      ;  if (((i+1) % 8) == 0)
            printf("\n")
   ;  }
   ;  if (i%8 != 0) printf("\n")
   ;  fprintf  (  stdout, "[ilPrint end%s%s: size is %d]\n"
               ,  msg[0] ? ":" : ""
               ,  msg
               ,  il->n
               )
   ;  fprintf(stdout, " size is %d\n\n", il->n)
;  }

                                    /* translate an integer sequence    */
                                    /* should be generalized via Unary  */
void     ilTranslate
(  Ilist*   il
,  int      dist
)
   {  int   i
   ;  if (!il) voidIlAlert("ilTranslate")

   ;  i          =  il->n
   ;  if (!dist) return
   ;  while (--i >= 0)
      {  *(il->list+i) += dist
   ;  }
;  }


void ilFree
(  Ilist**  ilp
)
   {  if (*ilp)
      {  if ((*ilp)->list)  mcxFree((*ilp)->list)
      ;  mcxFree(*ilp)
   ;  }
   ;  *ilp  =  (void*) 0
;  }

                              /* shuffle an interval of integers        */
Ilist*     ilRandPermutation
(  int      lb
,  int      rb
)
   {  int      w        =     rb - lb
   ;  int      *ip, i
   ;  Ilist*   il

   ;  if (w < 0)
      {  fprintf  (  stderr
                  ,  "[ilRandPermutation error] bounds [%d, %d] reversed\n"
                  ,  lb
                  ,  rb
                  )
      ;  exit(1)
   ;  }

   ;  if (w == 0)
      {  fprintf  (  stderr
                  ,  "[ilRandPermutation warning] bounds [%d, %d] equal\n"
                  ,  lb
                  ,  rb
                  )
   ;  }

   ;  il    =  ilNew(w, (void*) 0, -1)
   ;  ip    =  il->list

   ;  for (i=0;i<w;i++) *(ip+i) = i       /* initialize translated interval */

   ;  for (i=w-1;i>=0;i--)                /* shuffle interval               */
      {  int l       =  (int) (rand() % (i+1))
      ;  int draw    =  *(ip+l)
      ;  *(ip+l)     =  *(ip+i)
      ;  *(ip+i)     =  draw
   ;  }

   ;  ilTranslate(il, lb)        /* translate interval to correct offset   */
   ;  return il
;  }


/*
 *   currently not in use.
 *   note the solution in genMatrix:
 *   draw for each number separately.
*/


Ilist* ilLottery
(  int         lb
,  int         rb
,  float       p
,  int         times
)
   {  int      i
   ;  int      w        =  rb - lb
   ;  int      hits
   ;  long     prev, bar, r

   ;  Ilist*   il       =  ilNew(0, NULL, 0)
   ;  mcxBuf   ibuf

   ;  if (w <= 0 || rb < 1)
      {  fprintf
         (  stderr
         ,  "[ilDraw warning] interval [%d, %d> ill defined\n"
         ,  lb
         ,  rb
         )
      ;  exit(1)
   ;  }

   ;  if (p < 0.0) p = 0.0
   ;  if (p > 1.0) p = 1.0

   ;  mcxBufInit(&ibuf, &(il->list), sizeof(int), times)

   ;  hits     =  0
   ;  prev     =  rand()
   ;  bar      =  p * LONG_MAX
   
   ;  for (i=0;i<times;i++)
      {  
         if ((r = rand() % INT_MAX) < bar)
         {  
            int*  jptr  =  (int*) mcxBufExtend(&ibuf, 1)
         ;  *jptr       =  lb + ((r + prev) % w)
      ;  }
      ;  prev = r % w
   ;  }

   ;  il->n    =  mcxBufFinalize(&ibuf)
   ;  return il
;  }


                           /* create random partitions at grid--level   */
Ilist*  ilGridRandPartitionSizes
(  int      w
,  int      gridsize
)
   {  int      n_blocks, i
   ;  Ilist*   il_all   =     (void*) 0
   ;  Ilist*   il_one   =     (void*) 0


   ;  if (gridsize > w)
         return ilRandPartitionSizes(w)

   ;  n_blocks          =     w / gridsize

   ;  il_all            =     ilNew(0, (void*) 0, -1)

   ;  for (i=0;i<n_blocks;i++)
      {
      ;  il_one         =     ilRandPartitionSizes(gridsize)
      ;  ilCon(il_all, il_one->list, il_one->n)
      ;  ilFree(&il_one)
   ;  }

   ;  if (n_blocks * gridsize < w)
      {  il_one         =     ilRandPartitionSizes(w - n_blocks * gridsize)
      ;  ilCon(il_all, il_one->list, il_one->n)
      ;  ilFree(&il_one)
   ;  }

   ;  ilSort(il_all)
   ;  return il_all
;  }


                                    /* create random partition */
Ilist* ilRandPartitionSizes
(  int      w
)
   {  Pmt*     pmt
   ;  Ilist*   il

   ;  if (w <= 0)
      {  fprintf(stderr, "[ilRandPartition warning] width argument %d nonpositive\n", w)
      ;  return   ilNew(0, (void*) 0, -1)
   ;  }

   ;  pmt      =  pmtRand(w)
   ;  il       =  pmtGetCycleSizes(pmt)
   ;  pmtFree(&pmt)
   ;  ilSort(il)

   ;  return il
;  }


float ilDeviation
(  Ilist*   il
)
   {  float    dev   =  0.0
   ;  float    av    =  ilAverage(il)
   ;  int   i
   ;  if (il->n == 0)
         return 0.0

   ;  for (i=0;i<il->n;i++)
      {  dev += ((float ) (*(il->list+i)-av)) * (*(il->list+i)-av)
   ;  }
   ;  return sqrt(dev/il->n)
;  }


float ilAverage
(  Ilist*   il
)
   {  float    d  =  (float ) ilSum(il)
   ;  return il->n ? d /  il->n : 0.0
;  }


float ilCenter
(  Ilist*   il
)
   {  int   sum   =  ilSum(il)
   ;  return   sum ? (float ) ilSqum (il) / (float) sum : 0.0 
;  }


int ilSqum
(  Ilist*   il
)
   {  int   sum   =  0
   ;  int   i     =  il->n
   ;  while(--i >= 0)
      {  sum += *(il->list+i) * *(il->list+i)
   ;  }
   ;  return sum
;  }


int ilSelectRltBar
(  Ilist*   il
,  int      i1
,  int      i2
,  int      (*rlt1)(const void*, const void*)
,  int      (*rlt2)(const void*, const void*)
,  int      onlyCount
)
   {  int   i
   ;  int   j     =  0

   ;  for(i=0;i<il->n;i++)
      {  if
         (  (!rlt1 || rlt1(il->list+i, &i1))
         && (!rlt2 || rlt2(il->list+i, &i2))
         )
         {  
            if (!onlyCount && j<i)
            *(il->list+j)   =  *(il->list+i)

         ;  j++
      ;  }
   ;  }
   ;  if (!onlyCount && (i-j))
      ilResize(il, j)

   ;  return j
;  }


void voidIlAlert
(  const char*       msg
)
   {  fprintf(stderr, "[%s] void ilist argument\n", msg)
   ;  exit(1)
;  }


void  ilSort
(  Ilist*   il
)
   {  if (!il)
      {  fprintf(stderr, "[ilSort] warning: uninitialized list\n")
      ;  return
   ;  }
      if (il->list)
         qsort(il->list, il->n, sizeof(int), intCmp)
;  }


void  ilRevSort
(  Ilist*   il
)
   {  if (il->list)
      qsort(il->list, il->n, sizeof(int), intRevCmp)
;  }


my_inline int ilSelectLtBar
(  Ilist*   il
,  int      i
)  {  return ilSelectRltBar(il, i,  0, intLt, NULL, 0)
;  }


my_inline int   ilIsDescending
(  Ilist*   src
)  {  return ilIsMonotone(src, -1, 1)
;  }


my_inline int   ilIsNonAscending
(  Ilist*   src
)  {  return ilIsMonotone(src, -1, 0)
;  }


my_inline int   ilIsNonDescending
(  Ilist*   src
)  {  return ilIsMonotone(src, 1, 0)
;  }


my_inline int   ilIsAscending
(  Ilist*   src
)  {  return ilIsMonotone(src, 1, 1)
;  }


my_inline int ilSelectGqBar
(  Ilist*   il
,  int      i
)  {  return ilSelectRltBar(il, i,  0, intGq, NULL, 0)
;  }


my_inline Ilist* ilNew
(  int   n
,  int*  ints
,  int   c
)  {  Ilist* il =  ilInstantiate(NULL, n, ints, c)
   ;  return il
;  }


my_inline int ilCountLtBar
(  Ilist*   il
,  int      i
)  {  return ilSelectRltBar(il, i,  0, intLt, NULL, 1)
;  }


