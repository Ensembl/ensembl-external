/*
// compose.c            MCL specific compose
*/

#include <math.h>
#include <limits.h>
#include <float.h>

#include "nonema/compose.h"
#include "nonema/ivp.h"
#include "nonema/iface.h"

#include "mcl/compose.h"
#include "mcl/iface.h"
#include "mcl/heap.h"

#include "util/alloc.h"
#include "util/iface.h"
#include "util/minmax.h"


static const char* TRACK1        =  "trackPruning vector";
static mcxVector* heapVec        =  NULL;
static mcxIvp**   ivpHeap        =  NULL;
static mcxIvp**   ivpHeapRoot    =  NULL;
static mcxIvp*    ivpHeapInfIvp  =  NULL;
static mcxIvp*    ivpHeapSupIvp  =  NULL;
static int        ivpHeapSize    =  0;

void ivpHeapInsert(mcxIvp* vecIvp, int position);

mcxComposeParam* mcxComposeParamNew
(void
)  {  
      mcxComposeParam *cpParam      =     (mcxComposeParam*) rqAlloc
                                          (  sizeof(mcxComposeParam)
                                          ,  EXIT_ON_FAIL
                                          )

   ;  cpParam->maxDensity           =     mclDefaultMaxDensity
   ;  cpParam->precision            =     (float)
                                          pow(10.0,-mclDefaultPrecisionExponent)
   ;  cpParam->precisionExponent    =     mclDefaultPrecisionExponent
   ;  cpParam->alwaysBarWeight      =     mclDefaultAlwaysBarWeight
   ;  cpParam->threeTwoWeight       =     mclDefaultThreeTwoWeight
   ;  cpParam->centerWeight         =     mclDefaultCenterWeight
   ;  cpParam->cubeWeight           =     mclDefaultCubeWeight
   ;  cpParam->maxValWeight1        =     mclDefaultMaxValWeight1
   ;  cpParam->maxValWeight2        =     mclDefaultMaxValWeight2
   ;  return cpParam
;  }


mcxMatrix* mcxFlowCompose
(  const mcxMatrix*        mx1
,  const mcxMatrix*        mx2
,  mcxComposeParam*        param
,  mcxComposeStats*        stats
)
   {  mcxMatrix*           mx_d
   ;  int                  mx2col               =  0
   ;  mcxIvp              *barIvps

   ;  int                  maxDensity           =  param->maxDensity
   ;  float                alwaysBarWeight      =  param->alwaysBarWeight
   ;  float                threeTwoWeight       =  param->threeTwoWeight
   ;  float                centerWeight         =  param->centerWeight
   ;  float                cubeWeight           =  param->cubeWeight
   ;  float                maxValWeight1        =  param->maxValWeight1
   ;  float                maxValWeight2        =  param->maxValWeight2
   ;  mcxIvp*              maxDensityIvp        =  mcxIvpCreate(maxDensity, 0.0)
                                               
   ;  float                precision            =  param->precision
   ;  float                matrixInhomogeneity  =  0.0
                                               
   ;  int                  mainTrackPruning     =  mcxTrackNonemaPruning


   ;  barIvps        =     (mcxIvp*) rqAlloc
                           (  5 * sizeof(mcxIvp)
                           ,  EXIT_ON_FAIL
                           )


   ;  mcxComposeStatsReset(stats)
                                       /* the code in the following line   */
                                       /* affects mcxMatrixVectorCompose   */
   ;  mcxIvpStorageAllocated((mx2->N_rows)+1)

   ;  if (mx1->N_cols != mx2->N_rows)
      {  fprintf
         (  stderr
         ,  "[mcxFlowExpand PBD] "
            "Incompatible size matrices for compose operation\n"
         )
      ;  exit(1)
   ;  }

   ;  mx_d = mcxMatrixAllocZero(mx1->N_rows, mx2->N_cols)

   ;  if (mainTrackPruning)
         fprintf
         (  mcxTrackStreamNonema->fp
         ,  "____ [%s] at start\n"
         ,  TRACK1
         )

   ;  for (mx2col=0;mx2col<mx2->N_cols;mx2col++)

      {  mcxVector*  vec_d    =  mx_d->vectors + mx2col
      ;  float    alwaysBar, maxval, cube, center, threeTwo, mass
               ,  vectorInhomogeneity

      ;  if (mclProgress && (mx2col % mclProgress) == 0)
         {  fwrite(".", sizeof(char), 1, stdout)
         ;  fflush(stdout)
      ;  }

      ;  mcxTrackNonemaPruning      =     mainTrackPruning
                              && (  !mcxTrackNonemaPruningOfset
                                 || mx2col >= mcxTrackNonemaPruningOfset
                                 )
                              && (  !mcxTrackNonemaPruningBound
                                 || mx2col < mcxTrackNonemaPruningBound
                                 )
                              && (  
                                    (  (mx2col-mcxTrackNonemaPruningOfset)
                                    %  mcxTrackNonemaPruningInterval
                                    )
                                 == 0
                                 )

      ;  if (mclBdense)
         mcxMatrixVectorDenseCompose
         (  mx1
         ,  mx2->vectors + mx2col
         ,  vec_d
         )
      ;  else
         mcxMatrixVectorCompose
         (  mx1
         ,  mx2->vectors + mx2col
         ,  vec_d
         )

      ;  if (mcxTrackNonemaPruning)
         fprintf
         (  mcxTrackStreamNonema->fp
         ,  "\n[%s] vector %d, size %d\n"
         ,  TRACK1, mx2col, vec_d->n_ivps
         )  ;
/*
//    so far normal matrix multiplication.
//    In the following some options are implemented which enable
//    different ways of pruning the vector just computed, vec_d.
*/

/*
//    full matrix computation
*/
         if (  vec_d->n_ivps <= maxDensity || mclBdense )
         {  if (precision)
            {  mcxVectorSelectGqBar (vec_d, precision)
         ;  }
         ;  mcxDistrStoreValue(stats->mDb, 1.0 )
      ;  }

/*
//    heap pruning
*/
         else if (mclHeapPruning)
         {
            int      x
         ;  int      bEven       =  (maxDensity+1) % 2
         ;  mcxIvp*  vecIvp      =  vec_d->ivps
         ;  mcxIvp*  vecMaxIvp   =  vecIvp + vec_d->n_ivps

         ;  if (ivpHeapSize < maxDensity+bEven)
            {  ivpHeap           =  rqRealloc
                                    (  ivpHeap
                                    ,  (maxDensity+bEven)*sizeof(mcxIvp*)
                                    ,  EXIT_ON_FAIL
                                    )
            ;  ivpHeapRoot       =  ivpHeap
            ;  ivpHeapSize       =  maxDensity
            ;  ivpHeapInfIvp     =  mcxIvpInstantiate(NULL, -1, -1.0)
            ;  ivpHeapSupIvp     =  mcxIvpInstantiate(NULL, -1, FLT_MAX)
         ;  }

         ;  for (x=0;x<ivpHeapSize;x++)
            *(ivpHeap+x)         =  ivpHeapInfIvp

         ;  if (bEven)
            *(ivpHeap+ivpHeapSize)  =  ivpHeapSupIvp

         ;  while(vecIvp < vecMaxIvp)
            {  
               if (vecIvp->val > (*ivpHeapRoot)->val)
               ivpHeapInsert(vecIvp, 0)

            ;  vecIvp++
         ;  }

         ;  mcxVectorSelectGqBar
            (vec_d, MAX( (*(ivpHeapRoot+0))->val, precision))
      ;  }

/*
//    elaborate pruning schemes.
*/
         else
         {  int   n_pruned, n_bestHint
         ;  int   n_vec      =  vec_d->n_ivps ? vec_d->n_ivps : maxDensity

         ;  float reduce     =    maxDensity < n_vec
                                 ?  ((float ) maxDensity) / (float ) n_vec
                                 :  0.0

         ;  maxval    =    mcxVectorMaxValue(vec_d)
         ;  threeTwo  =    (float) pow((double)mcxVectorPowSum(vec_d, 1.5), 2.0)

         ;  alwaysBar =  
                           (  threeTwo
                           *  (float) pow
                              (  1.01 - reduce
                              ,  2.0
                              )
                           *  (float) pow
                              (  1.01 - (threeTwo / maxval)
                              ,  2.0
                              )
                           /  alwaysBarWeight
                           )  ;

            if (mclBsqueeze)
            {  
               mcxVectorSelectGqBar(vec_d, alwaysBar)

            ;  mass              =  mcxVectorSum(vec_d)
            ;  mass              =  mass ? mass : 1.0

            ;  cube              =     sqrt(mcxVectorPowSum(vec_d, 3.0))
                                    /  (mass*mass)
            ;  center            =     mcxVectorPowSum(vec_d, 2.0)
                                    /  mass
         ;  }
            else
            {  cube              =  sqrt(mcxVectorPowSum(vec_d, 3.0))
            ;  center            =  mcxVectorPowSum(vec_d, 2.0)

            ;  mcxVectorSelectGqBar(vec_d, alwaysBar)
            ;  mass              =  mcxVectorSum(vec_d)
         ;  }

         ;  n_pruned = vec_d->n_ivps

         ;  if (mcxTrackNonemaPruning)
               fprintf
               (  mcxTrackStreamNonema->fp
               ,  " max       cub       ctr       tTw"
                      "       bar       kept mass #kept\n"
                  " %.6f  %.6f  %.6f  %.6f [%.6f, %.6f, %d]\n"
               ,  maxval, cube, center, threeTwo
               ,  alwaysBar, mass,  vec_d->n_ivps
               )

         ;  if (maxDensity && (vec_d->n_ivps > maxDensity))
            {  float                hint1, hint2, hint3, hint4, hint5
            ;  int                  n_hint1, n_hint2, n_hint3, n_hint4, n_hint5

            ;  hint1             =  (  threeTwo
                                    /  threeTwoWeight
                                    )

            ;  hint2             =  (  center
                                    /  centerWeight
                                    )

            ;  hint3             =  (  cube
                                    /  cubeWeight
                                    )

            ;  hint4             =  (  maxval
                                    /  maxValWeight1
                                    )

            ;  hint5             =  (  maxval
                                    /  maxValWeight2
                                    )

            ;  n_hint1           =  mcxVectorCountGqBar(vec_d, hint1)
            ;  n_hint2           =  mcxVectorCountGqBar(vec_d, hint2)
            ;  n_hint3           =  mcxVectorCountGqBar(vec_d, hint3)
            ;  n_hint4           =  mcxVectorCountGqBar(vec_d, hint4)
            ;  n_hint5           =  mcxVectorCountGqBar(vec_d, hint5)

            ;  mcxIvpInstantiate(barIvps+0, n_hint1, hint1)
            ;  mcxIvpInstantiate(barIvps+1, n_hint2, hint2)
            ;  mcxIvpInstantiate(barIvps+2, n_hint3, hint3)
            ;  mcxIvpInstantiate(barIvps+3, n_hint4, hint4)
            ;  mcxIvpInstantiate(barIvps+4, n_hint5, hint5)

            ;  if (mcxTrackNonemaPruning)
               {  fprintf
                  (  mcxTrackStreamNonema->fp
                  ,  "[%s] hints, input size, size after blind prune\n"
                     "%8d| %8d| %8d| %8d| %8d| %8d -> %d\n"
                  ,  TRACK1
                  ,  n_hint1, n_hint2, n_hint3, n_hint4, n_hint5
                  ,  n_vec
                  ,  vec_d->n_ivps
                  )
               ;  fprintf
                  (  stderr
                  ,  "%.6f| %.6f| %.6f| %.6f| %.6f|       %.6f\n"
                  ,  hint1, hint2, hint3, hint4, hint5, alwaysBar
                  )
            ;  }
                              /*
                              // Sort hints according to how much they leave.
                              */

            ;  qsort(barIvps, 5, sizeof(mcxIvp), mcxIvpIdxCmp)

                              /*
                              // Try to find the best hint above maxDensity.
                              */

            ;  {  int u =
                     mcxSplitsearch
                     (  maxDensityIvp
                     ,  barIvps
                     ,  5
                     ,  sizeof(mcxIvp)
                     ,  mcxIvpIdxGeq
                     ,  1            /* return element right of split */
                     )

                              /*
                              // The best hint below maxDensity.
                              */

            ;     int l =  u-1

                              /*
                              // Case: all hints leave less than maxDensity.
                              */

               ;  if (u<0)
                  {  
                  ;  if (mcxTrackNonemaPruning) fprintf
                     (  mcxTrackStreamNonema->fp
                     ,  "[%s] Severe hints: Using [%d, %.6f] pair\n"
                     ,  TRACK1
                     ,  (barIvps+4)->idx
                     ,  (barIvps+4)->val
                     )
                  ;  mcxVectorSelectHighestWithHint
                     (  vec_d
                     ,  maxDensity
                     ,  (barIvps+4)->val
                     ,  (barIvps+4)->idx
                     )

                  ;  n_bestHint  =  (barIvps+4)->idx
               ;  }

                              /*
                              // Case: all hints leave more than maxDensity.
                              // Prune the one that is most severe.
                              */

                  else if (l<0)
                  {  
                  ;  mcxVectorSelectGqBar(vec_d, (barIvps+0)->val)

                  ;  if (mcxTrackNonemaPruning) fprintf
                     (  mcxTrackStreamNonema->fp
                     ,  "[%s] Loose hints: Pruning on [%d, %.6f] pair\n"
                     ,  TRACK1
                     ,  (barIvps+0)->idx
                     ,  (barIvps+0)->val
                     )
                  ;  mcxVectorSelectHighest(vec_d, maxDensity)

                  ;  n_bestHint  =  (barIvps+0)->idx
               ;  }

                  else
                  {  
                     int   n_u   =  (barIvps+u)->idx
                  ;  int   n_l   =  (barIvps+l)->idx

                  ;  if (mcxTrackNonemaPruning) fprintf
                     (  mcxTrackStreamNonema->fp
                     ,  "[%s] Both lower and upper hint exist:\n"
                        "[%d, %.6f] [%d, %.6f]\n"
                     ,  TRACK1
                     ,  n_l
                     ,  (barIvps+l)->val
                     ,  n_u
                     ,  (barIvps+u)->val
                     )

                  ;  if (abs(n_u - maxDensity) <= abs(maxDensity-n_l))
                     {  
                        if (mcxTrackNonemaPruning)
                           fprintf
                           (  mcxTrackStreamNonema->fp
                           ,  "[%s] Choosing upper\n"
                           ,  TRACK1
                           )

                     ;  mcxVectorSelectHighestWithHint
                        (  vec_d
                        ,  maxDensity
                        , (barIvps+u)->val
                        , (barIvps+u)->idx
                        )

                     ;  n_bestHint  =  (barIvps+u)->idx
                  ;  }
                     /* end upper lower hint is best                     */

                     else
                     {
                        if (mcxTrackNonemaPruning)
                           fprintf
                           (  mcxTrackStreamNonema->fp
                           ,  "[%s] Choosing lower\n"
                           ,  TRACK1
                           )

                     ;  mcxVectorSelectGqBar(vec_d, (barIvps+u)->val)
                     ;  mcxVectorSelectHighestWithHint
                        (  vec_d
                        ,  maxDensity
                        , (barIvps+l)->val
                        , (barIvps+l)->idx
                        )

                     ;  n_bestHint  =  (barIvps+l)->idx
                  ;  } /* end case lower hint is best                     */

               ;  } /* end case there are two hints.                      */
            ;  } /* end of block where hints are evaluated                */

         ;  if (stats->dbAllocated)
            mcxDistrStoreValue(stats->hDb, (float) n_bestHint )

         ;  }
           /*
            *  end case n_vec > maxDensity
            */

         ;  if (stats->dbAllocated)
            {  mass              =  mcxVectorSum(vec_d)
            ;  mcxDistrStoreValue(stats->vDb, (float) n_vec )
            ;  mcxDistrStoreValue(stats->pDb, (float) n_pruned )
            ;  mcxDistrStoreValue(stats->mDb, mass )
         ;  }
      ;  }

      ;  mcxVectorNormalize(vec_d)

      ;  maxval      =  mcxVectorMaxValue(vec_d)
      ;  threeTwo    =  (float) pow((double)mcxVectorPowSum(vec_d, 1.5), 2.0)

      ;  vectorInhomogeneity     =  (maxval-threeTwo) * vec_d->n_ivps

      ;  if (vectorInhomogeneity > matrixInhomogeneity)
         matrixInhomogeneity = vectorInhomogeneity
   ;  }

   ;  if (mclProgress)
      {  if (mclVerbosity)
         fprintf(stdout, "\n")
      ;  else
         fprintf(stdout, " %2.2f\n", matrixInhomogeneity)
   ;  }

   ;  mcxTrackNonemaPruning =  mainTrackPruning

   ;  mcxIvpStorageFreeIfNot(0)
   ;  rqFree(barIvps)
   ;  mcxIvpFree(&maxDensityIvp)

   ;  stats->inhomogeneity =  matrixInhomogeneity
   ;  return mx_d
;  }


mcxComposeStats* mcxComposeStatsNew
(  int   dbSize
)  {  
      mcxComposeStats* stats  =  (mcxComposeStats*) rqAlloc
                                 (  sizeof(mcxComposeStats)
                                 ,  EXIT_ON_FAIL
                                 )

   ;  stats->vDb              =  dbSize ? mcxDistrNew(dbSize) : NULL
   ;  stats->pDb              =  dbSize ? mcxDistrNew(dbSize) : NULL
   ;  stats->hDb              =  dbSize ? mcxDistrNew(dbSize) : NULL
   ;  stats->mDb              =  dbSize ? mcxDistrNew(dbSize) : NULL

   ;  stats->dbAllocated      =  dbSize ? 1 : 0

   ;  if (  dbSize &&
            (!stats->vDb || !stats->pDb || !stats->hDb || !stats->mDb )
         )
      {  fprintf
         (  stderr
         ,  "[mcxComposeStatsNew] could not allocate all four distributions"
            " (each of size %d)\n"
         ,  dbSize
         )
      ;  exit(1)
   ;  }

   ;  stats->inhomogeneity    =  0.0
   ;  stats->n_selectHighest  =  0

   ;  (stats->dbList)[0]      =  stats->mDb
   ;  (stats->dbList)[1]      =  stats->vDb
   ;  (stats->dbList)[2]      =  stats->pDb
   ;  (stats->dbList)[3]      =  stats->hDb

   ;  return stats
;  }

void mcxComposeStatsFree
(mcxComposeStats* stats
)  {  mcxDistrFree(&(stats->vDb))
   ;  mcxDistrFree(&(stats->pDb))
   ;  mcxDistrFree(&(stats->hDb))
   ;  mcxDistrFree(&(stats->mDb))
   ;  rqFree(stats)
;  }

void mcxComposeStatsReset
(mcxComposeStats* stats
)  {  if (stats->vDb)
         mcxDistrClear(stats->vDb)
   ;  if (stats->pDb)
         mcxDistrClear(stats->pDb)
   ;  if (stats->hDb)
         mcxDistrClear(stats->hDb)
   ;  if (stats->mDb)
         mcxDistrClear(stats->mDb)
   ;  stats->inhomogeneity    =  0.0
   ;  stats->n_selectHighest  =  0
;  }

void mcxComposeStatsPrint
(  mcxComposeStats*  stats
,  FILE*             fp
)
   {  mcxDistr**  dbList  =  stats->dbList
   ;  mcxDistr*   db
   ;  float    av, dv
   ;  int      i

   ;  for(i=0;i<4;i++)
      {  db    =  dbList[i]

      ;  av    =  mcxDistrGetAverage(db)
      ;  dv    =  mcxDistrGetDeviation(db)

      ;  if (db == stats->mDb)
            fprintf(fp, "%6.2f|%-6d", av, stats->hDb->N)
      ;  else
            fprintf(fp, "%6.0f,%-6.0f", av, dv)
   ;  }
   ;  fprintf(fp, " %6.2f|", stats->inhomogeneity)
;  }


void ivpHeapInsert
(  mcxIvp* vecIvp
,  int rootidx
)  {
      int   lftidx   =  2*rootidx+1

   ;  if (lftidx >= ivpHeapSize)          /* at leaf level */
      *(ivpHeap+rootidx)  =  vecIvp

   ;  else
      {  int dstidx  =  (*(ivpHeap+lftidx))->val <= (*(ivpHeap+lftidx+1))->val
                     ?  lftidx
                     :  lftidx + 1
      ;  if (vecIvp->val > (*(ivpHeap+dstidx))->val)
         {  *(ivpHeap+rootidx)   =  *(ivpHeap+dstidx)
         ;  ivpHeapInsert(vecIvp, dstidx)
      ;  }
         else
         *(ivpHeap+rootidx)      =  vecIvp
   ;  }
;  }

