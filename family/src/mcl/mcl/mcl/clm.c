/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdio.h>

#include "clm.h"
#include "dpsd.h"

#include "nonema/matrix.h"
#include "nonema/compose.h"
#include "intalg/la.h"
#include "util/txt.h"
#include "util/file.h"
#include "util/alloc.h"
#include "util/types.h"
#include "util/equate.h"


Ilist*  mclClusteringGetAligner
(  mclMatrix*     cl
)  {
      int         c
   ;  int         n_seen   =  0
   ;  int         missing, overlap, empty

   ;  Ilist       *pm      =  ilInstantiate(NULL, cl->N_rows, NULL, -1)

   ;  if (mclClusteringEnstrict(cl, &overlap, &missing, &empty, 1))
      {  fprintf
         (  stderr
         ,  "[mclClusteringAlign fatal] clustering is not a partition\n"
            "     -- This is an internal error. Please file a bug report\n"
         )
      ;  exit(1)
   ;  }

   ;  for (c=0;c<cl->N_cols;c++)
      {  
         mclIvp*  ivp      =  (cl->vectors+c)->ivps
      ;  mclIvp*  ivpmax   =  ivp + (cl->vectors+c)->n_ivps

      ;  while(ivp    < ivpmax)
         {  
            int   l  =  ivp->idx
                                         /* already seen (overlap) */
         ;  if (*(pm->list+l) >= 0)
            {  fprintf
               (  stderr
               ,  "[mclClusteringAlign] overlap at column %d, idx %d\n"
                  "     -- This should be impossible."
                  " Please file a bug report.\n"
               ,  c
               ,  l
               )
         ;  }
            else
            {  *(pm->list+l) = n_seen++
         ;  }
         ;  ivp++
      ;  }
   ;  }

   ;  if (n_seen < cl->N_rows)
      {  fprintf
         (  stderr
         ,  "[mclClusteringAlign error] clustering is not fully covering.\n"
            "     -- This should be impossible. Please file a bug report.\n"
         )
      ;  exit(1)
   ;  }

   ;  if (!ilIsOneOne(pm))
      {  fprintf
         (  stderr
         ,  "[mclClusteringAlign error] clustering is somehow"
            " not a partition.\n"
            "     -- This should be impossible. Please file a bug report.\n"
         )
      ;  exit(1)
   ;  }

   ;  return pm
;  }



   /*
    *    Remove overlap
    *    Add missing entries
    *    Remove empty clusters
    */

int  mclClusteringEnstrict
(  mclMatrix*  cl
,  int         *overlap
,  int         *missing
,  int         *empty
,  mcxflags    flags
)  {
      int      c
   ;  Ilist    *ct         =  ilInstantiate(NULL, cl->N_rows, NULL, 0)

   ;  *overlap             =  0
   ;  *missing             =  0
   ;  *empty               =  0

   ;  for (c=0;c<cl->N_cols;c++)
      {
         mclIvp*  ivp      =  (cl->vectors+c)->ivps
      ;  mclIvp*  ivpmax   =  ivp + (cl->vectors+c)->n_ivps
      ;  int      olap     =  0

      ;  while(ivp< ivpmax)
         {  
            int   l        =  ivp->idx
                                         /* already seen (overlap) */
         ;  if (*(ct->list+l) > 0)
            {  olap++
            ;  ivp->val    =  -1.0
         ;  }
            else
            {  *(ct->list+l) = 1
         ;  }

         ;  ivp++
      ;  }

      ;  *overlap  += olap

      ;  if (olap && !(flags & ENSTRICT_KEEP_OVERLAP))
         mclVectorSelectGqBar(cl->vectors+c, 0.0)
   ;  }

   ;  *missing          =  ilCountLtBar(ct, 1)

   ;  if (*missing && !(flags & ENSTRICT_LEAVE_MISSING))
      {
         int   z
      ;  int   y        =  0
      ;  int   newCol   =  cl->N_cols

      ;  cl->vectors    =  (mclVector*) mcxRealloc
                           (  cl->vectors
                           ,  (cl->N_cols+1)* sizeof(mclVector)
                           ,  EXIT_ON_FAIL
                           )

      ;  mclVectorInit(cl->vectors+newCol)
      ;  mclVectorInstantiate(cl->vectors+newCol, *missing, NULL)

      ;  for(z=0;z<ct->n;z++)
         {  
            if (*(ct->list+z) == 0)
            {  ((cl->vectors+newCol)->ivps+y)->idx =  z
            ;  ((cl->vectors+newCol)->ivps+y)->val =  1.0
            ;  y++
         ;  }
      ;  }

      ;  cl->N_cols++
   ;  }

      {
         int   q  =  0

      ;  for (c=0;c<cl->N_cols;c++)
         {
            if ((cl->vectors+c)->n_ivps > 0)
            {
               if (c>q  && !(flags & ENSTRICT_KEEP_EMPTY))
               {
                  (cl->vectors+q)->n_ivps    =  (cl->vectors+c)->n_ivps
               ;  (cl->vectors+q)->ivps      =  (cl->vectors+c)->ivps
            ;  }
            ;  q++
         ;  }
      ;  }

      ;  *empty            =  cl->N_cols - q

      ;  if (*empty && !(flags & ENSTRICT_KEEP_EMPTY))
         {  
            cl->vectors =  (mclVector*) mcxRealloc
                           (  cl->vectors
                           ,  q*sizeof(mclVector)
                           ,  EXIT_ON_FAIL
                           )
         ;  cl->N_cols     =  q
      ;  }
   ;  }

   ;  return (*overlap + *missing + *empty)
;  }


void mclClusteringSJD
(  mclMatrix*  cl
,  mclMatrix*  dl
,  int*        cddist
,  int*        dcdist
)
   {  mclMatrix* cdting   =  mclClusteringContingency(cl, dl)
   ;  mclMatrix* dcting   =  mclMatrixTranspose(cdting)
   ;  int i, j

   ;  *cddist = 0
   ;  *dcdist = 0

   ;  for (i=0;i<cdting->N_cols;i++)
      {  
         int         max            =  0
      ;  mclVector   *vecmeets      =  cdting->vectors+i

      ;  for (j=0;j<vecmeets->n_ivps;j++)
         {  if ((int) (vecmeets->ivps+j)->val > max)
            {  max = (int) (vecmeets->ivps+j)->val
         ;  }
      ;  }
      ;  *cddist += (cl->vectors+i)->n_ivps - max
   ;  }

   ;  for (i=0;i<dcting->N_cols;i++)
      {  
         int         max         =  0
      ;  mclVector   *vecmeets   =  dcting->vectors+i

      ;  for (j=0;j<vecmeets->n_ivps;j++)
         {  if ((int) (vecmeets->ivps+j)->val > max)
            {  max = (int) (vecmeets->ivps+j)->val
         ;  }
      ;  }
      ;  *dcdist += (dl->vectors+i)->n_ivps - max
   ;  }
   ;  mclMatrixFree(&cdting)
   ;  mclMatrixFree(&dcting)
;  }


mclMatrix*  mclClusteringContingency
(  mclMatrix*  cl
,  mclMatrix*  dl
)  {  mclMatrix      *dlT  =  mclMatrixTranspose(dl)
   ;  mclMatrix      *ct   =  mclMatrixCompose(dlT, cl, 0)
   ;  mclMatrixFree(&dlT)
   ;  return ct
;  }


mclMatrix*  mclClusteringMeet
(  mclMatrix*  cl
,  mclMatrix*  dl
,  mcxstatus   ON_FAIL
)  {
      int         i, c, o, m, e, n_clmeet, i_clmeet
   ;  mclMatrix   *cdting, *clmeet

   ;  if
      (  mclClusteringEnstrict(cl, &o, &m, &e, 1)
      || mclClusteringEnstrict(dl, &o, &m, &e, 1)
      )
      {  
         if (ON_FAIL == RETURN_ON_FAIL)
         return NULL
      ;  else
         {  fprintf
            (  stderr
            ,  "[mclClusteringMeet fatal] clusterings are not partitions\n"
            )
         ;  exit(1)
      ;  }
   ;  }

   ;  cdting      =     mclClusteringContingency(cl, dl)
   ;  if (!cdting)
      return NULL

   ;  n_clmeet    =     mclMatrixNrofEntries(cdting)
   ;  clmeet      =     mclMatrixAllocZero(n_clmeet, cl->N_rows)
   ;  i_clmeet    =     0

   ;  for (c=0;c<cdting->N_cols;c++)
      {  
         mclVector*  vec   =  cdting->vectors+c

      ;  for (i=0;i<vec->n_ivps;i++)
         {     
            int         d  =  (vec->ivps+i)->idx

         ;  if (i_clmeet == n_clmeet)
            {  fprintf
               (  stderr
               ,  "[mclClusteringMeet fatal] internal math does not add up\n"
               )
            ;  exit(1)
         ;  }

         ;  mclVectorSetMeet
            (  cl->vectors+c
            ,  dl->vectors+d
            ,  clmeet->vectors+i_clmeet
            )
         ;  i_clmeet++
      ;  }
   ;  }

   ;  if (i_clmeet != n_clmeet)
      {  fprintf
         (  stderr
         ,  "[mclClusteringMeet fatal] internal math does not substract\n"
         )
      ;  exit(1)
   ;  }

   ;  return clmeet
;  }


