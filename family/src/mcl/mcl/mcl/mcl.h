/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef mcl_mcl_h__
#define mcl_mcl_h__

#include "compose.h"
#include "interpret.h"

#include "nonema/matrix.h"

typedef struct
{  
   float                mainInflation
;  int                  mainLoopLength
                                                     
;  float                initInflation
;  int                  initLoopLength
                                                     
;  int                  printMatrix
;  int                  printDigits

;  mclIpretParam*       mclIpretParam
;  mclComposeParam*     mclComposeParam
;
}  mclParam             ;


mclParam* mclParamNew(void);


mclMatrix* mclCluster
(  
   mclMatrix*           mx
,  const mclParam*      param
)  ;


/*
 * description       Change the return probabilities in mx (or add them if
 *                   missing) with such values that in each column the return
 *                   probability would not change under one application of
 *                   inflation (with power factor 2).
 *
 *                   The idea is that this value is a good value
 *                   representing `indifference' of the node with regard
 *                   to being attracted or being attractive.
*/


void mclMatrixCenter
(  
   mclMatrix*     mx
,  float       w_center
,  float       w_selfval
)  ;


#endif

