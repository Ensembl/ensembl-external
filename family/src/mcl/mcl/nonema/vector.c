/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdlib.h>
#include <math.h>
#include <float.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>

#include "vector.h"
#include "iface.h"

#include "util/compile.h"
#include "util/alloc.h"
#include "util/types.h"
#include "util/array.h"
#include "util/minmax.h"
#include "util/sign.h"



void mclVectorAlert
(  const char*          caller
)
   {  fprintf(stderr, "[%s] void vector argument\n", caller)
   ;  return
;  }


mcxstatus mclVectorCheck
(  const mclVector*        vec
,  int                     range
,  mcxOnFail               ON_FAIL
)  
   {  mclIvp*  ivp      =  vec->ivps
   ;  mclIvp*  ivpmax   =  vec->ivps+vec->n_ivps
   ;  int      last     =  -1
   ;  int      status   =  STATUS_OK

   ;  if (!vec)
      {  fprintf
         (  stderr
         ,  "[mclVectorCheck deadly] NULL vector\n"
         )
      ;  if (ON_FAIL == RETURN_ON_FAIL)
         return STATUS_FAIL
      ;  else
         exit(1)
   ;  }

      if (!vec->ivps && vec->n_ivps)
      {  fprintf
         (  stderr
         ,  "[mclVectorCheck deadly] NULL ivps and [%d] n_ivps\n"
         ,  vec->n_ivps
         )
      ;  if (ON_FAIL == RETURN_ON_FAIL)
         return STATUS_FAIL
      ;  else
         exit(1)
   ;  }
         
   ;  while (ivp<ivpmax)
      {  if (ivp->idx < last)
         {  fprintf
            (  stderr
            ,  "[mclVectorCheck deadly] index descend [%d, %d] at ivp [%d]\n"
            ,  last, ivp->idx, (ivp - vec->ivps)
            )
         ;  status      =  STATUS_FAIL
         ;  break
      ;  }
         if (ivp->idx == last)
         {  fprintf
            (  stderr
            ,  "[mclVectorCheck deadly] repeated index [%d] at ivp [%d]\n"
            ,  ivp->idx, (ivp - vec->ivps)
            )
         ;  status      =  STATUS_FAIL
         ;  break
      ;  }
         if (ivp->val < 0.0)
         {  fprintf
            (  stderr
            ,  "[mclVectorCheck deadly] negative value [%f] at ivp [%d]\n"
            ,  ivp->val, (ivp - vec->ivps)
            )
         ;  status      =  STATUS_FAIL
         ;  break
      ;  }
         if (0 && ivp->val == 0.0)
         {  fprintf
            (  stderr
            ,  "[mclVectorCheck unusual] zero value [%f] at ivp [%d]\n"
            ,  ivp->val, (ivp - vec->ivps)
            )  ;
         }

      ;  last = ivp->idx
      ;  ivp++
   ;  }

   ;  if (last >= range)
      {  fprintf
         (  stderr
         ,  "[mclVectorCheck deadly] index [%d] tops range [%d]"
            " at ivp [%d]\n"
         ,  last, range, (ivp - 1 - vec->ivps)
         )
      ;  status      =  STATUS_FAIL
   ;  }

   ;  if ((status  == STATUS_FAIL) && (ON_FAIL == EXIT_ON_FAIL))
      exit(1)

   ;  return status
;  }


mclVector* mclVectorInit
(  mclVector*              vec
)  
   {  if (!vec)
      vec = (mclVector*) mcxAlloc(sizeof(mclVector), EXIT_ON_FAIL)

   ;  vec->ivps   =  NULL
   ;  vec->n_ivps =  0
   ;  return vec
;  }


mclVector* mclVectorInstantiate
(  mclVector*                 dst_vec
,  int                        new_n_ivps
,  const mclIvp*              src_ivps
)  
   {  mclIvp*                 new_ivps

   ;  if (!dst_vec)                                   /* create */
      dst_vec = mclVectorInit(NULL)

   ;  dst_vec->ivps
      =  
         (mclIvp*) mcxRealloc
         (  dst_vec->ivps
         ,  new_n_ivps * sizeof(mclIvp)
         ,  RETURN_ON_FAIL
         )

   ;  if (new_n_ivps && !dst_vec->ivps)
         mcxMemDenied(stderr, "mclVectorInstantiate", "mclIvp", new_n_ivps)
      ,  exit(1)

   ;  new_ivps       =  dst_vec->ivps

   ;  if (!src_ivps)                                  /* resize */
      {  
         int   k     =  dst_vec->n_ivps
      ;  while (k < new_n_ivps)
         {  
            mclIvpInit(new_ivps + k)
         ;  k++
      ;  }
   ;  }

      else if (src_ivps && new_n_ivps)                /* copy   */
      memcpy(new_ivps, src_ivps, new_n_ivps * sizeof(mclIvp))

   ;  dst_vec->n_ivps      =  new_n_ivps
   ;  return dst_vec
;  }


void mclVectorFree
(  mclVector**                 vecpp
)  
   {  if (*vecpp)
      {
         mcxFree((*vecpp)->ivps)
      ;  mcxFree(*vecpp)
      ;  (*vecpp) = NULL
   ;  }
;  }


void mclVectorSort
(  mclVector*              vec
,  int                     (*cmp)(const void*, const void*)
)  
   {  if (!vec)
         mclVectorAlert("mclVectorSort")
      ,  exit(1)

   ;  if (!cmp)
      cmp = mclIvpIdxCmp

   ;  if (vec->n_ivps)
      qsort(vec->ivps, vec->n_ivps, sizeof(mclIvp), cmp)
;  }


void mclVectorUniqueIdx
(  mclVector*              vec
)  
   {  if (!vec)
         mclVectorAlert("mclVectorUniqueIdx")
      ,  exit(1)

   ;  if (vec->n_ivps)
      vec->n_ivps
      =  mcxDedup
      (  vec->ivps
      ,  vec->n_ivps
      ,  sizeof(mclIvp)
      ,  mclIvpIdxCmp
      ,  mclIvpMergeDiscard
      )
;  }


float mclVectorKBar
(  mclVector   *vec
,  int         k
,  float       ignore            /*    ignore elements relative to this  */
,  int         mode
)  
   {  int      bEven       =  (k+1) % 2
   ;  int      n_inserted  =  0
   ;  float    ans         =  0.0

   ;  mclIvp*  vecIvp      =  vec->ivps
   ;  mclIvp*  vecMaxIvp   =  vecIvp + vec->n_ivps

   ;  float    *heap       =  (float*) mcxAlloc
                              (  (k+bEven)*sizeof(float)
                              ,  EXIT_ON_FAIL
                              )

   ;  if (k >= vec->n_ivps)
      return(-1.0)

   ;  if (mode == KBAR_SELECT_LARGE)
      {
         if (bEven)
         *(heap+k)         =  FLT_MAX

      ;  while(vecIvp < vecMaxIvp)
         {
            float val      =  vecIvp->val

         ;  if (val >= ignore)
            {
         ;  }
            else if (n_inserted < k)
            {
               int   i     =  n_inserted

            ;  while (i != 0 && *(heap+(i-1)/2) > val)
               {
                 *(heap+i) =  *(heap+(i-1)/2)
               ;  i        =  (i-1)/2
            ;  }

            ;  *(heap+i)   =  val
            ;  n_inserted++
         ;  }
            else if (val > *heap)
            {
               int   root  =  0
            ;  int   d

            ;  while((d = 2*root+1) < k)
               {
                  if (*(heap+d) > *(heap+d+1))
                  d++

               ;  if (val > *(heap+d))
                  {  *(heap+root)   =  *(heap+d)
                  ;  root           =  d
               ;  }
                  else
                  {  break
               ;  }
               }
               *(heap+root)         =  val
         ;  }

            vecIvp++
      ;  }
   ;  }

      else if (mode == KBAR_SELECT_SMALL)
      {
         if (bEven)
         *(heap+k)         =  -FLT_MAX

      ;  while(vecIvp < vecMaxIvp)
         {
            float val      =  vecIvp->val

         ;  if (val < ignore)
            {
         ;  }
            else if (n_inserted < k)
            {
               int   i     =  n_inserted

            ;  while (i != 0 && *(heap+(i-1)/2) < val)
               {
                 *(heap+i) =  *(heap+(i-1)/2)
               ;  i        =  (i-1)/2
            ;  }

            ;  *(heap+i)   =  val
            ;  n_inserted++
         ;  }
            else if (val < *heap)
            {
               int   root  =  0
            ;  int   d

            ;  while((d = 2*root+1) < k)
               {
                  if (*(heap+d) < *(heap+d+1))
                  d++

               ;  if (val < *(heap+d))
                  {  *(heap+root)   =  *(heap+d)
                  ;  root           =  d
               ;  }
                  else
                  {  break
               ;  }
               }
               *(heap+root)         =  val
         ;  }
            vecIvp++
      ;  }
   ;  }
      else
      {
         fprintf(stderr, "[mclVectorKBar PBD] invalid mode\n")
      ;  exit(1)
   ;  }

   ;  ans   =  *heap
   ;  mcxFree(heap)

   ;  return ans
;  }


float mclVectorSelectGqBar
(  mclVector*        vec
,  float             fbar
)
   {  mclIvp         *newIvp, *oldIvp, *maxIvp
   ;  float          mass  =  0.0      

   ;  if (!vec)
         mclVectorAlert("mclVectorSelectGqBar")
      ,  exit(1)

   ;  newIvp               =  vec->ivps
   ;  oldIvp               =  newIvp
   ;  maxIvp               =  newIvp+vec->n_ivps

   ;  while (oldIvp < maxIvp)
      {  
         if (oldIvp->val >= fbar)
         {  
            mass += (newIvp->val = oldIvp->val)
         ;  (newIvp++)->idx = oldIvp->idx
      ;  }
      ;  oldIvp++
   ;  }

   ;  mclVectorResize(vec, newIvp - (vec->ivps))
   ;  return mass
;  }


float mclVectorSelectNeedsBar
(  mclVector*              vec
,  int                     dest_n_ivps
)  
   {  int   i
   ;  float smaller, larger

   ;  if (dest_n_ivps >= vec->n_ivps)   return 0.0
   ;  if (dest_n_ivps < 0)
      {  fprintf
         (  stderr
         ,  "[mclVectorSelectNeedsBar] warning: negative argument\n"
         )
      ;  return (mclVectorMaxValue(vec) + 1)
   ;  }

   ;  mclVectorSort(vec, mclIvpValRevCmp)

   ;  larger           =  (vec->ivps+dest_n_ivps)->val
   ;  smaller          =  larger
   ;  i                =  dest_n_ivps+1

   ;  while (i<vec->n_ivps)
      {  smaller       =  (vec->ivps+i)->val
      ;  if (smaller < larger)   break
      ;  i++
   ;  }
   ;  mclVectorSort(vec, mclIvpIdxCmp)

   ;  return 0.5 * (smaller + larger)
;  }



void mclVectorUnary
(  mclVector*              vec
,  float                   (*operation)(float val, void* arg)
,  void*                   arg
)  
   {  int                  n_ivps
   ;  mclIvp               *src_ivp, *dst_ivp

   ;  if (!vec)
         mclVectorAlert("mclVectorUnary")
      ,  exit(1)

   ;  n_ivps                  =  vec->n_ivps
   ;  src_ivp                 =  vec->ivps
   ;  dst_ivp                 =  vec->ivps
   
   ;  while (--n_ivps >= 0)
      {  float val            =  operation(src_ivp->val, arg)

      ;  if (val != 0.0)
         {  dst_ivp->idx      =  src_ivp->idx
         ;  dst_ivp->val      =  val
         ;  dst_ivp++
      ;  }
      ;  src_ivp++
   ;  }
   ;  mclVectorResize(vec, dst_ivp - vec->ivps)
;  }


mclVector* mclVectorBinary
(  const mclVector*        vec1
,  const mclVector*        vec2
,  mclVector*              dst
,  float                   (*op)(float , float )
)  
   {  mclVector*           result
   ;  mclIvp               *ivpr, *ivp1, *ivp2, *ivp1max, *ivp2max
   ;  int                  lastidx     =  -1

   ;  if (!vec1)
         mclVectorAlert("mclVectorBinary (first arg)")
      ,  exit(1)

   ;  if (!vec2)
         mclVectorAlert("mclVectorBinary (second arg)")
      ,  exit(1)
                     
   ;  result         =     mclVectorCreate (vec1->n_ivps + vec2->n_ivps)
   ;  ivpr           =     result->ivps

   ;  ivp1           =     vec1->ivps
   ;  ivp2           =     vec2->ivps

   ;  ivp1max        =     ivp1 + vec1->n_ivps
   ;  ivp2max        =     ivp2 + vec2->n_ivps

   ;  if (!result)
      return NULL

   ;  result->n_ivps = 0

   ;  {
         float rval

      ;  while (ivp1 < ivp1max && ivp2 < ivp2max)
         {  
            float    val1 =  0.0
         ;  float    val2 =  0.0
         ;  int      idx

         ;  if (ivp1->idx < ivp2->idx)
            {  
               idx   =  ivp1->idx
            ;  val1  =  (ivp1++)->val
         ;  }
            else if (ivp1->idx > ivp2->idx)
            {  idx   =  ivp2->idx
            ;  val2  =  (ivp2++)->val
         ;  }
            else
            {  idx   =  ivp1->idx
            ;  val1  =  (ivp1++)->val
            ;  val2  =  (ivp2++)->val
         ;  }

         ;  if ((rval = op(val1, val2)) > 0)
            {  
               ivpr->idx      =  idx
            ;  (ivpr++)->val  =  rval
/*
 * ;  if (idx <= lastidx)
 *    {  fprintf
 *       (  stderr
 *       ,  "[mclVectorBinary fatal] vector not in"
 *          " ascending index format\n"
 *       )
 *    ;  exit(1)
 * ;  }
 * ;  lastidx        =  idx
*/
         ;  }
      ;  }

         while (ivp1 < ivp1max)
         {
            if ((rval = op(ivp1->val, 0.0)) > 0)
            {  
               ivpr->idx      =  ivp1->idx
            ;  (ivpr++)->val  =  rval
         ;  }
         ;  ivp1++
      ;  }

         while (ivp2 < ivp2max)
         {
            if ((rval = op(0.0, ivp2->val)) > 0)
            {  
               ivpr->idx      =  ivp2->idx
            ;  (ivpr++)->val  =  rval
         ;  }
         ;  ivp2++
      ;  }
   ;  }

   ;  result->n_ivps          =  ivpr - result->ivps

   ;  dst = mclVectorInstantiate(dst, result->n_ivps, result->ivps)
   ;  mclVectorFree(&result)
   ;  return dst
;  }


mclVector*  mclVectorFromData
(  float                *vals
,  int                  n_vals
)  
   {  mclVector* vec    =  mclVectorCreate(n_vals)
   ;  mclIvp* ivp       =  vec->ivps
   ;  int i =  0

   ;  while (ivp < vec->ivps+vec->n_ivps)
      {  
         ivp->idx       =  i
      ;  (ivp++)->val   =  *(vals+i)
      ;  i++
   ;  }
   ;  return vec
;  }


mclVector*  mclVectorComplete
(  mclVector*           dst_vec
,  int                  nr
,  float                val
)  
   {  mclIvp*           ivp
   ;  int               i      =  0

   ;  dst_vec     =     dst_vec 
                     ?  mclVectorResize(dst_vec, nr) 
                     :  mclVectorCreate(nr)

   ;  ivp         =  dst_vec->ivps

   ;  while (ivp < dst_vec->ivps+dst_vec->n_ivps)
      {  
         ivp->idx =  i++
      ;  (ivp++)->val =  val
   ;  }
   ;  return dst_vec
;  }


void mclVectorScale
(  mclVector*           vec
,  float                fac
)  
   {  int               n_ivps   =  vec->n_ivps
   ;  mclIvp*           ivps     =  vec->ivps

   ;  if (fac <= 0.0)
         fprintf(stderr, "[mclVectorScale PBD] nonpositive factor %f\n", fac)
      ,  exit(1)

   ;  while (--n_ivps >= 0)
      (ivps++)->val /= fac
;  }


float mclVectorNormalize
(  mclVector*              vec
)  
   {  int                  vecsize
   ;  mclIvp*              vecivps
   ;  float                sum

   ;  if (!vec)
         mclVectorAlert("mclVectorNormalize")
      ,  exit(1)

   ;  if (!vec->n_ivps)
      {  return 0.0
   ;  }

   ;  vecsize           =  vec->n_ivps
   ;  vecivps           =  vec->ivps
   ;  sum               =  mclVectorSum(vec)

   ;  if (mclWarningNonema && sum<=0.0)
      {  fprintf  
         (  stderr
         ,  "[mclVectorNormalize warning] "
            "nonpositive sum [%f]\n"
         ,  sum
         )
      ;  mclVectorResize(vec, 0)
      ;  return 0.0
   ;  }

   ;  while (--vecsize >= 0) (vecivps++)->val /= sum
   ;  return sum
;  }


float mclVectorInflate
(  mclVector*              vec
,  double                  power
)  
   {  mclIvp*              vecivps
   ;  int                  vecsize
   ;  float                powsum   =  0.0

   ;  if (!vec)
         mclVectorAlert("mclVectorInflate")
      ,  exit(1)

   ;  if (!vec->n_ivps)
      {  return 0.0
   ;  }

   ;  vecivps           =  vec->ivps
   ;  vecsize           =  vec->n_ivps

   ;  while (vecsize-- > 0)
      {  (vecivps)->val = (float) pow((double) (vecivps)->val, power)
      ;  powsum += (vecivps++)->val
   ;  }

   ;  if (mclWarningNonema && powsum <= 0.0)
      {  fprintf  
         (  stderr
         ,  "[mclVectorInflate warning] "
            "nonpositive sum [%f]\n"
         ,  powsum
         )
      ;  mclVectorResize(vec, 0)
      ;  return 0.0
   ;  }

   ;  vecivps = vec->ivps
   ;  vecsize = vec->n_ivps
   ;  while (vecsize-- > 0) (vecivps++)->val /= powsum

   ;  return (float) pow((double) powsum, power > 1.0 ? 1/(power-1) : 1.0)
;  }


float mclVectorSum
(  const mclVector*           vec
)  
   {  if (!vec)
         mclVectorAlert("mclVectorSum")
      ,  exit(1)

   ;  {  mclIvp*              vecivps = vec->ivps
      ;  int                  vecsize = vec->n_ivps
      ;  float                sum = 0.0

      ;  while (vecsize-- > 0)
         sum += (vecivps++)->val

      ;  return sum
   ;  }
;  }


float mclVectorPowSum
(  const mclVector*        vec
,  double                  power
)  
   {  if (!vec)
         mclVectorAlert("mclVectorPowSum")
      ,  exit(1)

   ;  {  mclIvp*              vecivps = vec->ivps
      ;  int                  vecsize = vec->n_ivps
      ;  float                powsum = 0.0

   ;  while (vecsize-- > 0)
         powsum += (float) pow((double) (vecivps++)->val, power)
   ;  return powsum
   ;  }
;  }


float mclVectorNorm
(  const mclVector*        vec
,  double                  power
)  
   {  if(power > 0.0)
         fprintf(stderr, "[mclVectorNorm PBD] negative power argument\n")
      ,  exit(1)

   ;  return (float) pow((double) mclVectorPowSum(vec, power), 1.0 / power)
;  }


int mclVectorIdxOffset
(  mclVector*              vec
,  int                     idx
)  
   {  mclIvp               *match   =  NULL
   ;  mclIvp               sought

   ;  mclIvpInstantiate(&sought, idx, 0.0)

   ;  if (!vec)
         mclVectorAlert("mclVectorIdxVal")
      ,  exit(1)

   ;  if (vec->n_ivps)
      {  match =
         bsearch
         (  &sought, vec->ivps, vec->n_ivps, sizeof(mclIvp)
         ,  mclIvpIdxCmp
         )
   ;  }

   ;  return match ? match - vec->ivps : -1
;  }


float mclVectorIdxVal
(  mclVector*              vec
,  int                     idx
,  int*                    p_offset
)  
   {  int      offset   =  mclVectorIdxOffset(vec, idx)
   ;  float    value    =  0.0

   ;  if (p_offset)
      *p_offset   =  offset
      
   ;  if (offset >= 0)
      value          =  (vec->ivps+offset)->val

   ;  return value
;  }


void mclVectorRemoveIdx
(  mclVector*  vec
,  int         idx
)  
   {  int                  offset   =  mclVectorIdxOffset(vec, idx)
                     /* check for nonnull vector is done in mclVectorIdxVal */
   ;  if (offset >= 0)
      {  
         memmove
         (  vec->ivps + offset
         ,  vec->ivps + offset + 1
         ,  (vec->n_ivps - offset - 1) * sizeof(mclIvp)
         )
      ;  mclVectorResize(vec, vec->n_ivps - 1)
   ;  }
;  }


int mclVectorIdxCmp
(  const void*  p1
,  const void*  p2
)  
   {  mclIvp*   ivp1    =  ((mclVector*)p1)->ivps
   ;  mclIvp*   ivp2    =  ((mclVector*)p2)->ivps
   ;  int       n_ivps  =  MIN
                           (  ((mclVector*)p1)->n_ivps
                           ,  ((mclVector*)p2)->n_ivps
                           )
   ;  int       diff    =     ((mclVector*)p1)->n_ivps
                           -  ((mclVector*)p2)->n_ivps

     /*
      *  Large clusters first
     */
   ;  if (mclVectorSizeCmp && diff)
      return -diff

     /*
      *  Rows with low numbers first
     */
   ;  while (--n_ivps >= 0)
      {  
         diff     =  (ivp1++)->idx - (ivp2++)->idx

      ;  if (diff)
         return -diff
   ;  }

   ;  return 0
;  }


int mclVectorSumCmp
(  const void*          p1
,  const void*          p2
)  
   {  double   s1 =  mclVectorSum((mclVector*) p1)
   ;  double   s2 =  mclVectorSum((mclVector*) p2)

   ;  return SIGN(s1-s2)
;  }


int mclVectorIdxRevCmp
(  const void*          p1
,  const void*          p2
)  
   {  return mclVectorIdxCmp(p2, p1)
;  }

   
int mclVectorSumRevCmp
(  const void*          p1
,  const void*          p2
)  
   {  return mclVectorSumCmp(p2, p1)
;  }


my_inline mclVector* mclVectorCreate
(  int                     n_ivps
)  
   {  return mclVectorInstantiate(NULL, n_ivps, NULL)
;  }


my_inline mclVector*  mclVectorResize
(  mclVector*              vec
,  int                     n_ivps
)  
   {  return mclVectorInstantiate(vec, n_ivps, NULL)
;  }


my_inline mclVector* mclVectorCopy
(  const mclVector*        src
)  
   {  return mclVectorInstantiate(NULL, src->n_ivps, src->ivps)
;  }


my_inline void mclVectorSelectHighest
(  mclVector*              vec
,  int                     max_n_ivps
)  
   {  float f =
      (vec->n_ivps >= 2 * max_n_ivps) 
      ?  mclVectorKBar
         (vec, max_n_ivps, FLT_MAX, KBAR_SELECT_LARGE)
      :  mclVectorKBar
         (vec, vec->n_ivps - max_n_ivps + 1, -FLT_MAX, KBAR_SELECT_SMALL)

   ;  mclVectorSelectGqBar(vec, f)
;  }


my_inline void mclVectorMakeCharacteristic
(  mclVector*              vec
)  
   {  float                one      =  1.0
   ;  mclVectorUnary(vec, fltConstant, &one)
;  }


my_inline void mclVectorHdp
(  mclVector*              vec
,  float                   power
)  
   {  mclVectorUnary(vec, fltPower, &power)
;  }


my_inline mclVector* mclVectorMaskedCopy
(  mclVector*              dst
,  const mclVector*        src
,  const mclVector*        msk
,  int                     mask_mode
)  
   {  if   (mask_mode == 0)                              /* positive mask */
      return  mclVectorBinary(src, msk, dst, fltLTrueAndRTrue)
   ;  else                                               /* negative mask */
      return mclVectorBinary(src, msk, dst, fltLTrueAndRFalse)
;  }


my_inline mclVector* mclVectorSetMerge
(  const mclVector*  lft
,  const mclVector*  rgt
,  mclVector*  dst
)
   {  return mclVectorBinary(lft, rgt, dst, fltLTrueOrRTrue)
;  }


my_inline mclVector* mclVectorSetMinus
(  const mclVector*  lft
,  const mclVector*  rgt
,  mclVector*  dst
)  
   {  return mclVectorBinary(lft, rgt, dst, fltLTrueAndRFalse)
;  }


my_inline mclVector* mclVectorSetMeet
(  const mclVector*  lft
,  const mclVector*  rgt
,  mclVector*  dst
)  
   {  return mclVectorBinary(lft, rgt, dst, fltLTrueAndRTrue)
;  }  


my_inline float mclVectorMaxValue
(  const mclVector*           vec
)  
   {  float                   max_val  =  0.0
   ;  mclVectorUnary((mclVector*)vec, fltPropagateMax, &max_val)
   ;  return (float) max_val
;  }


#if 0
void mclVectorSelectHighestWithHint
(  mclVector*        vec
,  int               max_n_ivps
,  float             hint
,  int               hint_n_ivps
)  
   {  int            seekLargeEntries  =  1
   ;  mclIvp       **ivpp              =  &(vec->ivps)
   ;  int            n_seek            =  0
   ;  float          thrval            =  0.0
   ;  int            idx              

   ;  if (!vec)
         mclVectorAlert("mclVectorSelectHighestWithHint")
      ,  exit(1)

   ;  if (vec->n_ivps <= max_n_ivps)
      return

   ;  if (hint_n_ivps < 0 || hint_n_ivps > vec->n_ivps)
      {

         /*    Branch below will search for the largest max_n_ivps ivps that
          *    are smaller than inf. Root of the heap will contain the smallest
          *    value in this set.
         */

         if (vec->n_ivps > 2 * max_n_ivps)
         {  
            seekLargeEntries  =  1
         ;  thrval            =  FLT_MAX     /* consider only els < inf    */
         ;  n_seek            =  max_n_ivps
      ;  }

         /*    Branch below will search for the smallest (vec->n_ivps  -
          *    max_n_ivps) ivps among all ivps. Root of the heap will contain
          *    the largest value in this set.
         */

         else
         {  
            seekLargeEntries  =  0
         ;  thrval            =  -FLT_MAX    /* consider only els >= -inf  */
         ;  n_seek            =  vec->n_ivps - max_n_ivps + 1
      ;  }

      ;  if (hint_n_ivps > vec->n_ivps)
         fprintf
         (  stderr
         ,  "[mclVectorSelectHighestWithHint PBD]"
            " stupid hint argument (ignoring)\n"
         )
   ;  }

      else
      {
         /*    Hint leaves us too few large ivps, maybe we can search for more
          *    large ivps.
         */

         if (hint_n_ivps < max_n_ivps)

            /*    Branch below will search for the largest (max_n_ivps -
             *    hint_n_ivps) ivps that are smaller than hint. Root of the
             *    heap will contain the smallest value in this set.
            */

         {  if (max_n_ivps - hint_n_ivps < vec->n_ivps - max_n_ivps)
            {  
               seekLargeEntries  =  1
            ;  thrval            =  hint     /* consider only els <  hint  */
            ;  n_seek            =  max_n_ivps - hint_n_ivps
         ;  }

            /*    Branch below will search for the smallest
             *    (vec->n_ivps  - max_n_ivps) ivps among all ivps.
             *    Root of the heap will contain the largest value in this set.
             *    The largest value is included in the gqBar selection,
             *    so we need to search for one extra value.
            */

            else
            {  seekLargeEntries  =  0
            ;  thrval            =  -FLT_MAX  /* consider only els >=  -inf */
            ;  n_seek            =  vec->n_ivps  - max_n_ivps + 1
         ;  }
      ;  }

         /*    hint leaves too few (small) ivps, 
          *    as we need (vec->n_ivps - max_n_ivps) of those, and this gives
          *    only (vec->n_ivps - hint_n_ivps) maybe we can search for more
          *    small ivps; we need still hint_n_ivps - max_n_ivps more.
          * 
          *    NOTE that we preprune; this affects the initialization taking
          *    place in the branches, namely the case seekLargeEntries = 0.
         */

         else if (hint_n_ivps > max_n_ivps)
         {
            if ((hint_n_ivps - max_n_ivps) < (vec->n_ivps - hint_n_ivps)) 
            mclVectorSelectGqBar(vec, hint)

            /*    Branch below will search for the smallest
             *    (hint_n_ivps - max_n_ivps) ivps among all ivps that
             *    are larger than hint. Root of the max-heap will contain the
             *    largest value in this set. This value is included in the
             *    gqBar selection, so we need to search for one extra value.
            */

         ;  if (hint_n_ivps - max_n_ivps < max_n_ivps)
            {     
               seekLargeEntries  =  0
            ;  thrval            =  hint     /* consider only els >= hint  */
            ;  n_seek            =  hint_n_ivps - max_n_ivps + 1
         ;  }

            /*    Branch below will search for max_n_ivps largest ivps
             *    among all ivps. Root of the min-heap will contain the
             *    smallest value in this set.
            */

            else
            {  seekLargeEntries  =  1
            ;  thrval            =  FLT_MAX  /* consider only els < FLT_MAX */
            ;  n_seek            =  max_n_ivps
         ;  }
      ;  }
         else if (hint_n_ivps == max_n_ivps)
         {  
            mclVectorSelectGqBar(vec, hint)
         ;  return
      ;  }
   ;  }

      {  
         float bar
      =  mclVectorKBar
         (  vec
         ,  n_seek
         ,  thrval
         ,  NULL
         ,  seekLargeEntries
         )

      ;  mclVectorSelectGqBar(vec, bar)
   ;  }
;  }


int mclVectorSelectRltBar
(  
   mclVector*              vec
,  int                     ibar
,  float                   fbar
,  int                     (*irlt)(const void*, const void*)
,  int                     (*frlt)(const void*, const void*)
,  int                     onlyCount
)  
   {  mclIvp               *newIvp, *oldIvp, *maxIvp

   ;  if (!vec)
         mclVectorAlert("mclVectorSelectRltBar")
      ,  exit(1)

   ;  newIvp               =  vec->ivps
   ;  oldIvp               =  newIvp
   ;  maxIvp               =  newIvp+vec->n_ivps

   ;  while (oldIvp < maxIvp)
      {  if
         (  (  !frlt || frlt(&(oldIvp->val), &fbar)
            )
         &&
            (  !irlt || irlt(&(oldIvp->idx), &ibar)
            )
         )
         {  if (!onlyCount && (newIvp < oldIvp))
            {  newIvp->val = oldIvp->val
            ;  newIvp->idx = oldIvp->idx
         ;  }
         ;  newIvp++
      ;  }
      ;  oldIvp++
   ;  }

   ;  if (!onlyCount)
      mclVectorResize(vec, newIvp - (vec->ivps))

   ;  return (newIvp - vec->ivps)
;  }


my_inline int mclVectorSelectGtBar
(  mclVector*              vec
,  float                   bar
)  
   {  return mclVectorSelectRltBar(vec, -1, bar, NULL, fltGt, 0)
;  }


my_inline int mclVectorCountGqBar
(  mclVector*              vec
,  float                   bar
)  
   {  return mclVectorSelectRltBar(vec, -1, bar, NULL, fltGq, 1)
;  }
#endif

