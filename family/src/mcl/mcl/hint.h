
#ifndef MCL_HINT__
#define MCL_HINT__

/*
 *    hint pf: average distance 
/*

typedef struct
{  
   float       val
;  int         idx
;  int         n_best   /* times hint was best hint and within range 2*k   */
;  mcxTxt*     spec     /* original string from command line               */
;  mcxDistr*   delta    /* distance from maxDensity when hint was best     */
;
}  hint        ;


#endif

