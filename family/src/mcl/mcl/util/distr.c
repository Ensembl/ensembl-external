/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdlib.h>
#include <stdio.h>
#include <math.h>

#include "distr.h"
#include "types.h"
#include "alloc.h"


mcxDistr*   mcxDistrNew
(  int      storage
)
   {  mcxDistr*   db;

   ;  db             =  (mcxDistr*) mcxAlloc(sizeof(mcxDistr), EXIT_ON_FAIL)
   ;  db->db         =  (float*) mcxAlloc
                        (  sizeof(float) * storage
                        ,  RETURN_ON_FAIL
                        )
   ;  if (!db->db)
         mcxMemDenied(stderr, "mcxDistrNew", "float", storage)
      ,  exit(1)

   ;  db->N          =  0
   ;  db->av         =  0.0
   ;  db->dv         =  0.0
   ;  db->av_true    =  0
   ;  db->dv_true    =  0
   ;  db->allocated  =  storage

   ;  return db
;  }


void mcxDistrFree
(  mcxDistr**  distrp
)
   {  if ((*distrp)->db != NULL)
      {  free((*distrp)->db)
      ;  free(*distrp)
      ;  *distrp  =  NULL
   ;  }
;  }


void mcxDistrClear
(  mcxDistr*   distr
)
   {  if (distr)
      {  distr->N       =  0
      ;  distr->av      =  0.0
      ;  distr->dv      =  0.0
      ;  distr->av_true =  0
      ;  distr->dv_true =  0
   ;  }
;  }


void mcxDistrStoreValue
(  mcxDistr*   db
,  float    val
)
   {  int N
   ;  if (!db)
      {  fprintf
         (  stderr
         ,  "[mcxDistrStoreValue PBD] void mcxDistribution, ignoring\n"
         )
      ;  return
   ;  }

   ;  N = db->N
   ;  if (N >= db->allocated)
      {  fprintf
         (  stderr
         ,  "[mcxDistrStoreValue PBD]"
            " not enough storage for new item, ignoring\n"
         )
      ;  return
   ;  }

   ;  *(db->db+N) =  val
   ;  (db->N)++
   ;  db->av_true = 0
;  }


float   mcxDistrGetAverage
(  mcxDistr*   db
)
   {  int   i
   ;  float av =  0.0

   ;  if (db->N == 0)
         return 0.0

   ;  if (db->av_true)
         return db->av

   ;  db->dv_true = 0

   ;  for (i=0;i<db->N;i++)
         av += *(db->db+i)

   ;  db->av = av / db->N
   ;  db->av_true = 1
   ;  return db->av
;  }


float   mcxDistrGetDeviation
(  mcxDistr*   db
)
   {  int   i
   ;  float av
   ;  float dv =  0.0

   ;  if (db->N == 0)
         return 0.0

   ;  if (db->av_true && db->dv_true)
         return db->dv

   ;  if (!db->av_true)
         mcxDistrGetAverage(db)
   ;  av = db->av

   ;  for (i=0;i<db->N;i++)
         dv += (float) pow((double) *(db->db+i) -av, 2)

   ;  db->dv = sqrt(dv / (float) db->N)
   ;  db->dv_true = 1

   ;  return db->dv
;  }



