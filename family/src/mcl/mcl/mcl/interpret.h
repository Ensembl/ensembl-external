/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef mcl_interpret_h__
#define mcl_interpret_h__

#include "nonema/matrix.h"

/*
////////////////////////////////////////////////////////////////////////////////
//                      struct mclIpretParam
//
//                      mclMatrix* clusterMtx mclInterpret
//                      (  const mclMatrix*          mtx
//                      ,  const mclIpretParam*   ipretParam
//                      );

// description (short)  Interpret any (nonnegative) stochastic matrix mtx
//                      as a clustering via a mapping explained below,
//                      return clustering encoded as matrix. Each vector in
//                      clusterMtx represents a cluster element, the last
//                      vector in clusterMtx represents a garbage vector.
//                      The members of ipretParam affect the number and size
//                      of the clusters and the amount of overlap generated.

// note                 The last vector in clusterMtx, which is the
//                      'garbage' vector, is _always_ present.  Under normal
//                      circumstances it will be empty.

//  more background     This routine works canonically on stochastic matrices
//                      which are 'diagonally positive semi--definite' (dpsd)
//    or doubly idempotent.  Do not worry about this; see below for the crux.
//    It was designed in a robust way, and will give meaningful results for
//    all kinds of nonnegative matrices.  However, it is likely that the
//    greatest use of mclInterpret() lies in applying it to iterands of the
//    MCL process, especially early iterands. The characteristic property of
//    dpsd matrices is that the absolute value of each diagonal entry relative
//    to the other (absolute) values in the vector it is in is governed by
//    special restrictions which bring forth a cluster interpretation of the
//    (column) indices. The simple truth, explained in the more specific
//    setting of column stochastic dpsd matrices, is:

//    Let A be a column stochastic dpsd matrix. 
//    Write l-->k if A_{ll} <= A_{kl}.  Then --> induces a directed acyclic
//    graph (DAG) on the column indices of A, if identical columns are lumped
//    together.  See 'A cluster process for graphs using stochastic matrices'
//    by Stijn.  The canonical way to associate a clustering with a DAG is to
//    define each node with no outgoing arcs (a sink) as the core of a unique
//    clustering.  Each core is then expanded with all nodes that reach it.
//    The definition above can also be applied to nonnegative doubly idempotent
//    stochastic matrices, which in general need not be dspd (they are dpsd
//    only if every node is an attractor, which is an exceptional case),
//    yielding the canonical cluster interpretation of such a matrix.

//    mclInterpret works by associating a DAG with its input matrix such
//    that the returned clustering satisfies the definition above for
//    a nonnegative input matrix which is dpsd or doubly idempotent. However,
//    mclInterpret does the best it can in associating a DAG with any
//    stochastic matrix, in a manner which is not affected by the order
//    in which columns and rows are stored. Moreover, the routine allows a
//    parametrization possibly affecting the amount of overlap and the number
//    of clusters generated. 'Possibly' because certain matrices allow only
//    one sensible cluster interpretation, e.g. doubly idempotent matrices.

//    The members of mclInterpretParam are used for transforming an input
//    matrix before interpreting it.  Their values affect whether diagonal
//    entries survive this transformation or not.  This in turn affects the
//    resulting clustering.  Basically, the more diagonal entries survive
//    (which are not maximal in their column), the more overlap will result
//    in the clustering.  note: The (graph associated with the) transformed
//    matrix still need not be a DAG.

//    The sum of the values of the members below should sum to 1 or a
//    number slightly smaller (e.g. somewhere in between 0.99..0.95),
//    and they should be nonnegative.  For one thing, this implies that no
//    matter their relative values, doubly idempotent matrices (which admit
//    only one sensible clustering) will always be interpreted correctly.
//    The transformation works as follows: For each column k a bar is
//    computed. All values below the bar are removed. The bar equals

//          w_center    *  (center of column k)
//          w_selfval   *  (value of kk entry)
//       +  w_maxval    *  (maximum value in column k)
//       --------------------------------------------
//       =  bar

//    The numbers selfval, center, and maxval are quantities which are
//    computed for each column.  selfval can in general be anything inbetween
//    the smallest and largest values of the column.  maxval is the largest
//    value of the column, and center, which is a weighted average of the
//    column values, also lies somewhere inbetween the smallest and largest
//    values.  Possible usage of these parameters is that one wants to keep
//    all diagonal entries which are greater than the center of their column.
//    In that case, set for example

//          w_center    =  alpha
//          w_selfval   =  beta

//    where alpha+beta == 1.  Then, if center > selfval, bar will be greater
//    than selfval, and if center < selfval, bar will be smaller. If alpha
//    is relatively large, the bar will be close to center, if beta is large,
//    the bar will be close to selfval. If  one wants to interpret the input
//    matrix strictly as if it is dpsd, then set

//          w_selfval   =  alpha
//          w_maxval    =  beta

//    where alpha+beta == 1-epsilon (e.g. 0.99..). The larger alpha, the
//    larger the size of the clusters and the more overlap.

//    The transformed matrix (call it) T is interpreted as follows.  nodes
//    which still have a positive return value (corresponding with columns with
//    nonzero diagonal entry) are considered attractive. If T_{kl} != 0 we
//    say that l-->k or that l is a parent of k.  A node is also considered
//    attractive if anywhere in a chain of parents leading to this node,
//    there is an attractive parent.  Now, each connected subgraph consisting
//    solely of attractive nodes is taken as the core of a cluster element.
//    This corresponds with 'lumping together of identical columns'
//    in the case of dpsd matrices mentioned above (the columns being the
//    columns associated with that connected subgraph, and this set of columns
//    subsequently playing the role of sink).  This core C is extended with
//    (the nodes of) all chains of parents for which one of the nodes lies
//    in C.  This corresponds with the act of joining all nodes reaching
//    a specific sink in a DAG.  This definition and its implementation
//    guarantuee that the resulting clustering is permutation invariant
//    (i.e. does not depend on the order in which columns and rows are stored).

// w_center             see above
// w_selfval            see above
// w_maxval             see above
*/

typedef struct
{  float                w_center                      /* default 0.0       */
;  float                w_selfval                     /* default 0.1       */
;  float                w_maxval                      /* default 0.9       */
;  
}  mclIpretParam;

mclIpretParam* mclIpretParamNew(void);


/*
////////////////////////////////////////////////////////////////////////////////
// description       Extract a clustering from a graph.
//                   
////////////////////////////////////////////////////////////////////////////////
*/


mclMatrix* mclInterpret
(  const mclMatrix*     mx
,  const mclIpretParam* ipretParam
)  ;


float  mclVectorCoverage
(  const mclVector*     vec
,  const mclVector*     cluster
,  int                  n
,  float                *maxcoverage
)  ;

float  mclMatrixCoverage
(  const mclMatrix*     mx
,  const mclMatrix*     clustering
,  float                *maxcoverage
)  ;

void  clusterMeasure
(  const mclMatrix*     clus
,  FILE*                fp
)  ;

mclVector*  mcxAttractivityScale
(  const mclMatrix*     M
)  ;


#if 0
void mcxDiagnosticsAttractor
(  const char*          ffn_attr
,  const mclMatrix*     clustering
,  const mcxDumpParam*  dumpParam
)  ;


void mcxDiagnosticsPeriphery
(  const char*          ffn_peri
,  const mclMatrix*     clustering
,  const mcxDumpParam*  dumpParam
)  ;
#endif


#endif

