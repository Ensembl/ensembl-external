/*
// compose.c            MCL specific compose
*/

#include <math.h>
#include <limits.h>
#include <float.h>
#include <pthread.h>

#include "nonema/compose.h"
#include "nonema/ivp.h"
#include "nonema/vector.h"
#include "nonema/iface.h"

#include "mcl/compose.h"
#include "mcl/params.h"

#include "intalg/ilist.h"

#include "util/alloc.h"
#include "util/types.h"
#include "util/heap.h"
#include "util/minmax.h"


static const char* tags    =  "0123456789@";
static int cloning         =  0;


static int   levels[]
=  {
      8000
   ,  5000
   ,  3000
   ,  2000
   ,  1250

   ,  800
   ,  500
   ,  300
   ,  200
   ,  125

   ,  80
   ,  50
   ,  30
   ,  20
   ,  12
   ,  -1
   }  ;     /* ~ magstep 5sqrt10 */


int n_levels   =  sizeof(levels)/sizeof(int) ;


static  mcxVector*   inhVec   =  NULL;


static void levelAccount
(  
   int   size
,  char  levelType
)  ;


void mcxNewFlowVector_thread
(
   void* arg
)  ;


static struct
{
   mcxHeap*       worstXprune
;  mcxHeap*       worstYprune
;  mcxHeap*       worstXfinal
;  mcxHeap*       worstYfinal

;  Ilist*         ilLevelsC
;  Ilist*         ilLevelsP

;  float          sum_prune_all
;  float          sum_final_all

;  int            n_selects
;  int            n_recoveries
;  int            n_below_pct
;  int            n_vectors
;
}  reg
   =  
   {  NULL, NULL, NULL, NULL
   ,  NULL, NULL
   ,  0.0,  0.0
   ,  0,    0,    0,    0  
   }  ;
  /*  Registry for statistics  */


float mcxNewFlowVector
(
   const mcxMatrix*  mx
,  const mcxVector*  vec_s                      /* src                     */
,  mcxVector*        vec_d                      /* dst                     */
,  mcxVector*        tmpVec
,  mcxVector*        ivpVec
)  ;


typedef struct
{
   int               id
;  int               start
;  int               end
;  mcxMatrix*        mxs
;  mcxMatrix*        mxd
;  mcxVector*        tmpVec
;  mcxVector*        ivpVec
;
}  mcxNewFlowVector_thread_arg
   ;


static pthread_mutex_t  reg_mutex   =     PTHREAD_MUTEX_INITIALIZER;
extern pthread_t        *threads_expand;        /* defined in mcl/mcl.c   */
static pthread_attr_t   pthread_custom_attr;


static void vecMeasure
(
   mcxVector*        vec
,  float             *maxval
,  float             *center
)  ;


mcxComposeParam* mcxComposeParamNew
(  void
)  
   {  
      mcxComposeParam *cpParam      =     (mcxComposeParam*) rqAlloc
                                          (  sizeof(mcxComposeParam)
                                          ,  EXIT_ON_FAIL
                                          )

   ;  cpParam->maxDensity           =     200
   ;  cpParam->precision            =     0.001
   ;  return cpParam
;  }


void mcxNewFlowVector_thread
(
   void* arg
)
   {
      mcxNewFlowVector_thread_arg *a =  (mcxNewFlowVector_thread_arg *) arg

   ;  mcxVector*           tmpVec   =  a->tmpVec
   ;  mcxVector*           ivpVec   =  a->ivpVec
   ;  mcxMatrix*           mxs      =  a->mxs
   ;  mcxMatrix*           mxd      =  a->mxd

   ;  const mcxVector*     srcVec   =  mxs->vectors + a->start
   ;  const mcxVector*     srcMax   =  mxs->vectors + a->end
   ;  mcxVector*           dstVec   =  mxd->vectors + a->start
   ;  mcxVector*           dstMax   =  mxd->vectors + a->end
   ;  int                  vecIdx   =  a->start
  /*
   *  cutcof, cutfac, dense, recover, are globally scoped
   *  variables accessed by mcxNewFlowVector.
  */

   ;  while (srcVec < srcMax)
      {
         float colInhomogeneity
         =  mcxNewFlowVector
            (
               mxs
            ,  srcVec
            ,  dstVec
            ,  tmpVec
            ,  ivpVec
            )
      ;  (inhVec->ivps+vecIdx)->val = colInhomogeneity
      ;  srcVec++, dstVec++, vecIdx++
   ;  }

   ;  mcxVectorFree(&tmpVec)
   ;  mcxVectorFree(&ivpVec)

   ;  if (a->id && cloning)
      mcxMatrixFree(&mxs)

   ;  free(a)
;  }


float mcxNewFlowVector
(
   const mcxMatrix*  mx
,  const mcxVector*  vecs                      /* src                     */
,  mcxVector*        vecd                      /* dst                     */
,  mcxVector*        tmpVec
,  mcxVector*        ivpVec
)
   {
      int            rg_n_compose   =  0
   ;  int            rg_n_prune     =  0

   ;  mcxbool        rg_b_recover   =  mcxFALSE
   ;  mcxbool        rg_b_select    =  mcxFALSE

   ;  float          rg_mass_prune  =  0.0

   ;  float          rg_sbar        =  -1.0     /*    select bar           */
   ;  float          rg_rbar        =  -1.0     /*    recovery bar         */

   ;  float          rg_mass_final  =  1.0
   ;  float          cut            =  0.0
                     
   ;  float          maxval, center, colInhomogeneity, cut_adapt

   ;  if (mclModeCompose == MCL_COMPOSE_DENSE)
      mcxMatrixVectorDenseCompose
      (  mx
      ,  vecs
      ,  vecd
      )
   ;  else
      mcxMatrixVectorCompose
      (  mx
      ,  vecs
      ,  vecd
      ,  ivpVec
      )

   ;  rg_n_compose         =  vecd->n_ivps ? vecd->n_ivps : 1


   ;  if (mclRecover && mclMarknum)
      {  
         memcpy(tmpVec->ivps, vecd->ivps, vecd->n_ivps * sizeof(mcxIvp))
      ;  tmpVec->n_ivps = vecd->n_ivps
   ;  }


   ;  if (mclModePruning == MCL_PRUNING_RIGID)
      {
         if (mclPrecision)
         {  
            cut            =  mclPrecision
         ;  rg_mass_prune  =  mcxVectorSelectGqBar (vecd, cut)
         ;  rg_n_prune     =  vecd->n_ivps
      ;  }
         else
         {
            rg_mass_prune  =  mcxVectorSum(vecd)
         ;  rg_n_prune     =  vecd->n_ivps
      ;  }
      ;  vecMeasure(vecd, &maxval, &center)
   ;  }

      else if (mclModePruning == MCL_PRUNING_ADAPT || 1)
      {
         vecMeasure(vecd, &maxval, &center)

      ;  cut_adapt         =  (1/mclCutCof)
                           *  center
                           *  pow(center/maxval,mclCutExp)

      ;  cut               =  float_MAX(cut_adapt, mclPrecision)
      ;  rg_mass_prune     =  mcxVectorSelectGqBar(vecd, cut)
      ;  rg_n_prune        =  vecd->n_ivps
   ;  }


   ;  if (!mclMarknum)

   ;  else if
      (
         rg_n_prune > mclMarknum
      )
      {
         rg_b_select       =  mcxTRUE

      ;  if (mclSelect)
         {
            if (rg_n_prune >= 2*mclMarknum)
            rg_sbar
            =  mcxVectorKBar
               (  vecd
               ,  mclMarknum
               ,  FLT_MAX
               ,  KBAR_SELECT_LARGE
               )
         ;  else
            rg_sbar
            =  mcxVectorKBar
               (  vecd
               ,  vecd->n_ivps - mclMarknum+1
               ,  -FLT_MAX
               ,  KBAR_SELECT_SMALL
               )
      ;  }
   ;  }

      else if
      (  
         rg_n_prune     <  mclMarknum
      && rg_mass_prune  <  mclPct
      )
      {
         rg_b_recover      =  mcxTRUE

      ;  if (mclRecover)
         {  
            mcxVectorInstantiate(vecd, tmpVec->n_ivps, tmpVec->ivps)

         ;  if (vecd->n_ivps > mclMarknum)      /* use cut previously      */
            rg_rbar                             /* computed.               */
            =  mcxVectorKBar                    /* we should check         */
            (  vecd                             /* whether it is any use   */
            ,  mclMarknum - rg_n_prune          /* (but we don't)          */
            ,  cut
            ,  KBAR_SELECT_LARGE
            )
         ;  else
            rg_rbar = 0.0
      ;  }
   ;  }
      else
      {
        /*
         *     mclMarknum > 0
         *  ,  rg_n_prune < mclMarknum
         *  ,  rg_mass_prune >= mclPct
        */
   ;  }


   ;  if (rg_sbar >= 0.0)
      rg_mass_final     =  mcxVectorSelectGqBar(vecd, rg_sbar)

   ;  else if (rg_rbar >= 0.0)
      rg_mass_final     =  mcxVectorSelectGqBar(vecd, rg_rbar)

   ;  else
      rg_mass_final     =  rg_mass_prune


   ;  mcxVectorScale(vecd, rg_mass_final)
   ;  colInhomogeneity  =  (maxval-center) * vecd->n_ivps
   ;


     /*
     /*  expansion threads only have read & write access to reg
     /*  in the block below and nowhere else.
     */

      if (mclVerbosityPruning || mclVerbosityVectorProgress)
      {
         if (mcl_num_ethreads)
         pthread_mutex_lock(&reg_mutex)

      ;  if (mclVerbosityPruning)
         {
            levelAccount(rg_n_compose, 'c')
         ;  levelAccount(rg_n_prune, 'p')

         ;  mcxHeapInsert(reg.worstXprune, &rg_mass_prune)
         ;  mcxHeapInsert(reg.worstYprune, &rg_mass_prune)
         ;  reg.sum_prune_all +=  rg_mass_prune

         ;  mcxHeapInsert(reg.worstXfinal, &rg_mass_final)
         ;  mcxHeapInsert(reg.worstYfinal, &rg_mass_final)
         ;  reg.sum_final_all    +=  rg_mass_final

         ;  if (rg_b_select)
            reg.n_selects++

         ;  if (rg_b_recover)
            reg.n_recoveries++

         ;  if (rg_mass_final < mclPct)
            reg.n_below_pct++
      ;  }

         if (mclVerbosityVectorProgress)
         {
            reg.n_vectors++

         ;  if (reg.n_vectors % mclVectorProgression == 0)
            fwrite(".", sizeof(char), 1, stdout)
         ,  fflush(stdout)
      ;  }

         if (mcl_num_ethreads)
         pthread_mutex_unlock(&reg_mutex)
   ;  }

   ;  return colInhomogeneity
;  }


mcxMatrix* mcxFlowExpand
(  
   const mcxMatrix*        mx
,  mcxComposeStats*        stats
)
   {
      mcxMatrix*           mx_d
   ;  mcxVector*           tmpVec         =  mcxVectorCreate(mx->N_rows)  
   ;  mcxVector*           ivpVec         =  mcxVectorCreate(mx->N_rows+1)  
   ;  int                  col            =  0

   ;  if (mx->N_cols != mx->N_rows)
         fprintf(stderr, "[mcxFlowExpand PBD] matrix not square\n")
      ,  exit(1)

   ;  mx_d                 =  mcxMatrixAllocZero(mx->N_rows, mx->N_cols)

   ;  inhVec   =  mcxVectorComplete(inhVec, mx->N_cols, 1.0)

   ;  mcxComposeStatsReset(stats)
   ;

     /*
     /*  Initialization of the registry. Here information is stored
     /*  which is eventually used to compute a bunch of statistics.
     /*  Probably nobody cares about this stuff, but I want it in.
     */

      {  
         reg.worstXprune   =  mcxHeapNew
                              (stats->nx,sizeof(float),fltCmp,MAX_HEAP)
      ;  reg.worstYprune   =  mcxHeapNew
                              (stats->ny,sizeof(float),fltCmp,MAX_HEAP)
      ;  reg.worstXfinal   =  mcxHeapNew
                              (stats->nx,sizeof(float),fltCmp,MAX_HEAP)
      ;  reg.worstYfinal   =  mcxHeapNew
                              (stats->ny,sizeof(float),fltCmp,MAX_HEAP)

      ;  reg.sum_final_all=  0.0
      ;  reg.sum_prune_all =  0.0

      ;  reg.n_selects     =  0
      ;  reg.n_recoveries  =  0
      ;  reg.n_below_pct   =  0
      ;  reg.n_vectors     =  0

      ;  reg.ilLevelsC     =  ilInstantiate(reg.ilLevelsC,n_levels, NULL, 0)
      ;  reg.ilLevelsP     =  ilInstantiate(reg.ilLevelsP, n_levels, NULL, 0)
   ;  }


   ;  if (mcl_num_ethreads)
      {
         int   i
      ;  int   workLoad    =  mx->N_cols / mcl_num_ethreads
      ;  int   workTail    =  mx->N_cols % mcl_num_ethreads

      ;  cloning           =  (  mclCloneMatrices
                              && (  mcxMatrixNrofEntries(mx) 
                                 >  mclCloneBarrier* mx->N_cols
                                 )
                              )
      ;  if (cloning && !mclVerbosityPruning)
         fprintf(stdout, "(cloning) ")

      ;  pthread_attr_init(&pthread_custom_attr)

      ;  for (i=0;i<mcl_num_ethreads;i++)
         {
            mcxNewFlowVector_thread_arg *a
                           =  (mcxNewFlowVector_thread_arg *)
                              malloc(sizeof(mcxNewFlowVector_thread_arg))
         ;  a->id          =  i
         ;  a->start       =  workLoad * i
         ;  a->end         =  workLoad * (i+1)
         ;  a->mxd         =  mx_d
         ;  a->tmpVec      =  mcxVectorCreate(mx->N_rows)
         ;  a->ivpVec      =  mcxVectorCreate(mx->N_rows+1)

         ;  a->mxs         =  (i && cloning)   /* thread 0 accesses original */
                              ?  mcxMatrixCopy(mx)
                              :  (mcxMatrix*) mx

         ;  if (i+1==mcl_num_ethreads)
            a->end   +=  workTail

         ;  pthread_create
            (  &threads_expand[i]
            ,  &pthread_custom_attr
            ,  (void *) mcxNewFlowVector_thread
            ,  (void *) a
            )
      ;  }

      ;  for (i = 0; i < mcl_num_ethreads; i++)
         pthread_join(threads_expand[i], NULL)
   ;  }

      else for (col=0;col<mx->N_cols;col++)
      {
         mcxVector*  vec_d          =  mx_d->vectors + col

      ;  float colInhomogeneity
         =  mcxNewFlowVector
            (  mx
            ,  mx->vectors+col
            ,  mx_d->vectors+col
            ,  tmpVec
            ,  ivpVec
            )
      ;  (inhVec->ivps+col)->val = colInhomogeneity
   ;  }

   ;  stats->inhomogeneity    =  mcxVectorMaxValue(inhVec)

     /*
     /*  All but the level accounting part of the registry.
     /*  Transferral of information from registry to stats.
     */

   ;  {
         int   x, y

      ;  float sumx_prune     =  0.0
      ;  float sumy_prune     =  0.0

      ;  float sumx_final     =  0.0
      ;  float sumy_final     =  0.0

      ;  if (reg.worstXprune->n_inserted)
         {
            float*   flp         =  (float *) reg.worstXprune->base  

         ;  for (x=0;x<reg.worstXprune->n_inserted;x++)
            sumx_prune += *(flp+x)
         ;  stats->mass_prune_nx =  sumx_prune/reg.worstXprune->n_inserted
      ;  }

      ;  if (reg.worstYprune->n_inserted)
         {
            float*   flp         =  (float *) reg.worstYprune->base  

         ;  for (y=0;y<reg.worstYprune->n_inserted;y++)
            sumy_prune += *(flp+y)
         ;  stats->mass_prune_ny =  sumy_prune/reg.worstYprune->n_inserted
      ;  }

         ;  if (reg.worstXfinal->n_inserted) { /* patch */
            float*   flp         =  (float *) reg.worstXfinal->base

         ;  for (x=0;x<reg.worstXfinal->n_inserted;x++)
            sumx_final += *(flp+x)
         ;  stats->mass_final_nx =  sumx_final/reg.worstXfinal->n_inserted
                                        /* BUG: 0.0/0 here! */
      ;  }

         ;  if (reg.worstYfinal->n_inserted) /* patched */
         {
            float*   flp         =  (float *) reg.worstYfinal->base

         ;  for (y=0;y<reg.worstYfinal->n_inserted;y++)
            sumy_final += *(flp+y)
         ;  stats->mass_final_ny =  sumy_final/reg.worstYfinal->n_inserted
      ;  }

      ;  stats->mass_prune_all   =  reg.sum_prune_all/mx->N_cols
      ;  stats->mass_final_all   =  reg.sum_final_all/mx->N_cols

      ;  mcxHeapFree(&reg.worstXprune)
      ;  mcxHeapFree(&reg.worstYprune)
      ;  mcxHeapFree(&reg.worstXfinal)
      ;  mcxHeapFree(&reg.worstYfinal)

      ;  stats->n_recoveries     =  reg.n_recoveries
      ;  stats->n_below_pct      =  reg.n_below_pct

      ;  if (reg.n_selects)
         stats->n_selects        =  reg.n_selects
   ;  }


     /*
     /*  The level accounting part of the registry.
     /*  Transferral of information from registry to stats.
     */

   ;  {
         int   x, y
      ;  int   n_levels_p        =  reg.ilLevelsP->n
      ;  int   n_levels_c        =  reg.ilLevelsC->n

      ;  char *cString           =  (char*) rqAlloc(n_levels_c+1, EXIT_ON_FAIL)
      ;  char *pString           =  (char*) rqAlloc(n_levels_p+1, EXIT_ON_FAIL)
      
      ;  pString[n_levels_p-1]   =  '\0'
      ;  cString[n_levels_c-1]   =  '\0'

      ;  ilAccumulate(reg.ilLevelsC)
      ;  ilAccumulate(reg.ilLevelsP)

      ;  for (x=0;x<n_levels_c-1;x++)
         {  int   n              =  *(reg.ilLevelsC->list+x)
         ;  cString[x]           =     n == 0
                                    ?  '_'
                                    :  tags[((1000*n / (mx->N_cols))+50) / 100]
      ;  }

      ;  for (x=0;x<n_levels_p-1;x++)
         {  int   n              =  *(reg.ilLevelsP->list+x)
         ;  pString[x]           =     n == 0
                                    ?  '_'
                                    :  tags[((1000*n / (mx->N_cols))+50) / 100]
      ;  }

      ;  stats->levels_compose   =  mcxTxtNew(cString)
      ;  stats->levels_prune     =  mcxTxtNew(pString)
      ;  rqFree(cString)
      ;  rqFree(pString)
   ;  }

   ;  mcxVectorFree(&tmpVec)
   ;  mcxVectorFree(&ivpVec)

   ;  return mx_d
;  }


mcxComposeStats* mcxComposeStatsNew
(  
   int   nx
,  int   ny
)  
   {  
      mcxComposeStats* stats  =  (mcxComposeStats*) rqAlloc
                                 (  
                                    sizeof(mcxComposeStats)
                                 ,  EXIT_ON_FAIL
                                 )

   ;  stats->nx               =  nx
   ;  stats->ny               =  ny

   ;  stats->inhomogeneity    =  0.0
   ;  stats->n_selects        =  0
   ;  stats->n_recoveries     =  0
   ;  stats->n_below_pct      =  0

   ;  stats->mass_final_nx   =  0.0
   ;  stats->mass_final_ny   =  0.0
   ;  stats->mass_final_all  =  0.0

   ;  stats->mass_prune_nx    =  0.0
   ;  stats->mass_prune_ny    =  0.0
   ;  stats->mass_prune_all   =  0.0

   ;  stats->levels_compose   =  NULL
   ;  stats->levels_prune     =  NULL

   ;  return stats
;  }


void mcxComposeStatsFree
(
   mcxComposeStats* stats
)  
   {  
      mcxTxtFree(&(stats->levels_compose))
   ;  mcxTxtFree(&(stats->levels_prune))
   ;  rqFree(stats)
;  }


void mcxComposeStatsReset
(  mcxComposeStats* stats
)  
   {  
      stats->inhomogeneity    =  0.0
   ;  stats->n_selects        =  0
   ;  stats->n_recoveries     =  0
   ;  stats->n_below_pct      =  0

   ;  stats->mass_prune_nx    =  0.0
   ;  stats->mass_prune_ny    =  0.0
   ;  stats->mass_prune_all   =  0.0

   ;  stats->mass_final_nx   =  0.0
   ;  stats->mass_final_ny   =  0.0
   ;  stats->mass_final_all  =  0.0

   ;  mcxTxtFree(&(stats->levels_compose))
   ;  mcxTxtFree(&(stats->levels_prune))
;  }


void mcxComposeStatsPrint
(  
   mcxComposeStats*  stats
,  FILE*             fp
)
   {
      fprintf
      (  fp
      ,  "%3d%3d%3d %3d%3d%3d %s %s %-7d %-7d %-7d"
      ,  (int) (100.0*stats->mass_prune_all)
      ,  (int) (100.0*stats->mass_prune_ny)
      ,  (int) (100.0*stats->mass_prune_nx)
      ,  (int) (100.0*stats->mass_final_all)
      ,  (int) (100.0*stats->mass_final_ny)
      ,  (int) (100.0*stats->mass_final_nx)
      ,  stats->levels_compose->str
      ,  stats->levels_prune->str
      ,  stats->n_recoveries
      ,  stats->n_selects
      ,  stats->n_below_pct
      )
;  }


static void levelAccount
(  
   int   size
,  char  levelType
)
   {  
      int   i  =  0

   ;  while (size < levels[i] && i<n_levels)
      i++

   ;  if (levelType == 'c')
      (*(reg.ilLevelsC->list+i))++

   ;  else if (levelType == 'p')
      (*(reg.ilLevelsP->list+i))++
;  }


static void vecMeasure
(  
   mcxVector*  vec
,  float       *maxval
,  float       *center
)  
   {
      mcxIvp*  ivp      =  vec->ivps
   ;  int      n_ivps   =  vec->n_ivps
   ;  float    m        =  0.0
   ;  float    c        =  0.0

   ;  while (--n_ivps >= 0)
      {  
         float val      =  (ivp++)->val

      ;  c += val * val

      ;  if (val > m)
         m = val
   ;  }

   ;  *maxval           =  m
   ;  *center           =  c
;  }

