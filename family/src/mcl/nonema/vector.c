/*
// vector.c                Sparse vector operations
*/

#include <stdlib.h>
#include <limits.h>
#include <math.h>
#include <float.h>
#include <stdio.h>
#include <string.h>

#include "nonema/vector.h"
#include "nonema/iface.h"
#include "util/alloc.h"
#include "util/types.h"
#include "util/array.h"
#include "util/minmax.h"
#include "util/sign.h"

void mcxVectorAlert
(  
   const char*          caller
)  {  
      fprintf(stderr, "[%s] void vector argument\n", caller)
   ;  return
;  }


mcxstatus mcxVectorCheck
(  
   const mcxVector*        vec
,  int                     range
,  const char*             caller
,  mcxOnFail               ON_FAIL
)  
   {  
      mcxIvp*  ivp      =  vec->ivps
   ;  mcxIvp*  ivpmax   =  vec->ivps+vec->n_ivps
   ;  int      last     =  -1
   ;  int      status   =  STATUS_OK

   ;  if (!vec)
      {  fprintf
         (  stderr
         ,  "[mcxVectorCheck deadly] NULL vector\n"
         )
      ;  if (ON_FAIL == RETURN_ON_FAIL)
         return STATUS_FAIL
      ;  else
         exit(1)
   ;  }

      if (!vec->ivps && vec->n_ivps)
      {  fprintf
         (  stderr
         ,  "[mcxVectorCheck deadly] NULL ivps and [%d] n_ivps\n"
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
            ,  "[mcxVectorCheck deadly] index descend [%d, %d] at ivp [%d]\n"
            ,  last, ivp->idx, (ivp - vec->ivps)
            )
         ;  status      =  STATUS_FAIL
         ;  break
      ;  }
         if (ivp->idx == last)
         {  fprintf
            (  stderr
            ,  "[mcxVectorCheck deadly] repeated index [%d] at ivp [%d]\n"
            ,  ivp->idx, (ivp - vec->ivps)
            )
         ;  status      =  STATUS_FAIL
         ;  break
      ;  }
         if (ivp->val < 0.0)
         {  fprintf
            (  stderr
            ,  "[mcxVectorCheck deadly] negative value [%f] at ivp [%d]\n"
            ,  ivp->val, (ivp - vec->ivps)
            )
         ;  status      =  STATUS_FAIL
         ;  break
      ;  }
         if (0 && ivp->val == 0.0)
         {  fprintf
            (  stderr
            ,  "[mcxVectorCheck unusual] zero value [%f] at ivp [%d]\n"
            ,  ivp->val, (ivp - vec->ivps)
            )  ;
         }

      ;  last = ivp->idx
      ;  ivp++
   ;  }

   ;  if (last >= range)
      {  fprintf
         (  stderr
         ,  "[mcxVectorCheck deadly] index [%d] tops range [%d]"
            " at ivp [%d]\n"
         ,  last, range, (ivp - 1 - vec->ivps)
         )
      ;  status      =  STATUS_FAIL
   ;  }

   ;  if ((status  == STATUS_FAIL) && (ON_FAIL == EXIT_ON_FAIL))
      exit(1)

   ;  return status
;  }


/*
 *    mcxVectorInit: vec argument may be NULL.
 *
*/


mcxVector* mcxVectorInit
(  
   mcxVector*              vec
)  
   {  
      if (!vec)
      vec               =  (mcxVector*) rqAlloc(sizeof(mcxVector), EXIT_ON_FAIL)
   ;  vec->ivps         =  NULL
   ;  vec->n_ivps       =  0
   ;  return vec
;  }


/*
 *    mcxVectorInstantiate: vec argument may be NULL.
*/


mcxVector* mcxVectorInstantiate
(  
   mcxVector*                 dst_vec
,  int                        new_n_ivps
,  const mcxIvp*              src_ivps
)  
   {  mcxIvp*                 new_ivps

   ;  if (!dst_vec)                                   /* create */
      dst_vec = mcxVectorInit(NULL)

   ;  dst_vec->ivps
      =  
         (mcxIvp*) rqRealloc
         (  dst_vec->ivps
         ,  new_n_ivps * sizeof(mcxIvp)
         ,  RETURN_ON_FAIL
         )

   ;  if (new_n_ivps && !dst_vec->ivps)
         mcxMemDenied(stderr, "mcxVectorInstantiate", "mcxIvp", new_n_ivps)
      ,  exit(1)

   ;  new_ivps       =  dst_vec->ivps

   ;  if (!src_ivps)                                  /* resize */
      {  
         int   k     =  dst_vec->n_ivps
      ;  while (k < new_n_ivps)
         {  
            mcxIvpInit(new_ivps + k)
         ;  k++
      ;  }
   ;  }

      else if (src_ivps && new_n_ivps)                /* copy   */
      memcpy(new_ivps, src_ivps, new_n_ivps * sizeof(mcxIvp))

   ;  dst_vec->n_ivps      =  new_n_ivps
   ;  return dst_vec
;  }


/*
 *    mcxVectorFree: vec that is pointed to in argument may be NULL.
*/


void mcxVectorFree
(  
   mcxVector**                 vecpp
)  
   {  
      if (*vecpp)
      {
         rqFree((*vecpp)->ivps)
      ;  rqFree(*vecpp)
      ;  (*vecpp) = NULL
   ;  }
;  }


/*
 *
*/


void mcxVectorSort
(  
   mcxVector*              vec
,  int                     (*cmp)(const void*, const void*)
)  
   {  
      if (!vec)
         mcxVectorAlert("mcxVectorSort")
      ,  exit(1)

   ;  if (!cmp)
      cmp = mcxIvpIdxCmp

   ;  if (vec->n_ivps)
      qsort(vec->ivps, vec->n_ivps, sizeof(mcxIvp), cmp)
;  }


void mcxVectorUniqueIdx
(  
   mcxVector*              vec
)  
   {
      if (!vec)
         mcxVectorAlert("mcxVectorUniqueIdx")
      ,  exit(1)

   ;  if (vec->n_ivps)
      vec->n_ivps
      =  mcxDedup
      (  vec->ivps
      ,  vec->n_ivps
      ,  sizeof(mcxIvp)
      ,  mcxIvpIdxCmp
      ,  mcxIvpMergeDiscard
      )
;  }


/*
 *
*/


float mcxVectorKBar
(
   mcxVector   *vec
,  int         k
,  float       ignore            /*    ignore elements relative to this  */
,  int         mode
)  
   {
      int      bEven       =  (k+1) % 2
   ;  int      n_inserted  =  0
   ;  float    ans         =  0.0

   ;  mcxIvp*  vecIvp      =  vec->ivps
   ;  mcxIvp*  vecMaxIvp   =  vecIvp + vec->n_ivps

   ;  float    *heap       =  (float*) rqAlloc
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
         fprintf(stderr, "[mcxVectorKBar PBD] invalid mode\n")
      ;  exit(1)
   ;  }

   ;  ans   =  *heap
   ;  rqFree(heap)

   ;  return ans
;  }


#if 0
int mcxVectorSelectRltBar
(  
   mcxVector*              vec
,  int                     ibar
,  float                   fbar
,  int                     (*irlt)(const void*, const void*)
,  int                     (*frlt)(const void*, const void*)
,  int                     onlyCount
)  
   {  
      mcxIvp               *newIvp, *oldIvp, *maxIvp

   ;  if (!vec)
         mcxVectorAlert("mcxVectorSelectRltBar")
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
      mcxVectorResize(vec, newIvp - (vec->ivps))

   ;  return (newIvp - vec->ivps)
;  }
#endif


float mcxVectorSelectGqBar
(  
   mcxVector*        vec
,  float             fbar
)
   {  
      mcxIvp         *newIvp, *oldIvp, *maxIvp
   ;  float          mass  =  0.0      

   ;  if (!vec)
         mcxVectorAlert("mcxVectorSelectRltBar")
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

   ;  mcxVectorResize(vec, newIvp - (vec->ivps))
   ;  return mass
;  }


float mcxVectorSelectNeedsBar
(  
   mcxVector*              vec
,  int                     dest_n_ivps
)  
   {  
      int   i
   ;  float smaller, larger

   ;  if (dest_n_ivps >= vec->n_ivps)   return 0.0
   ;  if (dest_n_ivps < 0)
      {  fprintf
         (  stderr
         ,  "[mcxVectorSelectNeedsBar] warning: negative argument\n"
         )
      ;  return (mcxVectorMaxValue(vec) + 1)
   ;  }

   ;  mcxVectorSort(vec, mcxIvpValRevCmp)

   ;  larger           =  (vec->ivps+dest_n_ivps)->val
   ;  smaller          =  larger
   ;  i                =  dest_n_ivps+1

   ;  while (i<vec->n_ivps)
      {  smaller       =  (vec->ivps+i)->val
      ;  if (smaller < larger)   break
      ;  i++
   ;  }
   ;  mcxVectorSort(vec, mcxIvpIdxCmp)

   ;  return 0.5 * (smaller + larger)
;  }



void mcxVectorUnary
(  
   mcxVector*              vec
,  float                   (*operation)(float val, void* arg)
,  void*                   arg
)  
   {  
      int                  n_ivps
   ;  mcxIvp               *src_ivp, *dst_ivp

   ;  if (!vec)
         mcxVectorAlert("mcxVectorUnary")
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
   ;  mcxVectorResize(vec, dst_ivp - vec->ivps)
;  }


mcxVector* mcxVectorBinary
(  
   const mcxVector*        vec1
,  const mcxVector*        vec2
,  mcxVector*              dst
,  float                   (*op)(float , float )
)  
   {  
      mcxVector*           result
   ;  mcxIvp               *ivpr, *ivp1, *ivp2, *ivp1max, *ivp2max
   ;  int                  lastidx     =  -1

   ;  if (!vec1)
         mcxVectorAlert("mcxVectorBinary (first arg)")
      ,  exit(1)

   ;  if (!vec2)
         mcxVectorAlert("mcxVectorBinary (second arg)")
      ,  exit(1)
                     
   ;  result         =     mcxVectorCreate (vec1->n_ivps + vec2->n_ivps)
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
#if 0
            ;  if (idx <= lastidx)
               {  fprintf
                  (  stderr
                  ,  "[mcxVectorBinary fatal] vector not in"
                     " ascending index format\n"
                  )
               ;  exit(1)
            ;  }
            ;  lastidx        =  idx
#endif
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

   ;  dst = mcxVectorInstantiate(dst, result->n_ivps, result->ivps)
   ;  mcxVectorFree(&result)
   ;  return dst
;  }


mcxVector*  mcxVectorComplete
(  
   mcxVector*           dst_vec
,  int                  nr
,  float                val
)  
   {
      mcxIvp*           ivp
   ;  int               i      =  0

   ;  dst_vec     =     dst_vec 
                     ?  mcxVectorResize(dst_vec, nr) 
                     :  mcxVectorCreate(nr)

   ;  ivp         =  dst_vec->ivps

   ;  while (ivp < dst_vec->ivps+dst_vec->n_ivps)
      {  
         ivp->idx =  i++
      ;  (ivp++)->val =  val
   ;  }
   ;  return dst_vec
;  }


void mcxVectorScale
(  
   mcxVector*           vec
,  float                fac
)  
   {  
      int               n_ivps   =  vec->n_ivps
   ;  mcxIvp*           ivps     =  vec->ivps

   ;  if (fac <= 0.0)
         fprintf(stderr, "[mcxVectorScale PBD] nonpositive factor %f\n", fac)
      ,  exit(1)

   ;  while (--n_ivps >= 0)
      (ivps++)->val /= fac
;  }


float mcxVectorNormalize
(  
   mcxVector*              vec
)  
   {  
      int                  vecsize
   ;  mcxIvp*              vecivps
   ;  float                sum

   ;  if (!vec)
         mcxVectorAlert("mcxVectorNormalize")
      ,  exit(1)

   ;  if (!vec->n_ivps)
      {  return 0.0
   ;  }

   ;  vecsize           =  vec->n_ivps
   ;  vecivps           =  vec->ivps
   ;  sum               =  mcxVectorSum(vec)

   ;  if (mcxWarningNonema && sum<=0.0)
      {  fprintf  
         (  stderr
         ,  "[mcxVectorNormalize warning] "
            "nonpositive sum [%f]\n"
         ,  sum
         )
      ;  mcxVectorResize(vec, 0)
      ;  return 0.0
   ;  }

   ;  while (--vecsize >= 0) (vecivps++)->val /= sum
   ;  return sum
;  }


float mcxVectorInflate
(  
   mcxVector*              vec
,  double                  power
)  
   {  
      mcxIvp*              vecivps
   ;  int                  vecsize
   ;  float                powsum   =  0.0

   ;  if (!vec)
         mcxVectorAlert("mcxVectorInflate")
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

   ;  if (mcxWarningNonema && powsum <= 0.0)
      {  fprintf  
         (  stderr
         ,  "[mcxVectorInflate warning] "
            "nonpositive sum [%f]\n"
         ,  powsum
         )
      ;  mcxVectorResize(vec, 0)
      ;  return 0.0
   ;  }

   ;  vecivps = vec->ivps
   ;  vecsize = vec->n_ivps
   ;  while (vecsize-- > 0) (vecivps++)->val /= powsum

   ;  return (float) pow((double) powsum, power > 1.0 ? 1/(power-1) : 1.0)
;  }


float mcxVectorSum
(  
   const mcxVector*           vec
)  
   {  
      if (!vec)
         mcxVectorAlert("mcxVectorSum")
      ,  exit(1)

   ;  {  mcxIvp*              vecivps = vec->ivps
      ;  int                  vecsize = vec->n_ivps
      ;  float                sum = 0.0

      ;  while (vecsize-- > 0)
         sum += (vecivps++)->val

      ;  return sum
   ;  }
;  }


float mcxVectorPowSum
(  
   const mcxVector*        vec
,  double                  power
)  
   {  
      if (!vec)
         mcxVectorAlert("mcxVectorPowSum")
      ,  exit(1)

   ;  {  mcxIvp*              vecivps = vec->ivps
      ;  int                  vecsize = vec->n_ivps
      ;  float                powsum = 0.0

   ;  while (vecsize-- > 0)
         powsum += (float) pow((double) (vecivps++)->val, power)
   ;  return powsum
   ;  }
;  }


float mcxVectorNorm
(  
   const mcxVector*        vec
,  double                  power
)  
   {  
      assert(power > 0.0)
   ;  return (float) pow((double) mcxVectorPowSum(vec, power), 1.0 / power)
;  }


int mcxVectorIdxOffset
(  
   mcxVector*              vec
,  int                     idx
)  
   {  
      mcxIvp               *match   =  NULL
   ;  mcxIvp               sought

   ;  mcxIvpInstantiate(&sought, idx, 0.0)

   ;  if (!vec)
         mcxVectorAlert("mcxVectorIdxVal")
      ,  exit(1)

   ;  if (vec->n_ivps)
      {  match =
         bsearch
         (  &sought, vec->ivps, vec->n_ivps, sizeof(mcxIvp)
         ,  mcxIvpIdxCmp
         )
   ;  }

   ;  return match ? match - vec->ivps : -1
;  }


float mcxVectorIdxVal
(  
   mcxVector*              vec
,  int                     idx
,  int*                    p_offset
)  
   {  
      int      offset   =  mcxVectorIdxOffset(vec, idx)
   ;  float    value    =  0.0

   ;  if (p_offset)
      *p_offset   =  offset
      
   ;  if (offset >= 0)
      value          =  (vec->ivps+offset)->val

   ;  return value
;  }


void mcxVectorRemoveIdx
(  
   mcxVector*              vec
,  int                     idx
)  
   {  

   /*
    *    check for nonnull vector is done in mcxVectorIdxVal
   */

      int                  offset   =  mcxVectorIdxOffset(vec, idx)

   ;  if (offset >= 0)
      {  
         memmove
         (  vec->ivps + offset
         ,  vec->ivps + offset + 1
         ,  (vec->n_ivps - offset - 1) * sizeof(mcxIvp)
         )
      ;  mcxVectorResize(vec, vec->n_ivps - 1)
   ;  }
;  }


int mcxVectorIdxCmp
(  
   const void*  p1
,  const void*  p2
)  
   {  
      mcxIvp*   ivp1    =  ((mcxVector*)p1)->ivps
   ;  mcxIvp*   ivp2    =  ((mcxVector*)p2)->ivps
   ;  int       n_ivps  =  int_MIN(((mcxVector*)p1)->n_ivps
                                   ,  ((mcxVector*)p2)->n_ivps
                                   )
   ;  int       diff    =     ((mcxVector*)p1)->n_ivps
                           -  ((mcxVector*)p2)->n_ivps

     /*
      *  Large clusters first
     */
   ;  if (mcxVectorSizeCmp && diff)
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


int mcxVectorSumCmp
(  
   const void*          p1
,  const void*          p2
)  
   {  
      return (int)   float_SIGN(mcxVectorSum(p1) - mcxVectorSum(p2))
;  }


int mcxVectorIdxRevCmp
(  
   const void*          p1
,  const void*          p2
)  
   {  
      return mcxVectorIdxCmp(p2, p1)
;  }

   
int mcxVectorSumRevCmp
(  
   const void*          p1
,  const void*          p2
)  
   {  
      return mcxVectorSumCmp(p2, p1)
;  }


#if 0
void mcxVectorSelectHighestWithHint
(  
   mcxVector*        vec
,  int               max_n_ivps
,  float             hint
,  int               hint_n_ivps
)  
   {
      int            seekLargeEntries  =  1
   ;  mcxIvp       **ivpp              =  &(vec->ivps)
   ;  int            n_seek            =  0
   ;  float          thrval            =  0.0
   ;  int            idx              

   ;  if (!vec)
         mcxVectorAlert("mcxVectorSelectHighestWithHint")
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
         ,  "[mcxVectorSelectHighestWithHint PBD]"
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
            mcxVectorSelectGqBar(vec, hint)

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
            mcxVectorSelectGqBar(vec, hint)
         ;  return
      ;  }
   ;  }

      {  
         float bar
      =  mcxVectorKBar
         (  vec
         ,  n_seek
         ,  thrval
         ,  NULL
         ,  seekLargeEntries
         )

      ;  mcxVectorSelectGqBar(vec, bar)
   ;  }
;  }
#endif

