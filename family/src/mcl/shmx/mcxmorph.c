
/*
//
*/

#include "nonema/matrix.h"
#include "nonema/vector.h"
#include "nonema/io.h"
#include "nonema/compose.h"
#include "nonema/iface.h"
#include "util/file.h"
#include "util/types.h"
#include "util/alloc.h"
#include "mcl/interpret.h"
#include <string.h>


int  flagWithArg(const int a, const char *string);
static int           myargc                  =  0;
static const char**  myargv;

const char *usagelines[] = {
"\n",
"[mcxmorph] usage:",
"mcxmorph [options] -o <mx-dest> <mx-spec>+",
"\n",

"<mx dest>     name of file where destination matrix is stored",
"<mx-spec>     is either one of <fname | fname %[csT]+>",
"                 T: take transpose of the matrix in file fname",
"                 c: make matrix 0/1 matrix by setting all values to 1",
"                 s: make matrix stochastic by normalizing columns",
"              These actions are processed in this exact order (T-c-s)",
"              If more than one spec is given the product of the matrices",
"              according to the specs is computed - this product is called",
"              the result matrix. Some options in [options] may still further",
"              transform the result matrix",
"Options:",
"  -n <int j>  prune each subproduct with pruning constant j",
"  -c          make each matrix factor and subproduct characteristic",
"  -s          make each matrix factor and subproduct stochastic",
"  -T          take the transpose of result matrix",
"  -N <int j>  prune result matrix with pruning constant j",
"  -C          make result matrix characteristic",
"  -S          make result matrix stochastic",
"  -d <int j>  precision for printing values in ascii output",
"                    supplying j=-1 suppresses printing of values",
"  -b          output destination matrix in binary format (default is ascii)",
"\n",

"Coarsening a graph relative to a clustering:",
"  mcxmorph -s -o coarse.mci out.mcl %T graph.mci out.mcl",
"Uncoarsening a clustering:",
"  mcxmorph -o uncoarse.mcl out.mcl coarse.mcl",
"  [  for coarsening you probably want to write custom software",
"     lowering inflation generally gives better results than coarsening",
"  ]",
"Producing a contingency matrix given two clusterings:",
"  mcxmorph -o ting.mci out.mcl2 %T out.mcl1",
"Computing the transpose of a matrix:",
"  mcxmorph -o matrixT.mci matrix.mci %T",
"\n",

"NOTE file extensions have no meaning to mcl utilities",
"you can simply pick whatever suits you best",
"\n",
""
}  ;



int main
(  int               argc
,  const char*       argv[]
)  {  
      mcxIOstream    **xfMcs        =  NULL
   ;  mcxIOstream    *xfOut         =  NULL
   ;  int            *mxActions     =  NULL
   ;  const char     *dieMsg        =  NULL

   ;  int      TRANSFORM_STOCHASTIC =  1
   ;  int      TRANSFORM_TRANSPOSE  =  2
   ;  int      TRANSFORM_CHARACTER  =  4

   ;  mcxMatrix      *lft           =  NULL
   ;  mcxMatrix      *rgt           =  NULL
   ;  mcxMatrix      *dst           =  NULL

   ;  const char     *whoiam        =  "mcxmorph"

   ;  int            a              =  1
   ;  int            n_mx           =  0
   ;  int            j              =  0
   ;  int            i              =  0
   ;  int            N_cols         =  -1
   ;  int            N_rows         =  -1

   ;  int         bResultStochastic =  0
   ;  int         bResultTranspose  =  0
   ;  int         bResultCharacter  =  0
   ;  int            bSubStochastic =  0
   ;  int            bSubCharacter  =  0
   ;  int            nSub           =  0
   ;  int            nResult        =  0
   ;  int            status         =  0

   ;  char           format         =  'a'
   ;  int            digits         =  8

   ;  mcxVerbosityIoNonema          =  1
   ;  myargc                        =  argc
   ;  myargv                        =  (const char**) argv

   ;  if (argc==1)
      {  fprintf
         (  stdout
         ,  "Usage:\n"
            "mcxmorph [options] -o <dest-file> <fname [SPEC]>+\n"
            "mcxmorph -h for help\n"
         )
      ;  exit(0)
   ;  }
      else if ((argc >= 2 && !strcmp(argv[1], "-h")))
      {  goto help
   ;  }
      else if (argc < 3)
      {  dieMsg   =  "specify factors and destination file names"
      ;  goto die
   ;  }

   ;  mxActions   =  (int*) rqAlloc((argc)*sizeof(int), EXIT_ON_FAIL)

   ;  for (j=0;j<argc;j++)
      mxActions[j] = 0

   ;  xfMcs       =  (mcxIOstream**) rqAlloc
                     (  (argc)*sizeof(mcxIOstream*)
                     ,  EXIT_ON_FAIL
                     )

   ;  while(a<argc)
      {  if (!strcmp(argv[a], "-h"))
         {  
            help:
            while(usagelines[i][0] != '\0')
            {  if (usagelines[i][0] == '\n')
                  fprintf(stdout, "\n")
            ;  else
                  fprintf(stdout, "%s\n", usagelines[i])
            ;  i++
         ;  }

         ;  fprintf(stdout, "[mcxmorph usage summary] Printed %d lines\n", i+1)
         ;  if (dieMsg)
            {  fprintf(stderr, "%s%s%s", "__!! ", dieMsg, " !!__\n")
         ;  }
         ;  exit(status)
      ;  }
         else if (0)
         {  die:
            status   =  1
         ;  goto help
      ;  }
         else if (!strcmp(argv[a], "-s"))
         {  bSubStochastic       =  1
         ;  bResultStochastic    =  1
      ;  }
         else if (!strcmp(argv[a], "-S"))
         {  bResultStochastic    =  1
      ;  }
         else if (!strcmp(argv[a], "-T"))
         {  bResultTranspose     =  1
      ;  }
         else if (!strcmp(argv[a], "-c"))
         {  bSubCharacter        =  1
         ;  bResultCharacter     =  1
         ;  digits               =  -1
      ;  }
         else if (!strcmp(argv[a], "-C"))
         {  bResultCharacter     =  1
         ;  digits               =  -1
      ;  }
         else if (!strcmp(argv[a], "-b"))
         {  format               =  'b'
      ;  }
         else if (flagWithArg(a, "-d"))
         {  digits               =  atoi(argv[++a])
      ;  }
         else if (flagWithArg(a, "-o"))
         {  
            xfOut = mcxIOstreamNew(argv[++a], "w")
         ;  mcxIOstreamOpen(xfOut, EXIT_ON_FAIL)
      ;  }
         else if (flagWithArg(a, "-n"))
         {  nSub              =  atoi(argv[++a])
      ;  }
         else if (flagWithArg(a, "-N"))
         {  nResult           =  atoi(argv[++a])
      ;  }
         else if (argv[a][0] == '%')
         {  if (n_mx == 0)
            {  dieMsg = "no matrix to apply action to"
            ;  goto die
         ;  }

            if (strchr(argv[a], 's'))
            mxActions[n_mx-1] |= TRANSFORM_STOCHASTIC
         ;  if (strchr(argv[a], 'T'))
            mxActions[n_mx-1] |= TRANSFORM_TRANSPOSE
         ;  if (strchr(argv[a], 'c'))
            mxActions[n_mx-1] |= TRANSFORM_CHARACTER

         ;  if (!mxActions[n_mx-1])
            {  dieMsg = "Action token '%%' requires at least one of [csT]"
            ;  goto die
         ;  }
      ;  }
         else if (a<argc)
         {  xfMcs[n_mx] = mcxIOstreamNew(argv[a], "r")
         ;  mcxIOstreamOpen(xfMcs[n_mx], EXIT_ON_FAIL)
         ;  n_mx++
      ;  }

      ;  if (a==argc)
         {  fprintf
            (  stderr
            ,  "[mcxmorph] missing argument for flag [%s]\n"
            ,  argv[argc-1]
            )
         ;  exit(1)
      ;  }

      ;  a++
   ;  }

   ;  if (!xfOut)
      {  dieMsg = "-o <fname> option is mandatory"
      ;  goto die
   ;  }

   ;  if (!n_mx)
      {  dieMsg = "at least one matrix factor required"
      ;  goto die
   ;  }

   ;  for (j=0;j<n_mx;j++)
      {
         int new_N_rows, new_N_cols
      ;  if
         (  mcxMatrixFilePeek
            (  xfMcs[j]
            ,  &new_N_cols
            ,  &new_N_rows
            ,  RETURN_ON_FAIL
            )
            == STATUS_FAIL
         )
         {  fprintf
            (  stderr
            ,  "[%s] matrix format not known for stream [%s]\n"
            ,  whoiam
            ,  xfMcs[j]->fn->str
            )  ;
         ;  exit(1)
      ;  }

      ;  if (mxActions[j] & TRANSFORM_TRANSPOSE)
         {  int   t        =  new_N_cols
         ;  new_N_cols     =  new_N_rows
         ;  new_N_rows= t
      ;  }  

      ;  if (j && N_cols != new_N_rows)
         {  fprintf
            (  stderr
            ,  "[%s] offending dimensions [%dx%d] [%dx%d] (matrices %d, %d)\n"
            ,  whoiam
            ,  N_rows      ,  N_cols
            ,  new_N_rows  ,  new_N_cols
            ,  j-1         ,  j
            )  ;
         ;  exit(1)
      ;  }
         else
         {  N_cols      =  new_N_cols
         ;  N_rows      =  new_N_rows
      ;  }
   ;  }

   ;  lft               =  mcxMatrixRead(xfMcs[0], EXIT_ON_FAIL)
   ;  mcxIOstreamRelease(xfMcs[0])

   ;  if (mxActions[0] & TRANSFORM_TRANSPOSE)
      {  mcxMatrix* ltp    =  mcxMatrixTranspose(lft)
      ;  mcxMatrixFree(&lft)
      ;  lft               =  ltp
   ;  }

      if (bSubCharacter || (mxActions[0] & TRANSFORM_CHARACTER))
      {  mcxMatrixMakeCharacteristic(lft)
   ;  }

      if (bSubStochastic || (mxActions[0] & TRANSFORM_STOCHASTIC))
      {  mcxMatrixMakeStochastic(lft)
   ;  }

   ;  for (j=1;j<n_mx;j++)
      {  rgt =  mcxMatrixRead (xfMcs[j], EXIT_ON_FAIL)
      ;  mcxIOstreamRelease(xfMcs[j])

      ;  if (mxActions[j] & TRANSFORM_TRANSPOSE)
         {  mcxMatrix*  rtp   =  mcxMatrixTranspose(rgt)
         ;  mcxMatrixFree(&rgt)
         ;  rgt               =  rtp
      ;  }
      ;  if (bSubCharacter || (mxActions[j] & TRANSFORM_CHARACTER))
         {  mcxMatrixMakeCharacteristic(rgt)
      ;  }
      ;  if (bSubStochastic || (mxActions[j] & TRANSFORM_STOCHASTIC))
         {  mcxMatrixMakeStochastic(rgt)
      ;  }

      ;  dst   =  mcxMatrixCompose(lft, rgt, nSub)
      ;  lft   =  dst
      ;  mcxMatrixFree(&rgt)

      ;  if (bSubCharacter)
         {  mcxMatrixMakeCharacteristic(lft)
      ;  }
      ;  if (bSubStochastic)
         {  mcxMatrixMakeStochastic(lft)
      ;  }
   ;  }

   ;  if (bResultTranspose)
      {  mcxMatrix   *T    =  mcxMatrixTranspose(lft)
      ;  mcxMatrixFree(&lft)
      ;  lft               =  T
   ;  }
   ;  if (nResult)
      {  mcxMatrixMakeSparse(lft, nResult)
   ;  }
   ;  if (bResultCharacter)
      {  mcxMatrixMakeCharacteristic(lft)
   ;  }
   ;  if (bResultStochastic)
      {  mcxMatrixMakeStochastic(lft)
   ;  }

      if (format == 'a')
      {  mcxMatrixWriteAscii(lft, xfOut, digits, EXIT_ON_FAIL)
   ;  }
      else
      {  if (!digits)
         mcxMatrixMakeCharacteristic(lft)
      ;  mcxMatrixWrite(lft, xfOut, EXIT_ON_FAIL)
   ;  }

   ;  mcxMatrixFree(&lft)
   ;  mcxIOstreamFree(&xfOut)
   ;  free(mxActions)
   ;  free(xfMcs)

   ;  return(0)
;  }


int flagWithArg
(  const int a, const char *string
)  {
      if (strcmp(myargv[a], string))
      return 0

   ;  if (a+1 >= myargc)
      {  fprintf  (  stderr
                  ,  "[mcxmorph] Flag %s needs argument\n"
                  ,  myargv[myargc-1]
                  )
      ;  exit(1)
   ;  }
   ;  return 1
;  }

