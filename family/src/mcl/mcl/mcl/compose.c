/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <math.h>
#include <limits.h>
#include <float.h>
#include <pthread.h>

#include "compose.h"
#include "params.h"

#include "util/alloc.h"
#include "util/types.h"
#include "util/heap.h"
#include "util/minmax.h"

#include "nonema/compose.h"
#include "nonema/ivp.h"
#include "nonema/vector.h"
#include "nonema/iface.h"

#include "intalg/ilist.h"


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


static  mclVector*   ihvec_g   =  NULL;


static void levelAccount
(  int   size
,  char  levelType
)  ;


void mclNewFlowVector_thread
(  void* arg
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


float mclNewFlowVector
(  const mclMatrix*  mx
,  const mclVector*  vec_s       /* src                         */
,  mclVector*        vec_d       /* dst                         */
,  mclVector*        cpyVec      /* backup storage for recovery */
,  mclVector*        ivpVec      /* large storage for computing */
,  int               col
)  ;


typedef struct
{
   int               id
;  int               start
;  int               end
;  mclMatrix*        mxs
;  mclMatrix*        mxd
;
}  mclNewFlowVector_thread_arg
   ;


static pthread_mutex_t  reg_mutex   =     PTHREAD_MUTEX_INITIALIZER;
extern pthread_t        *threads_expand;        /* defined in mcl/mcl.c   */
static pthread_attr_t   pthread_custom_attr;


static void vecMeasure
(  mclVector*        vec
,  float             *maxval
,  float             *center
)  ;


mclComposeParam* mclComposeParamNew
(  void
)  
   {  mclComposeParam *cpParam      =     (mclComposeParam*) mcxAlloc
                                          (  sizeof(mclComposeParam)
                                          ,  EXIT_ON_FAIL
                                          )

   ;  cpParam->maxDensity           =     200
   ;  cpParam->precision            =     0.001
   ;  return cpParam
;  }


void mclNewFlowVector_thread
(  void* arg
)
   {  mclNewFlowVector_thread_arg *a =  (mclNewFlowVector_thread_arg *) arg
   ;  mclMatrix*           mxs      =  a->mxs
   ;  mclMatrix*           mxd      =  a->mxd
   ;  mclVector*           cpyVec   =  mclVectorCreate(mxs->N_rows)  
   ;  mclVector*           ivpVec   =  mclVectorCreate(mxs->N_rows+1)  
   ;  int                  colidx   =  a->start
   ;
      for (colidx = a->start; colidx < a->end; colidx++)
      {
         float colInhomogeneity
         =  mclNewFlowVector
            (  mxs
            ,  mxs->vectors + colidx
            ,  mxd->vectors + colidx
            ,  cpyVec      /* backup storage for recovery */
            ,  ivpVec      /* large storage for computing */
            ,  colidx
            )
      ;  (ihvec_g->ivps+colidx)->val = colInhomogeneity
   ;  }

   ;  mclVectorFree(&cpyVec)
   ;  mclVectorFree(&ivpVec)

   ;  if (a->id && cloning)
      mclMatrixFree(&mxs)

   ;  free(a)
;  }


float mclNewFlowVector
(  const mclMatrix*  mx
,  const mclVector*  vec_s                     /* src                     */
,  mclVector*        vec_d                     /* dst                     */
,  mclVector*        cpyVec
,  mclVector*        ivpVec
,  int               col
)
   {  int            rg_n_compose   =  0
   ;  int            rg_n_prune     =  0

   ;  mcxbool        rg_b_recover   =  FALSE
   ;  mcxbool        rg_b_select    =  FALSE

   ;  float          rg_mass_prune  =  0.0

   ;  float          rg_sbar        =  -1.0     /*    select bar           */
   ;  float          rg_rbar        =  -1.0     /*    recovery bar         */

   ;  float          rg_mass_final  =  1.0
   ;  float          cut            =  0.0
   ;  mcxbool        mesg           =  FALSE
                     
   ;  float          maxval, center, colInhomogeneity, cut_adapt

   ;  if (mclModeCompose == MCL_COMPOSE_DENSE)
      mclMatrixVectorDenseCompose
      (  mx
      ,  vec_s
      ,  vec_d
      )
   ;  else
      mclMatrixVectorCompose
      (  mx
      ,  vec_s
      ,  vec_d
      ,  ivpVec
      )

   ;  rg_n_compose         =  vec_d->n_ivps ? vec_d->n_ivps : 1

   ;  if (mclRecoverNumber)
      {  memcpy(cpyVec->ivps, vec_d->ivps, vec_d->n_ivps * sizeof(mclIvp))
      ;  cpyVec->n_ivps = vec_d->n_ivps
   ;  }


   ;  if (mclModePruning == MCL_PRUNING_RIGID)
      {  vecMeasure(vec_d, &maxval, &center)
      ;  if (mclPrecision)
         {  cut            =  mclPrecision
         ;  rg_mass_prune  =  mclVectorSelectGqBar (vec_d, cut)
      ;  }
         else
         {  rg_mass_prune  =  mclVectorSum(vec_d)
      ;  }
      ;  rg_n_prune        =  vec_d->n_ivps
      ;  rg_mass_final     =  rg_mass_prune
   ;  }

      else if (mclModePruning == MCL_PRUNING_ADAPT)
      {  vecMeasure(vec_d, &maxval, &center)
      ;  cut_adapt         =  (1/mclCutCof)
                              *  center
                              *  pow(center/maxval,mclCutExp)
      ;  cut               =  MAX(cut_adapt, mclPrecision)
      ;  rg_mass_prune     =  mclVectorSelectGqBar(vec_d, cut)
      ;  rg_n_prune        =  vec_d->n_ivps
      ;  rg_mass_final     =  rg_mass_prune
   ;  }
      
      else
      {  /* E.g. DENSE mode. */
   ;  }

   ;  if
      (  mclWarnFactor
      && (  mclWarnFactor * MAX(vec_d->n_ivps, mclSelectNumber) < rg_n_compose
            && rg_mass_prune < mclWarnPct
         )
      )
      {  
         mesg = TRUE
      ;  fprintf
         (  stderr,
         "\n"
         "___> Vector with idx [%d], maxval [%.6f] and [%d] composed entries\n"
         " ->  initially reduced to [%d] entries with combined mass [%.6f].\n"
         " ->  Consider increasing the -P value and %s the -S value.\n"
         ,  col
         ,  maxval
         ,  rg_n_compose
         ,  vec_d->n_ivps
         ,  rg_mass_prune
         ,  mclSelectNumber ? "increasing" : "using"
         )
   ;  }

      if (!mclRecoverNumber && !vec_d->n_ivps)
      {
         mclVectorInstantiate(vec_d, 1, NULL)
      ;  (vec_d->ivps+0)->idx = col
      ;  (vec_d->ivps+0)->val = 1.0
      ;  rg_mass_prune  =  1.0
      ;  rg_n_prune     =  1
      ;  if (mclWarnFactor)
         fprintf(stderr, " ->  Emergency measure: added loop to node\n")
   ;  }

      if
      (  mclRecoverNumber
      && (  vec_d->n_ivps  <  mclRecoverNumber)
      && (  rg_mass_prune  <  mclPct)
      )
      {
         int recnum     =  mclRecoverNumber
      ;  rg_b_recover   =  TRUE
      ;  mclVectorInstantiate(vec_d, cpyVec->n_ivps, cpyVec->ivps)

      ;  if (vec_d->n_ivps > recnum)         /* use cut previously      */
         rg_rbar                             /* computed.               */
         =  mclVectorKBar                    /* we should check         */
         (  vec_d                            /* whether it is any use   */
         ,  recnum - rg_n_prune              /* (but we don't)          */
         ,  cut
         ,  KBAR_SELECT_LARGE
         )
      ;  else
         rg_rbar = 0.0

      ;  rg_mass_final     =  mclVectorSelectGqBar(vec_d, rg_rbar)
   ;  }

      else if (mclSelectNumber && vec_d->n_ivps > mclSelectNumber)
      {
         float mass_select
      ;  int   n_select
      ;  rg_b_select       =  TRUE

      ;  if (mclRecoverNumber)         /* recovers to post prune vector */
         {  memcpy(cpyVec->ivps, vec_d->ivps, vec_d->n_ivps * sizeof(mclIvp))
         ;  cpyVec->n_ivps = vec_d->n_ivps
      ;  }

      ;  if (vec_d->n_ivps >= 2*mclSelectNumber)
         rg_sbar
         =  mclVectorKBar
            (  vec_d
            ,  mclSelectNumber
            ,  FLT_MAX
            ,  KBAR_SELECT_LARGE
            )
      ;  else
         rg_sbar
         =  mclVectorKBar
            (  vec_d
            ,  vec_d->n_ivps - mclSelectNumber + 1
            ,  -FLT_MAX          /* values < cut are already removed */
            ,  KBAR_SELECT_SMALL
            )

      ;  mass_select       =  mclVectorSelectGqBar(vec_d, rg_sbar)
      ;  rg_mass_final     =  mass_select
      ;  n_select          =  vec_d->n_ivps

      ;  if
         (  mclRecoverNumber
         && (  vec_d->n_ivps  <  mclRecoverNumber)
         && (  mass_select    <  mclPct)
         )
         {
            int recnum     =  mclRecoverNumber
         ;  rg_b_recover   =  TRUE
         ;  mclVectorInstantiate(vec_d, cpyVec->n_ivps, cpyVec->ivps)

         ;  if (vec_d->n_ivps > recnum)         /* use cut previously   */
            rg_rbar                             /* computed.            */
            =  mclVectorKBar                    /* we should check      */
            (  vec_d                            /* whether it is any use*/
            ,  recnum - n_select                /* (but we don't)       */
            ,  rg_sbar
            ,  KBAR_SELECT_LARGE
            )
         ;  else
            rg_rbar = 0.0

         ;  rg_mass_final  =  mclVectorSelectGqBar(vec_d, rg_rbar)
      ;  }
   ;  }

      if (mesg)
      fprintf
      (  stderr
      ,  " ->  (before rescaling) Finished with [%d] entries and [%f] mass.\n"
      ,  vec_d->n_ivps
      ,  rg_mass_final
      )

   ;  if (rg_mass_final)
      mclVectorScale(vec_d, rg_mass_final)

   ;  colInhomogeneity  =  (maxval-center) * vec_d->n_ivps
   ;


     /*
     /*  expansion threads only have read & write access to reg
     /*  in the block below and nowhere else.
     */

      if (1 || mclVerbosityPruning || mclVerbosityVectorProgress)
      {
         if (mcl_num_ethreads)
         pthread_mutex_lock(&reg_mutex)

      ;  levelAccount(rg_n_compose, 'c')
      ;  levelAccount(rg_n_prune, 'p')

      ;  mcxHeapInsert(reg.worstXprune, &rg_mass_prune)
      ;  mcxHeapInsert(reg.worstYprune, &rg_mass_prune)
      ;  reg.sum_prune_all +=  rg_mass_prune

      ;  mcxHeapInsert(reg.worstXfinal, &rg_mass_final)
      ;  mcxHeapInsert(reg.worstYfinal, &rg_mass_final)
      ;  reg.sum_final_all +=  rg_mass_final

      ;  if (rg_b_select)
         reg.n_selects++

      ;  if (rg_b_recover)
         reg.n_recoveries++

      ;  if (rg_mass_final < mclPct)
         reg.n_below_pct++

      ;  if (mclVerbosityVectorProgress)
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


mclMatrix* mclFlowExpand
(  const mclMatrix*        mx
,  mclComposeStats*        stats
)
   {  mclMatrix*           mx_d
   ;  int                  col            =  0

   ;  if (mx->N_cols != mx->N_rows)
         fprintf(stderr, "[mclFlowExpand PBD] matrix not square\n")
      ,  exit(1)

   ;  mx_d     =  mclMatrixAllocZero(mx->N_rows, mx->N_cols)
   ;  ihvec_g  =  mclVectorComplete(ihvec_g, mx->N_cols, 1.0)

   ;  mclComposeStatsReset(stats)
   ;

     /*
      *  Initialization of the registry. Here information is stored
      *  which is eventually used to compute a bunch of statistics.
      *  Probably nobody cares about this stuff, but I want it in.
     */

      {
         reg.worstXprune   =  mcxHeapNew
                              (stats->nx,sizeof(float),fltCmp,MCX_MAX_HEAP)
      ;  reg.worstYprune   =  mcxHeapNew
                              (stats->ny,sizeof(float),fltCmp,MCX_MAX_HEAP)
      ;  reg.worstXfinal   =  mcxHeapNew
                              (stats->nx,sizeof(float),fltCmp,MCX_MAX_HEAP)
      ;  reg.worstYfinal   =  mcxHeapNew
                              (stats->ny,sizeof(float),fltCmp,MCX_MAX_HEAP)

      ;  reg.sum_final_all =  0.0
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
                              && (  mclMatrixNrofEntries(mx) 
                                 >  mclCloneBarrier* mx->N_cols
                                 )
                              )
      ;  if (cloning && !mclVerbosityPruning)
         fprintf(stdout, "(cloning) ")

      ;  pthread_attr_init(&pthread_custom_attr)

      ;  for (i=0;i<mcl_num_ethreads;i++)
         {
            mclNewFlowVector_thread_arg *a
                           =  (mclNewFlowVector_thread_arg *)
                              malloc(sizeof(mclNewFlowVector_thread_arg))
         ;  a->id          =  i
         ;  a->start       =  workLoad * i
         ;  a->end         =  workLoad * (i+1)
         ;  a->mxd         =  mx_d

         ;  a->mxs         =  (i && cloning)   /* thread 0 accesses original */
                              ?  mclMatrixCopy(mx)
                              :  (mclMatrix*) mx

         ;  if (i+1==mcl_num_ethreads)
            a->end   +=  workTail

         ;  pthread_create
            (  &threads_expand[i]
            ,  &pthread_custom_attr
            ,  (void *(*)(void*)) mclNewFlowVector_thread
            ,  (void *) a
            )
      ;  }

      ;  for (i = 0; i < mcl_num_ethreads; i++)
         pthread_join(threads_expand[i], NULL)

      /* glob a is destroyed by mclNewFlowVector_thread */
   ;  }

      else
      {
         mclVector*  cpyVec  =  mclVectorCreate(mx->N_rows)  
      ;  mclVector*  ivpVec  =  mclVectorCreate(mx->N_rows+1)  
      ;
         for (col=0;col<mx->N_cols;col++)
         {
            mclVector*  vec_d =  mx_d->vectors + col

         ;  float colInhomogeneity
            =  mclNewFlowVector
               (  mx
               ,  mx->vectors+col
               ,  mx_d->vectors+col
               ,  cpyVec
               ,  ivpVec
               ,  col
               )
         ;  (ihvec_g->ivps+col)->val = colInhomogeneity
      ;  }

         mclVectorFree(&cpyVec)
      ;  mclVectorFree(&ivpVec)
   ;  }

   ;  stats->inhomogeneity =  mclVectorMaxValue(ihvec_g)

     /*
      *  All but the level accounting part of the registry.
      *  Transferral of information from registry to stats.
     */

   ;  {
         int   x, y

      ;  float sumx_prune  =  0.0
      ;  float sumy_prune  =  0.0

      ;  float sumx_final  =  0.0
      ;  float sumy_final  =  0.0

      ;  if (reg.worstXprune->n_inserted)
         {
            float*   flp   =  (float *) reg.worstXprune->base  

         ;  for (x=0;x<reg.worstXprune->n_inserted;x++)
            sumx_prune += *(flp+x)
         ;  stats->mass_prune_nx =  sumx_prune/reg.worstXprune->n_inserted
      ;  }

      ;  if (reg.worstYprune->n_inserted)
         {
            float*   flp   =  (float *) reg.worstYprune->base  

         ;  for (y=0;y<reg.worstYprune->n_inserted;y++)
            sumy_prune += *(flp+y)
         ;  stats->mass_prune_ny =  sumy_prune/reg.worstYprune->n_inserted
      ;  }

      ;  if (reg.worstXfinal->n_inserted)
         {
            float*   flp   =  (float *) reg.worstXfinal->base

         ;  for (x=0;x<reg.worstXfinal->n_inserted;x++)
            {  sumx_final += *(flp+x)
         ;  }
         ;  stats->mass_final_nx =  sumx_final/reg.worstXfinal->n_inserted
      ;  }

      ;  if (reg.worstYfinal->n_inserted)
         {
            float*   flp   =  (float *) reg.worstYfinal->base

         ;  for (y=0;y<reg.worstYfinal->n_inserted;y++)
            {  sumy_final += *(flp+y)
         ;  }
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
      *  The level accounting part of the registry.
      *  Transferral of information from registry to stats.
     */

   ;  {
         int   x, y
      ;  int   n_levels_p        =  reg.ilLevelsP->n
      ;  int   n_levels_c        =  reg.ilLevelsC->n

      ;  char *cString           =  (char*) mcxAlloc(n_levels_c+1, EXIT_ON_FAIL)
      ;  char *pString           =  (char*) mcxAlloc(n_levels_p+1, EXIT_ON_FAIL)
      
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

      ;  stats->levels_compose   =  mcxTingNew(cString)
      ;  stats->levels_prune     =  mcxTingNew(pString)
      ;  mcxFree(cString)
      ;  mcxFree(pString)
   ;  }

   ;  return mx_d
;  }


mclComposeStats* mclComposeStatsNew
(  int   nx
,  int   ny
)  
   {  mclComposeStats* stats  =  (mclComposeStats*) mcxAlloc
                                 (  
                                    sizeof(mclComposeStats)
                                 ,  EXIT_ON_FAIL
                                 )

   ;  stats->nx               =  nx
   ;  stats->ny               =  ny

   ;  stats->inhomogeneity    =  0.0
   ;  stats->n_selects        =  0
   ;  stats->n_recoveries     =  0
   ;  stats->n_below_pct      =  0

   ;  stats->mass_final_nx    =  0.0
   ;  stats->mass_final_ny    =  0.0
   ;  stats->mass_final_all   =  0.0

   ;  stats->mass_prune_nx    =  0.0
   ;  stats->mass_prune_ny    =  0.0
   ;  stats->mass_prune_all   =  0.0

   ;  stats->levels_compose   =  NULL
   ;  stats->levels_prune     =  NULL

   ;  return stats
;  }


void mclComposeStatsFree
(  mclComposeStats** statspp
)  
   {  mclComposeStats* stats = *statspp

   ;  mcxTingFree(&(stats->levels_compose))
   ;  mcxTingFree(&(stats->levels_prune))
   ;  mcxFree(stats)
   ;  *statspp = NULL
;  }


void mclComposeStatsReset
(  mclComposeStats* stats
)  
   {  stats->inhomogeneity    =  0.0
   ;  stats->n_selects        =  0
   ;  stats->n_recoveries     =  0
   ;  stats->n_below_pct      =  0

   ;  stats->mass_prune_nx    =  0.0
   ;  stats->mass_prune_ny    =  0.0
   ;  stats->mass_prune_all   =  0.0

   ;  stats->mass_final_nx    =  0.0
   ;  stats->mass_final_ny    =  0.0
   ;  stats->mass_final_all   =  0.0

   ;  mcxTingFree(&(stats->levels_compose))
   ;  mcxTingFree(&(stats->levels_prune))
;  }


void mclComposeStatsPrint
(  mclComposeStats*  stats
,  FILE*             fp
)
   {  fprintf
      (  fp
      ,  "%3d%3d%3d %3d%3d%3d %s %s %-7d %-7d %-7d\n"
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
(  int   size
,  char  levelType
)
   {  int   i  =  0

   ;  while (size < levels[i] && i<n_levels)
      i++

   ;  if (levelType == 'c')
      (*(reg.ilLevelsC->list+i))++

   ;  else if (levelType == 'p')
      (*(reg.ilLevelsP->list+i))++
;  }


static void vecMeasure
(  mclVector*  vec
,  float       *maxval
,  float       *center
)  
   {  mclIvp*  ivp      =  vec->ivps
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


void mclComposeStatsHeader
(  FILE* vbfp
)  
   {
      const char* pruneMode
      =  (mclModePruning == MCL_PRUNING_ADAPT)
         ?  "adaptive"
         :  "rigid"  
   ;  const char* pStatus
      =  (mclModePruning == MCL_PRUNING_ADAPT)
         ?  "minimum"
         :  "rigid"  
   ;

fprintf
(  vbfp
,  "The %s threshold value equals [%f] (-p <f> or -P <i>)).\n"
,  pStatus
,  mclPrecision
)  ;

if (mclSelectNumber)
fprintf
(  vbfp
,  "Exact selection prunes to at most %d positive entries (-S).\n"
,  mclSelectNumber
)  ;

if (mclRecoverNumber)
fprintf
(  vbfp
,  "If %s thresholding leaves less than %2.0f%% mass (-pct) and less than\n"
   "%d entries, as much mass as possible is recovered (-R).\n"
,  pruneMode
,  100 * mclPct
,  mclRecoverNumber
)  ;

fprintf
(  vbfp
,  "\nLegend\n"
   "all: average over all vectors\n"
   "ny:  average over the worst %d cases (-ny <i>).\n"
   "nx:  average over the worst %d cases (-nx <i>).\n"
   "<>:  recovery is %sactivated. (-R, -pct)\n"
   "[]:  selection is %sactivated. (-S)\n"
   "8532c:  'man mcl' explains.\n"
,  mcl_ny
,  mcl_nx
,  (mclRecoverNumber) ? "" : "NOT "
,  (mclSelectNumber) ? "" : "NOT "
)  ;

fprintf
(  vbfp
,  "\n"
"----------------------------------------------------------------------------\n"
" mass percentages  | distribution of vec footprints|#recover cases <>       \n"
"         |         |__ compose ________ prune _____||    #select cases []   \n"
"  prune  | final   |000  00   0    |000  00   0    ||       |     #below pct\n"
"all ny nx|all ny nx|8532c8532c8532c|8532c8532c8532c|V       V        V      \n"
"---------.---------.---------------.---------------.-------.--------.-------\n"
)  ;

   }

