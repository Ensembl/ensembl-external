/*
// mcl.h                MCL clustering algorithm
*/

#ifndef MCLH__
#define MCLH__

#include "nonema/matrix.h"
#include "mcl/compose.h"
#include "mcl/interpret.h"

typedef struct
{  
   float                mainInflation
;  int                  mainLoopLength
                                                     
;  float                initInflation
;  int                  initLoopLength
                                                     
;  int                  printMatrix
;  int                  printDigits
                    
;  mcxIpretParam*       mcxIpretParam
;  mcxComposeParam*     mcxComposeParam
;
}  mclParam             ;


mclParam* mclParamNew(void);


mcxMatrix* mclCluster
(  
   mcxMatrix*           mx
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


void mcxMatrixCenter
(  
   mcxMatrix*     mx
,  float       w_center
,  float       w_selfval
)  ;


void mcxFlowInflate
(  
   mcxMatrix*           mx
,  float             power
)  ;


#endif

