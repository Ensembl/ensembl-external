/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef mcl_compose_h__
#define mcl_compose_h__

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
;  mcxTing*          levels_compose
;  mcxTing*          levels_prune
;
}  mclComposeStats   ;


extern int hintScores[5];


mclComposeStats* mclComposeStatsNew
(  int   nx
,  int   ny
)  ;


void mclComposeStatsReset
(  mclComposeStats* stats
)  ;


void mclComposeStatsFree
(  mclComposeStats** statspp
)  ;


void mclComposeStatsPrint
(  mclComposeStats*  stats
,  FILE*             fp
)  ;

void mclComposeStatsHeader
(  FILE* vbfp
)  ;  

typedef struct
{  int                  maxDensity
;  float                precision
;
}  mclComposeParam;


mclComposeParam* mclComposeParamNew
(  void
)  ;


mclMatrix* mclFlowExpand
(  const mclMatrix*        mx
,  mclComposeStats*        stats
)  ;


#endif

