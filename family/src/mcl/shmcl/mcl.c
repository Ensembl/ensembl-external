
/*
 *    MCL front-end. Lots of options, many more have come and gone.
 *    Most options are inessential.
*/

#include "nonema/compose.h"
#include "nonema/iface.h"
#include "nonema/io.h"

#include "util/txt.h"
#include "util/equate.h"
#include "util/file.h"
#include "util/buf.h"
#include "util/types.h"
#include "util/checkbounds.h"

#include "intalg/ilist.h"

#include "mcl/mcl.h"
#include "mcl/clm.h"
#include "mcl/params.h"
#include "mcl/interpret.h"
#include "mcl/compose.h"

#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <limits.h>
#include <string.h>
#include <ctype.h>
#include <time.h>

void usage(const char** lines);
void settings(void);
void setBool(const char *string);
void doInfoFlag(const char *string);
int  flagWithArg(const int a, const char *string);
void toggle(int* i, const char* s);

mclParam*            mclparam;

static int           myargc                  =  0;
static const char**  myargv;

static mcxMatrix* mcxInitialize(int argc, char* const argv[]);

static const char*   ffn_opt                 =   "";

static int           mclWriteMode            =   'a';
static int           usrVectorProgress       =   0;

static int           bCenterMatrix           =   1;
static int           bAddLoop                =   0;
static int           bAddDiag                =   0;
static float         diagWeight              =   0.0;
static float         centerMatrixWeight      =   1.0;

static int           bShowSettings           =   0;
static int           bSizesort               =   1;
static int           bStdout                 =   0;
static int           keepOverlap             =   0;

static const char*   proggie                 =   NULL;

static int           n_preprune              =   0;
static mcxMatrix*    diagAll                 =   NULL;
static mcxMatrix*    diagSome                =   NULL;
mcxIOstream*         xfOut                   =   NULL;

const char *infoFlags[] = {
"--version",
"--help",
"-help",
"-h",
"--8532c",
"--pruning",
"--h",
"-x",
"-z",
""               /* denotes end of array */
};

int main
(  int               argc
,  char* const       argv[]
)  {
      FILE*          fpopt             =  NULL
   ;  mcxMatrix      *themx            =  NULL
   ;  mcxMatrix      *cluster          =  NULL

   ;  int            digits
   ;  int            n_cluster
   ;  int            B_print

   ;  mclparam                         =  mclParamNew()
   ;  proggie                          =  "mcl"
   ;  myargc                           =  argc
   ;  myargv                           =  (const char**) argv

   ;  xfOut                            =  mcxIOstreamNew("out.mcl", "w")

   ;  if (argc < 2)
      {  fprintf
         (  stderr
         ,  "Usage: %s <-|file name> [options], do mcl -h for help\n"
         ,  proggie
         )
      ;  exit(0)
   ;  }

      {  int i = 0
      ;  while(infoFlags[i][0] != '\0')
         {  if (!strcmp(infoFlags[i], argv[1]))
            {  doInfoFlag(argv[1])
            ;  exit(0)
         ;  }
         ;  i++
      ;  }
   ;  }

   ;  themx = mcxInitialize(argc, argv)

   ;  digits                  =  mclparam->printDigits
   ;  B_print                 =  mclparam->printMatrix

   ;  {  if (bAddDiag && !bAddLoop)
         {  mcxMatrix*  t  =  mcxMatrixAdd(themx, diagAll)
         ;  mcxMatrixFree(&themx)
         ;  mcxMatrixFree(&diagAll)
         ;  themx       =  t
      ;  }
         if (bAddLoop)
         {  mcxMatrix*  t  =  mcxMatrixAdd(themx, diagSome)
         ;  mcxMatrixFree(&themx)
         ;  mcxMatrixFree(&diagSome)
         ;  themx       =  t
      ;  }

      ;  if (bCenterMatrix)
         {  mcxMatrixCenter(themx, centerMatrixWeight, 0)
      ;  }

      ;  mcxMatrixMakeStochastic(themx)
   ;  }

   ;  if (n_preprune)
      {  mcxMatrixMakeSparse(themx, n_preprune)
      ;  mcxMatrixMakeStochastic(themx)
   ;  }

      {  
         int   o, m, e

      ;  cluster = mclCluster(themx, mclparam)

      ;  mclClusteringEnstrict
         (  cluster
         ,  &o
         ,  &m
         ,  &e
         ,  keepOverlap ? ENSTRICT_KEEP_OVERLAP : 0
         )
      ;  n_cluster = cluster->N_cols

      ;  if (o>0)
         {  
            if (keepOverlap && mclVerbosityMcl)
            fprintf(stdout, "[mcl] found [%d] instances of overlap\n", o)

         ;  else if (!keepOverlap && mclVerbosityMcl)
            fprintf(stderr, "[mcl] removed [%d] instances of overlap\n", o)
      ;  }

      ;  if (m>0)
         {  fprintf(stderr, "[mcl] added [%d] garbage entries\n", m)
      ;  }

      ;  if (cluster->N_cols > 1)
         {  
            if (bSizesort)
            {
               mcxVectorSizeCmp = 1
            ;  qsort
               (  cluster->vectors
               ,  cluster->N_cols - (m ? 1 : 0)    /* leave garbage alone */
               ,  sizeof(mcxVector)
               ,  mcxVectorIdxCmp
               )
         ;  }
            else
            {
               mcxVectorSizeCmp = 0
            ;  qsort
               (  cluster->vectors
               ,  cluster->N_cols -  (m ? 1 : 0)
               ,  sizeof(mcxVector)
               ,  mcxVectorIdxRevCmp
               )
         ;  }
      ;  }
   ;  }
     /* EO cluster enstriction
      */


   ;  if (mcxIOstreamOpen(xfOut, RETURN_ON_FAIL) != STATUS_OK)
      {  fprintf
         (  stderr
         ,  "[mcl] Cannot open output stream for [%s]\n"
            "[mcl] Trying to fall back to default [out.mcl]\n"
         ,  xfOut->fn->str
         )
      ;  mcxIOstreamOtherName(xfOut, "out.mcl")
      ;  mcxIOstreamOpen(xfOut, EXIT_ON_FAIL)
   ;  }

   ;  if (xfOut->fp == stdout)
      {  bStdout = 1
   ;  }

   {  if (mclWriteMode == 'a' || (mclWriteMode == 'b' && bStdout))
      {  mcxMatrixWriteAscii(cluster, xfOut, -1, EXIT_ON_FAIL)
      ;  if (mclWriteMode == 'b')
         {  fprintf
            (  stderr
            , "[mcl] Overrode format from binary to ascii (stdout)\n"
            )
      ;  }
   ;  }
      else if (mclWriteMode == 'b' && !bStdout)
      {  mcxMatrixWrite(cluster, xfOut, EXIT_ON_FAIL)
   ;  }
      else
      {  fprintf(stderr, "[mcl PBD] unrecognized output format\n")
      ;  exit(1)
   ;  }
;  }

   ;  if (strlen(ffn_opt))
      {  Ilist*  clussizes  =  ilInstantiate(NULL, cluster->N_cols, NULL, 0)
      ;  int      x
      ;  fpopt = fopen(ffn_opt, "wb")
      ;  if (!fpopt)
         {  fprintf(stderr, "[mcl] can't open output partition file")
         ;  exit(1)
      ;  }
      ;  for (x=0;x<cluster->N_cols;x++)
         {  *(clussizes->list+x) =  (cluster->vectors+x)->n_ivps
      ;  }
      ;  ilWriteFile(clussizes, fpopt)
      ;  fclose(fpopt)
   ;  }

   ;  if (mclVerbosityMcl && !bStdout)
      fprintf(stdout, "[mcl] %d clusters found\n", n_cluster)

   ;  return 0
;  }

const char *usageLines[] = {
"Copyright (c) 1999-2001 Stijn van Dongen.",
"Usage: mcl <file name> [options], or mcl - [options] using stdin.",
"Below: i,j,k stand for integers, f for float, str for string.",
"The most important options are listed last.",
"\n",

"---->  mcl <graph.mci> -I 2.0    should get you going. <----",
"\n",

"-dump att      dump attractor vectors",
"-dump ite      dump iterands",
"-dump cls      dump clusters",
"-dumpi <i:j>   dump objects during iterations i,i+1,..,j-1",
"-dumpm <k>     only dump objects i+0,i+k,.. in the range given by -dumpi",
"-dumpstr <str> use str as stem for dumped objects",
"\n",

"--ascii        output in native ascii format (default)",
"--binary       output in native binary format",
"\n",

"--overlap      keep overlap (the default is removal of overlap)",
"--square       replace input matrix by its square (does *not* add loops)",
"-preprune <i>  prune columns of input matrix to a maximum of n entries",
"\n",

"--show         print MCL iterands (small graphs only)",
"-digits <i>    precision for printing",
"\n",

"-z             show defaults and allowed settings",
"\n",

"-nx <i>        keep track of worst i prune and select instances         [10]",
"-ny <j>        keep track of worst j prune and select instances        [100]",
"\n",

"-o <fname|->   output to file `fname' (-o - for stdout)",
"\n",

"mcl verbosity modes",
"--verbose      turn on all -v options (see below)",
"--silent       turn off all -v options (see below)",
"-v all         turn on all -v options",
"-v mcl         emit clustering characteristics                          [on]",
"-v pruning   + emit pruning statistics                                 [off]",
"-v progress  + emit progress gauge      [when threading OFF, otherwise] [on]",
"-v io          emit input/output messages                               [on]",
"-V <str>       turn off corresponding -v option",
"                 all these options are sensitive to order of use and",
"                 should be used *after* -thread and its variants, if present",
"\n",

"-progress <i>  if i>0, (try to) print i times `.' during one iteration  [30]"
"               if i<0, print `.' after every |i| vectors computed",
"               if i=0, print convergence measure after every iteration",
"\n",

"mcldoc commands (mcldoc is a separate utility)",
"'mcldoc pruning' explains MCL pruning regimes",
"'mcldoc 8532c' explains output listed under '-v pruning'",
"\n",

"on multi-processor systems",
"-t <i>  \\      number of threads to use for both inflation and expansion",
"-te <i> - ++++ number of threads to use for expansion                    [0]",
"-ti <i> /      number of threads to use for inflation                    [0]",
"--clone      + when threading, clone source matrices (see -cloneat)",
"-cloneat <i> + only clone when source matrix vectors have more than i entries",
"                  on average (default 20)",
"\n",

"pruning options, adaptive/rigid",
"--rigid \\      rigid pruning (the default) (see -p and 'mcldoc pruning')",
"--adapt / ++++ adaptive pruning by computing column-depending thresholds",
"-ae <f>      + adaptive pruning exponent (range 3-10 conceivable)      [4.0]",
"-af <f>      + adaptive pruning factor (range 1-100 conceivable)       [4.0]",
"                  do 'mcldoc pruning' for more information",
"\n",

"speed/quality controls",
"-p <f> \\       set precision (i.e. fixed threshold, cutof value) to f [1e-3]",
"-P <i> / +++++ equivalent to '-p f' where f == 1/i                    [1000]",
"                  these define the true cutof for rigid pruning and the",
"                  minimum cutof for adaptive pruning. (see 'mcldoc pruning')",
"-m <i> \\       sets the 'mark number' to i. 'mcldoc pruning' explains.   [0]",
"-M <i> /    ++ equivalent to '-m <i> --recover --select'",
"-pct <i>    ++ mass percentage below which to try to recover pruning    [95]",
"--recover   ++ recover over-severe pruning (with -m i, i > 0)",
"--select    ++ select after pruning (with -m i, i > 0)",
"\n",

"mcl cluster controls",
"-l <i>       * initial MCL loop length (use 2 as a secondary default)    [0]",
"-i <f>       * initial inflation                                       [2.0]",
"-a <f> /       add loops of weight f (deprecated alternative to -c)",
"-c <f> \\    ** add loops of weight f times the column center           [1.0]",
"               stick to the default or use higher values",
"-L <i>         main MCL loop length                               [infinity]",
"-I <f>   ***** main inflation                                          [2.0]",
"\n",

"Options marked * are MCL cluster controls, options marked + are quality/speed",
"controls, The number of marks indicates the importance. For most cases all",
"defaults should be fine. 'mcldoc pruning' explains quality/speed controls.",
"Try different -I values for finding clusterings of different granularity",
"(e.g. in the range 1.2 - 4.0), and use a -P value at least 3-5 times larger",
"than the average node degree. For example settings, explanations, and further",
"pointers, see http://members.ams.chello.nl/svandong/thesis/.",

"\n",

"---->  mcl <graph.mci> -I 2.0    should get you going. <----",
"\n",

"",              /* denotes end of array */
};

const char *ans_help
=
"Use -h for help, -z for defaults, for complete information see\n"
"http://members.ams.chello.nl/svandong/thesis/index.html.\n"
"Report bugs to vanbaal@mdcc.cx, s.vandongen@chello.nl\n"
;

const char *ans_version
=
"mcl 2.0\n"
"Copyright (c) 1999-2001 Stijn van Dongen. mcl comes with NO WARRANTY, to the\n"
"extent permitted by law. You may redistribute copies of mcl under\n"
"the terms of the GNU General Public License.\n"
;


mcxMatrix* mcxInitialize (int argc, char* const argv[])
{  int               a, i
;  float             f
;  float             f_0         =  0.0
;  float             f_1         =  1.0
;  int               i_0         =  0
;  int               i_1         =  1
;  int               i_100       =  100
;  float             f_E1        =  1e-1
;  float             f_E20       =  1e-20
;  mcxMatrix        *mx
;  mcxBuf            diagbuf
;  mcxVector        *diagvec     =  mcxVectorInit(NULL)
;  mcxIpretParam*    ipretParam  =  mclparam->mcxIpretParam

;  mcxIOstream*      xfIn        =  mcxIOstreamNew(argv[1], "r")
;  checkBoundsPrintDigits        =  1
;  a                             =  2

;  while (a < argc)
   {  
      if (flagWithArg(a, "-c"))
      {  
         f = (float) atof(argv[++a])
      ;  flagCheckBounds
         ("-c", "float", &f, fltGq, &f_0, NULL, NULL)
      ;  if (f<1.0 || f>3.0)
         {  fprintf
            (  stderr
            ,  "[mcl warning -c] conceivable/normal ranges for -c are "
               "[0.5, 5.0] / [1.0, 3.0]\n"
            )
      ;  }
      ;  bCenterMatrix = f == 0.0 ? 0 : 1
      ;  centerMatrixWeight = f
   ;  }
      else if (flagWithArg(a, "-a"))
      {  
         diagWeight  =  (float) atof(argv[++a])
      ;  flagCheckBounds
         ("-a", "float", &diagWeight, fltGt, &f_0, NULL, NULL)
      ;  bAddDiag   =  1
   ;  }
      else if (flagWithArg(a, "-A"))
      {  
         if (sscanf(argv[++a], "%d:%f", &i, &f) == 2)

        /*    code below is not clean. Logic should lie with buf 
         *    or with declaration of diagbuf
        */
         {  
            if (!bAddLoop)
            mcxBufInit
            (  &diagbuf
            ,  &(diagvec->ivps)
            ,  sizeof(mcxIvp)
            ,  30
            )

         ;  bAddLoop = 1

         ;  {  mcxIvp  *ivp   =  (mcxIvp*) mcxBufExtend(&diagbuf, 1)
            ;  ivp->idx       =  i
            ;  ivp->val       =  f
         ;  }

         ;  flagCheckBounds("-A", "float", &f, fltGq, &f_0, NULL, NULL)
      ;  }
         else
         {  fprintf(stderr, "-A flag takes <int:float> format\n")
         ;  exit(1)
      ;  }
   ;  }
      else if (flagWithArg(a, "-B"))
      {  setBool(argv[++a])
   ;  }
      else if (!strncmp(argv[a], "--", 2))
      {  
         i = 0
      ;  while(infoFlags[i][0] != '\0')
         {  
            if (!strcmp(infoFlags[i], argv[a]))
            doInfoFlag(argv[a])
         ;  i++
      ;  }
      ;  setBool(argv[a]+2)
   ;  }
      else if (flagWithArg(a, "-cloneat"))
      {  
         mclCloneBarrier = atoi(argv[++a])
      ;  flagCheckBounds
         ("-cloneat", "integer", &mclCloneBarrier, intGq, &i_1, NULL, NULL)
   ;  }
      else if (flagWithArg(a, "-progress"))
      {  
         usrVectorProgress = atoi(argv[++a])

      ;  if (!usrVectorProgress)
         {  
            mclVectorProgression = 0
         ;  mclVerbosityMatrixProgress = mcxTRUE
         ;  mclVerbosityVectorProgress = mcxFALSE
      ;  }
         else
         mclVerbosityVectorProgress = mcxTRUE

      ;  mclVectorProgression = usrVectorProgress
   ;  }
      else if (flagWithArg(a, "-tracki"))
      {  if
         (  sscanf
            (  argv[++a]
            ,  "%d:%d"
            ,  &mcxTrackNonemaPruningOfset
            ,  &mcxTrackNonemaPruningBound
            )
         != 2
         )
         {  fprintf
            (  stderr
            ,  "Flag -tracki expects i:j format, j=0 denoting infinity\n"
            )
         ;  exit(1)
      ;  }
      ;  mcxTrackNonemaPruning = 1
   ;  }
      else if (flagWithArg(a, "-t"))
      {  
         mcl_num_ethreads = atoi(argv[++a])
      ;  flagCheckBounds
         (  "-t"
         ,  "integer", &mcl_num_ethreads, intGq, &i_0, NULL, NULL
         )
      ;  mcl_num_ithreads = mcl_num_ethreads
      ;  mclVerbosityPruning  = 0
   ;  }
      else if (flagWithArg(a, "-ti"))
      {  
         mcl_num_ithreads = atoi(argv[++a])
      ;  flagCheckBounds
         (  "-ti"
         ,  "integer", &mcl_num_ithreads, intGq, &i_0, NULL, NULL
         )
      ;  mclVerbosityPruning  = 0
   ;  }
      else if (flagWithArg(a, "-te"))
      {  
         mcl_num_ethreads = atoi(argv[++a])
      ;  flagCheckBounds
         (  "-te"
         ,  "integer", &mcl_num_ethreads, intGq, &i_0, NULL, NULL
         )
      ;  mclVerbosityPruning  = 0
   ;  }
      else if (flagWithArg(a, "-nx"))
      {  
         mcl_nx    =  atoi(argv[++a])
      ;  flagCheckBounds
         (  "-nx"
         ,  "integer", &mcl_nx, intGq, &i_1, NULL, NULL
         )
   ;  }
      else if (flagWithArg(a, "-ny"))
      {  
         mcl_ny    =  atoi(argv[++a])
      ;  flagCheckBounds
         (  "-ny"
         ,  "integer", &mcl_ny, intGq, &i_1, NULL, NULL
         )
   ;  }
      else if (flagWithArg(a, "-trackm"))
      {  
         mcxTrackNonemaPruningInterval = atoi(argv[++a])
      ;  flagCheckBounds
         (  "-trackm"
         ,  "integer", &mcxTrackNonemaPruningInterval, intGq, &i_1, NULL, NULL
         )
      ;  mcxTrackNonemaPruning = 1
   ;  }
      else if (flagWithArg(a, "-digits"))
      {  
         int   iten  =  10;
      ;  i = atoi(argv[++a])
      ;  flagCheckBounds
         ("-digits", "integer", &i, intGq, &i_1, intLq, &iten)
      ;  mclparam->printDigits = i
   ;  }
      else if (!strcmp(argv[a], "-h"))
      {  doInfoFlag("-h")
   ;  }
      else if (flagWithArg(a, "-i"))
      {  
         float t  =  0.1
      ;  float h  =  100.0
      ;  f = (float) atof(argv[++a])
      ;  mclparam->initInflation = f
      ;  flagCheckBounds("-i", "float", &f, fltGq, &t, fltLq, &h)
      ;  if (f<1.1 || f>5.0)
         {  fprintf
            (  stderr
            ,  "[mcl warning -i] conceivable/normal ranges for -i are "
               "[0.5, 5.0] / [1.0, 3.0]\n"
            )
      ;  }
   ;  }
      else if (flagWithArg(a, "-I"))
      {  
         float t  =  0.1
      ;  float h  =  100.0
      ;  f = (float) atof(argv[++a])
      ;  mclparam->mainInflation = f
      ;  flagCheckBounds("-I", "float", &f, fltGq, &t, fltLq, &h)
      ;  if (f<1.1 || f>5.0)
         {  fprintf
            (  stderr
            ,  "[mcl warning -I] conceivable/normal ranges for -I are "
               "(1.0, 5.0] / [1.2, 3.0]\n"
            )
      ;  }
   ;  }
      else if (flagWithArg(a, "-l"))
      {  
         i = atoi(argv[++a])
      ;  mclparam->initLoopLength = i
      ;  flagCheckBounds
         ("-l", "integer", &i, intGq, &i_0, NULL, NULL)
   ;  }
      else if (flagWithArg(a, "-L"))
      {  
         i                          =  atoi(argv[++a])
      ;  mclparam->mainLoopLength   =  i
      ;  flagCheckBounds("-L", "integer", &i, intGq, &i_0, NULL, NULL)
   ;  }
      else if (flagWithArg(a, "-P"))
      {  
         i                 =  atoi(argv[++a])
      ;  flagCheckBounds("-P", "integer", &i, intGq, &i_1, NULL, NULL)
      ;  mclPrecision      =  0.99999 / ((float) i)
   ;  }
      else if (flagWithArg(a, "-p"))
      {  
         mclPrecision      =  atof(argv[++a])
      ;  flagCheckBounds
         ("-p", "float", &mclPrecision, fltGq, &f_0, fltLq, &f_E1)
   ;  }
      else if (flagWithArg(a, "-pct"))
      {  
         i           =  atoi(argv[++a])
      ;  flagCheckBounds
         (  "-pct"
         ,  "integer", &i, intGq, &i_0, intLt, &i_100
         )
      ;  mclPct      =  ((float) i) / 100.0
   ;  }
      else if (flagWithArg(a, "-M"))
      {  
         mclMarknum        =  atoi(argv[++a])
      ;  flagCheckBounds("-m", "integer", &mclMarknum, intGq, &i_0, NULL, NULL)
      ;  mclSelect         =  mcxTRUE
      ;  mclRecover        =  mcxTRUE
   ;  }
      else if (flagWithArg(a, "-m"))
      {  
         mclMarknum         =  atoi(argv[++a])
      ;  flagCheckBounds("-m", "integer", &mclMarknum, intGq, &i_0, NULL, NULL)
   ;  }
      else if (flagWithArg(a, "-ae"))
      {  
         mclCutExp         =  atof(argv[++a])
      ;  mclModePruning    =  MCL_PRUNING_ADAPT

      ;  flagCheckBounds
         (  "-ae"
         ,  "float", &mclCutExp, fltGq, &f_1, NULL, NULL
         )
   ;  }
      else if (flagWithArg(a, "-af"))
      {  
         mclCutCof         =  atof(argv[++a])
      ;  mclModePruning    =  MCL_PRUNING_ADAPT

      ;  flagCheckBounds
         (  "-af"
         ,  "float", &mclCutCof, fltGq, &f_1, NULL, NULL
         )
   ;  }
      else if (flagWithArg(a, "-opt"))
      {  ffn_opt = argv[++a]
   ;  }
      else if (flagWithArg(a, "-o"))
      {  mcxIOstreamOtherName(xfOut, argv[++a])
   ;  }
      else if (flagWithArg(a, "-preprune"))
      {  
         n_preprune = atoi(argv[++a])
      ;  flagCheckBounds
         ("-preprune", "integer", &n_preprune, intGq, &i_1, NULL, NULL)
   ;  }
      else if (flagWithArg(a, "-prlwtzkofsky"))
      {                                   /* currently obsolete */  
         f = (float) atof(argv[++a])
      ;  ipretParam->w_center = f
   ;  }
      else if (flagWithArg(a, "-Q"))
      {                                   /* currently obsolete */
         f = (float) atof(argv[++a])
      ;  ipretParam->w_selfval = f
   ;  }
      else if (flagWithArg(a, "-R"))
      {                                   /* currently obsolete */
         f = (float) atof(argv[++a])
      ;  ipretParam->w_maxval = f
   ;  }
      else if (flagWithArg(a, "-devel"))
      {  mclDevel =  atoi(argv[++a])      /* as a quick debug hook */
   ;  }
      else if (flagWithArg(a, "-dumpstr"))
      {  mclDumpStem = argv[++a]             /* bad hack? */
   ;  }
      else if (flagWithArg(a, "-v"))
      {  
         a++
      ;  if (strcmp(argv[a], "pruning") == 0)
         mclVerbosityPruning    =  mcxTRUE

      ;  else if (strcmp(argv[a], "io") == 0)
         mcxVerbosityIoNonema   =  mcxTRUE

      ;  else if (strcmp(argv[a], "mcl") == 0)
         mclVerbosityMcl        =  mcxTRUE

      ;  else if (strcmp(argv[a], "progress") == 0)
         mclVerbosityVectorProgress =  mcxTRUE

      ;  else if (strcmp(argv[a], "all") == 0)
         setBool("verbose")
   ;  }
      else if (flagWithArg(a, "-V"))
      {  
         a++
      ;  if (strcmp(argv[a], "pruning") == 0)
                                          mclVerbosityPruning    =  mcxFALSE
      ;  else if (strcmp(argv[a], "io") == 0)
                                          mcxVerbosityIoNonema   =  mcxFALSE
      ;  else if (strcmp(argv[a], "mcl") == 0)
                                          mclVerbosityMcl        =  mcxFALSE
      ;  else if (strcmp(argv[a], "progress") == 0)
                                      mclVerbosityVectorProgress =  mcxFALSE
      ;  else if (strcmp(argv[a], "all") == 0)
                                          setBool("silent")
   ;  }
      else if (flagWithArg(a, "-dump"))
      {  
         a++
      ;  if (strcmp(argv[a], "att") == 0)       mclDumpAttractors   =  1
      ;  else if (strcmp(argv[a], "ite") == 0)  mclDumpIterands     =  1
      ;  else if (strcmp(argv[a], "cls") == 0)  mclDumpClusters     =  1
   ;  }
      else if (flagWithArg(a, "-dumpi"))
      {  if
         (  sscanf
            (  argv[++a]
            ,  "%d:%d"
            ,  &mclDumpOfset, &mclDumpBound
            )
         != 2
         )
         {  fprintf
            (  stderr
            ,  "Flag -dumpi expects i:j format, j=0 denoting infinity\n"
            )
         ;  exit(1)
      ;  }
   ;  }
      else if (flagWithArg(a, "-dumpm"))
      {  
         mclDumpModulo = atoi(argv[++a])
      ;  flagCheckBounds
         ("-dumpm", "integer", &mclDumpModulo, intGq, &i_1, NULL, NULL)
   ;  }
      else if (!strcmp(argv[a], "-z"))
      {  bShowSettings = 1;
   ;  }
      else
      {  
         fprintf(stderr, "Unrecognized flag %s\n", argv[a])
      ;  doInfoFlag("--help")
      ;  exit(1)
   ;  }
   ;  a++
;  }

   ;  if (bShowSettings)
         settings()
      ,  exit (0)

   ;  mx =  mcxMatrixRead(xfIn, EXIT_ON_FAIL)
   ;  mcxIOstreamFree(&xfIn)

   ;  if (bAddDiag)
      diagAll     =  mcxMatrixDiag(mx->N_cols, diagWeight, NULL, 0)

   ;  if (bAddLoop)
      {  
         diagvec->n_ivps   =  diagbuf.n

      ;  diagSome    =  mcxMatrixDiag
                        (  mx->N_cols
                        ,  0.0
                        ,  diagvec->ivps
                        ,  diagvec->n_ivps
                        )
      ;  mcxVectorFree(&diagvec)
   ;  }

  /* 
   *     because of initialization the condition below means that
   *     user has not used -progress flag or given it argument 0.
   *     This setup is very ugly, general problem when trying to
   *     make constituting elements of default settings interact.
  */
   ;  if ((mcl_num_ethreads || mcl_num_ithreads) && !usrVectorProgress)
      {
         mclVerbosityMatrixProgress = mcxTRUE
      ;  mclVerbosityVectorProgress = mcxFALSE
   ;  }

   ;  if (mclVerbosityVectorProgress)
      {  
         if (mclVectorProgression > 0)
         mclVectorProgression
         =  MAX(1 + (mx->N_cols -1)/mclVectorProgression, 1)

      ;  else
         mclVectorProgression = -mclVectorProgression
   ;  }
      else if
         (  !mclVectorProgression
         && mx->N_cols >= 2000
         && !mcl_num_ethreads
         && !mcl_num_ithreads
         && !mclVerbosityMatrixProgress
         )
      {  
         fprintf
         (  stderr
         ,  "[mcl advice] for larger graphs such as this, -progress <n> will "
            "reflect progress\n"
         )
   ;  }

   ;  if (mcxTrackNonemaPruning)
      {  mcxTrackStreamNonema = mcxIOstreamNew("-", "w")
      ;  mcxIOstreamOpen(mcxTrackStreamNonema, EXIT_ON_FAIL)
   ;  }

   ;  return mx
;  }

void setBool
(  const char *string
)
{
   if      (!strcmp(string, "track"))     mcxTrackNonemaPruning   =  1
;  else if (!strcmp(string, "overlap"))   keepOverlap             =  1
;  else if (!strcmp(string, "silent")) {    mclVerbosityPruning   =  mcxFALSE
                                       ;    mcxVerbosityIoNonema  =  mcxFALSE
                                       ;    mclVerbosityMcl       =  mcxFALSE
                                 ;    mclVerbosityVectorProgress  =  mcxFALSE
                                    ;  }
   else if (!strcmp(string, "verbose")){    mclVerbosityPruning   =  mcxTRUE
                                       ;    mcxVerbosityIoNonema  =  mcxTRUE
                                       ;    mclVerbosityMcl       =  mcxTRUE
                                 ;    mclVerbosityVectorProgress  =  mcxTRUE
                                    ;  }
   else if (!strcmp(string, "ascii"))     {    mclWriteMode       =  'a'
                                          ;    mclDumpMode        =  'a'
                                       ;  }
   else if (!strcmp(string, "binary"))    {    mclWriteMode       =  'b'
                                          ;    mclDumpMode        =  'b'
                                       ;  }
   else if (!strcmp(string, "thick"))     mclModeCompose = MCL_COMPOSE_DENSE  ;
   else if (!strcmp(string, "rigid"))     mclModePruning = MCL_PRUNING_RIGID  ;
   else if (!strcmp(string, "adapt"))     mclModePruning = MCL_PRUNING_ADAPT  ;

   else if (!strcmp(string, "pruning"))   doInfoFlag("--pruning")             ;
   else if (!strcmp(string, "8532c"))     doInfoFlag("--8532c")               ;

   else if (!strcmp(string, "clone"))     mclCloneMatrices        =  mcxTRUE  ;
   else if (!strcmp(string, "recover"))   mclRecover              =  mcxTRUE  ;
   else if (!strcmp(string, "select"))    mclSelect               =  mcxTRUE  ;
   else if (!strcmp(string, "show"))      mclparam->printMatrix   =  mcxTRUE  ;
   else if (!strcmp(string, "dense"))
   {  fprintf
      (  stdout
      ,  
"\n[mcl] obsolete flag; former dense mode has become the default setting\n"
"under the new pruning regime and is now more aptly called rigid pruning.\n"
"Note: the default precision has shrunk from 1e-6 to 1e-3.\n\n"
      )
   ;  exit(0)
;  }
   else
   {  fprintf(stdout, "[mcl] Unrecognized flag --%s\n", string)
   ;  exit(1)
;  }
}

int flagWithArg
(  const int a, const char *string
)  {  
      if (strcmp(myargv[a], string))
      return 0

   ;  if (a+1 >= myargc)
      {  fprintf  (  stderr
                  ,  "[mcl] Flag %s needs argument\n"
                  ,  myargv[myargc-1]
                  )
      ;  doInfoFlag("--help")
      ;  exit(1)
   ;  }
   ;  return 1
;  }

void doInfoFlag(const char *string)
{
;  if (!strcmp(string, "--help"))         fprintf(stdout, "%s", ans_help)
;  else if (!strcmp(string, "--version")) fprintf(stdout, "%s", ans_version)
;  else if (!strcmp(string, "-h"))        usage(usageLines)
;  else if (!strcmp(string, "-z"))        settings()
;  else if (!strcmp(string, "--pruning"))
      fprintf(stdout, "do 'mcldoc pruning'\n")
;  else if (!strcmp(string, "--8532c"))
      fprintf(stdout, "do 'mcldoc 8532c'\n")
;  else                                   usage(usageLines)
;  exit(0)
;
}

void settings (void)  
{
   printf("[mcl] default settings:\n");

printf(
"Mark number:                                     %8d    [-m int]\n"
,  mclMarknum                                   
)  ;                                                     
printf(                                                  
"Number of digits used in prettyprint (--show):   %8d    [-digits int]\n"
,  mclparam->printDigits                                 
)  ;                                                     
printf(                                                  
"Precision, defining cutof for --dense:          %8.7f    [-precision flt]\n"
,  (float) mclPrecision
)  ;  printf("\n");


printf(
"Loop centering factor:                             %8.1f _[-c flt]\n"
,  centerMatrixWeight
)  ;
printf(
"Bool add centering diagonal to matrix:           %8d   /\n"
,  bCenterMatrix
)  ;  printf("\n");


printf(
"Loop weight factor:                                %8.1f _[-a flt]\n"
,  diagWeight
)  ;
printf(
"Bool add constant diagonal to matrix:            %8d   /\n"
,  bAddDiag
)  ;  printf("\n");


printf(
"nx     (see -h for explanation)                  %8d    [-nx int]\n"
,  mcl_nx
)  ;
printf(
"ny     (see -h for explanation)                  %8d    [-ny int]\n"
,  mcl_ny
)  ;
printf(
"pct    (see -h for explanation)                  %8d    [-pct int]\n"
,  (int) (100 * mclPct + 0.5)
)  ;
printf(
"ae (see -h for explanation)                          %2.2f    [-ae flt]\n"
,  mclCutExp
)  ;
printf(
"af (see -h for explanation)                          %2.2f    [-af flt]\n"
,  mclCutCof
)  ;  printf("\n");


printf(
"Initial loop length:                             %8d    [-l int]\n"
,  mclparam->initLoopLength                      
)  ;                                             
printf(                                          
"Main loop length:                                %8d    [-L int]\n"
,  mclparam->mainLoopLength                      
)  ;                                             
printf(                                          
"Initial inflation:                                 %8.1f  [-i flt]\n"
,  mclparam->initInflation                       
)  ;                                             
printf(                                          
"Main inflation:                                    %8.1f  [-I flt]\n"
,  mclparam->mainInflation
)  ;  printf("\n");

#if 0
printf
(  "Interpretation center weight:                      %-8f [-P flt]\n"
,  ipretParam->w_center                            
)  ;                                               
printf                                             
(  "Interpretation selfval weight:                     %-8f [-Q flt]\n"
,  ipretParam->w_selfval                           
)  ;                                               
printf                                             
(  "Interpretation maxval weight:                      %-8f [-R flt]\n"
,  ipretParam->w_maxval
)  ;
printf("\n");
#endif

#if 0
printf(
"Boolean dump clusters:                                %-8d [-dump cls]\n"
,  mclDumpClusters                              
)  ;                                            
printf(                                         
"Boolean dump iterands:                                %-8d [-dump ite]\n"
,  mclDumpIterands                              
)  ;                                            
printf(                                         
"Boolean dump attractors:                              %-8d [-dump attr]\n"
,  mclDumpAttractors                            
)  ;                                            
#endif

exit(0);
}

void toggle (int *i, const char *s)
{  if (*i != 0 && *i != 1)
   {  fprintf  (  stderr
               ,  "[mcl internal error] variable tagged by [%s] not a bool!\n"
               ,  s
               )
   ;  exit(1)
;  }
   *i =  1 - *i
;
}


void usage
(  const char**   lines
)  {
      int i =  0

   ;  while(lines[i][0] != '\0')
      {
         if (lines[i][0] == '\n')
         fprintf(stdout, "\n")
      ;  else
         fprintf(stdout, "%s\n", lines[i])

      ;  i++
   ;  }

      fprintf(stdout, "[mcl] Printed %d lines\n", i+1)
   ;  exit(0)
;  }


