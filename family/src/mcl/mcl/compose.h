
/*
 * compose.h            MCL-specific compose routines
 *
 * description          Elaborate compose function that adds statistics
 *                      and pruning targeted towards stochastic matrices.
*/

#ifndef MCL_COMPOSE__
#define MCL_COMPOSE__

#include <stdio.h>

#include "util/txt.h"
#include "nonema/matrix.h"


typedef struct
{  
   float             inhomogeneity
;  int               n_selects
;  int               n_recoveries
;  int               n_below_pct
;  int               nx
;  int               ny
;  float             mass_prune_nx
;  float             mass_prune_ny
;  float             mass_prune_all
;  float             mass_final_nx
;  float             mass_final_ny
;  float             mass_final_all
;  mcxTxt*           levels_compose
;  mcxTxt*           levels_prune
;
}  mcxComposeStats   ;


extern int hintScores[5];


mcxComposeStats* mcxComposeStatsNew
(  
   int   nx
,  int   ny
)  ;


void mcxComposeStatsReset
(
   mcxComposeStats* stats
)  ;


void mcxComposeStatsFree
(
   mcxComposeStats* stats
)  ;


void mcxComposeStatsPrint
(  
   mcxComposeStats*  stats
,  FILE*             fp
)  ;


typedef struct
{  int                  maxDensity
;  float                precision
;
}  mcxComposeParam;


mcxComposeParam* mcxComposeParamNew
(  void
)  ;


mcxMatrix* mcxFlowExpand
(  
   const mcxMatrix*        mx
,  mcxComposeStats*        stats
)  ;


#endif

