/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

/*
 *    MCL front-end. Lots of options, many more have come and gone.
 *    Most options are inessential.
*/


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


void doBool(const char *string);
void doInfoFlag(const char *string);
int  flagWithArg(const int a, const char *string);
void toggle(int* i, const char* s);
void makeSettings(void);

static mclParam*  mclparam = NULL;

static int  scheme[4][4]                     =  {  {  1500, 400, 500, 90 }
                                                ,  {  2000, 500, 600, 90 }
                                                ,  {  2500, 600, 700, 90 }
                                                ,  {  3000, 700, 800, 90 }
                                                }  ;

static int           myargc                  =  0;
static const char**  myargv;

static mclMatrix* mcxInitialize(int argc, char* const argv[]);

static const char*   ffn_opt                 =   "";

static int           mclWriteMode            =   'a';
static int           usrVectorProgress       =   0;

static mcxbool       centerMatrix            =   TRUE;
static mcxbool       addDiag                 =   FALSE;
static mcxbool       expandOnly              =   FALSE;

static float         diagWeight              =   0.0;
static float         centerMatrixWeight      =   1.0;

static int           bSizesort               =   1;
static int           bStdout                 =   0;
static int           keepOverlap             =   0;

static int           expandDigits            =   8;
static int           n_prune                 =  -1;
static int           n_select                =  -1;
static int           n_recover               =  -1;
static int           n_scheme                =  -1;
static int           n_pct                   =  -1;

static const char*   proggie                 =   NULL;

static int           n_preprune              =   0;
static mclMatrix*    diagAll                 =   NULL;
mcxIOstream*         xfOut                   =   NULL;

const char *infoFlags[] = {
"--version",
"--show-schemes",
"--show-settings",
"-shs",
"--help",
"-help",
"-h",
"--h",
"-x",
"-z",
""               /* denotes end of array */
};

int main
(  int               argc
,  char* const       argv[]
)
   {  FILE*          fpopt             =  NULL
   ;  mclMatrix      *themx            =  NULL
   ;  mclMatrix      *cluster          =  NULL

   ;  int            n_cluster
   ;  int            B_print

   ;  mclparam                         =  mclParamNew()
   ;  proggie                          =  "mcl"
   ;  myargc                           =  argc
   ;  myargv                           =  (const char**) argv

   ;  xfOut                            =  mcxIOstreamNew("out.mcl", "w")

   ;  mclCutExp               =  2.0

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
      }

      themx    =  mcxInitialize(argc, argv)
   ;  B_print  =  mclparam->printMatrix

   ;  if (expandOnly)
      mclVerbosityPruning =  TRUE
   ;

      if (!mclInflateFirst)
      {
         if (addDiag)
         {  mclMatrix*  t  =  mclMatrixAdd(themx, diagAll)
         ;  mclMatrixFree(&themx)
         ;  mclMatrixFree(&diagAll)
         ;  themx       =  t
      ;  }

         if (centerMatrix)
         mclMatrixCenter(themx, centerMatrixWeight, 0)

      ;  mclMatrixMakeStochastic(themx)

      ;  if (n_preprune)
         {  mclMatrixMakeSparse(themx, n_preprune)
         ;  mclMatrixMakeStochastic(themx)
      ;  }
   ;  }

      if (expandOnly)
      {
         mclComposeStats *stats  =  mclComposeStatsNew(mcl_nx, mcl_ny)
      ;  mclMatrix*  expanded    =  mclFlowExpand(themx, stats)
      ;
         if (mclVerbosityVectorProgress)
         fprintf(stdout, "\n")
      ;  if (mclVerbosityExplain)
         mclComposeStatsHeader(stdout)
      ;  mclComposeStatsPrint(stats, stdout)
      ;
         if (!strcmp(xfOut->fn->str, "out.mcl"))
         mcxIOstreamOtherName(xfOut, "out.mce")
      ;
         if (mcxIOstreamOpen(xfOut, RETURN_ON_FAIL) != STATUS_OK)
         {  fprintf
            (  stderr
            ,  "[mcl] Cannot open output stream for [%s]\n"
               "[mcl] Trying to fall back to default [out.mce]\n"
            ,  xfOut->fn->str
            )
         ;  mcxIOstreamOtherName(xfOut, "out.mce")
         ;  mcxIOstreamOpen(xfOut, EXIT_ON_FAIL)
      ;  }
         {  if (xfOut->fp == stdout)
            bStdout = 1
         ;  if (mclWriteMode == 'a' || (mclWriteMode == 'b' && bStdout))
            {  mclMatrixWriteAscii(expanded, xfOut, expandDigits, EXIT_ON_FAIL)
            ;  if (mclWriteMode == 'b')
               {  fprintf
                  (  stderr
                  , "[mcl] Overrode format from binary to ascii (stdout)\n"
                  )
            ;  }
         ;  }
            else
            mclMatrixWrite(expanded, xfOut, EXIT_ON_FAIL)
      ;  }
      ;  return 0
   ;  }

      {  int   o, m, e

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
            if (keepOverlap)
            fprintf(stderr, "[mcl] found [%d] instances of overlap\n", o)

         ;  else if (!keepOverlap)
            fprintf(stderr, "[mcl] removed [%d] instances of overlap\n", o)
      ;  }

      ;  if (m>0)
         {  fprintf(stderr, "[mcl] added [%d] garbage entries\n", m)
      ;  }

      ;  if (cluster->N_cols > 1)
         {  
            if (bSizesort)
            {
               mclVectorSizeCmp = 1
            ;  qsort
               (  cluster->vectors
               ,  cluster->N_cols - (m ? 1 : 0)    /* leave garbage alone */
               ,  sizeof(mclVector)
               ,  mclVectorIdxCmp
               )
         ;  }
            else
            {
               mclVectorSizeCmp = 0
            ;  qsort
               (  cluster->vectors
               ,  cluster->N_cols -  (m ? 1 : 0)
               ,  sizeof(mclVector)
               ,  mclVectorIdxRevCmp
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

      {  if (xfOut->fp == stdout)
         bStdout = 1
      ;  if (mclWriteMode == 'a' || (mclWriteMode == 'b' && bStdout))
         {  mclMatrixWriteAscii(cluster, xfOut, -1, EXIT_ON_FAIL)
         ;  if (mclWriteMode == 'b')
            {  fprintf
               (  stderr
               , "[mcl] Overrode format from binary to ascii (stdout)\n"
               )
         ;  }
      ;  }
         else
         mclMatrixWrite(cluster, xfOut, EXIT_ON_FAIL)
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

      fprintf
      (  stderr
      ,  "[mcl] [%d,%d,%d] jury marks for pruning, "
         "out of 100 (cf -scheme/-P/-R/-S/-pct)\n"
      ,  mclMarks[0]
      ,  mclMarks[1]
      ,  mclMarks[2]
      )
   ;  fprintf(stderr, "[mcl] %d clusters found\n", n_cluster)

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
"-dumpstem<str> use str as stem for dumped objects",
"\n",

"--ascii        output in native ascii format (default)",
"--binary       output in native binary format",
"\n",

"--dense        disable selection and recovery (but not rigid pruning)",
"--thick        expect computed vectors to have sparse zero-pattern",
"\n",

"--overlap      keep overlap (the default is removal of overlap)",
"--expand-only  compute first expansion, write to file, and exit",
"--inflate-first  start with inflation rather than expansion",
"-preprune <i>  prune columns of input matrix to a maximum of n entries",
"\n",

"--show         print MCL iterands (small graphs only)",
"-digits <i>    precision for printing",
"\n",

"-z             show the current settings",
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

"-progress <i>  if i>0, (try to) print i times `.' during one iteration  [30]",
"               if i<0, print `.' after every |i| vectors computed",
"               if i=0, print convergence measure after every iteration",
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
"--rigid \\      rigid pruning (the default)",
"--adapt /   ++ adaptive pruning by computing column-depending thresholds",
"-ae <f>      + adaptive pruning exponent (range 3-10 conceivable)      [2.0]",
"-af <f>      + adaptive pruning factor (range 1-100 conceivable)       [4.0]",
"\n",

"speed/quality controls",
"-p <f> \\       set precision (i.e. fixed threshold, cutof value) to f     []",
"-P <i> / +++++ equivalent to '-p f' where f == 1/i                [scheme 2]",
"                  these define the true cutof for rigid pruning and the",
"                  minimum cutof for adaptive pruning.",
"-S <i> / +++++ set selection number to i                          [scheme 2]",
"-R <i> / +++++ set recover number to i                            [scheme 2]",
"-pct <i> +++++ mass percentage below which to apply recovery      [scheme 2]",
"-scheme <i>    use a preset scheme for -P/-S/-R/-pct, (i=1,2,3,4)        [2]",
"--show-schemes show the preset schemes",
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
"defaults should be fine.",
"Try different -I values for finding clusterings of different granularity",
"(e.g. in the range 1.2 - 4.0). For example settings, explanations, and further",
"pointers, see http://members.ams.chello.nl/svandong/thesis/.",
"For very large graphs, try to understand selection (-S) and recovery (-R).",
"Report bugs to mcl-bugs@mdcc.cx",
"\n",

"---->  mcl <graph.mci> -I 2.0    should get you going. <----",
"\n",

"",              /* denotes end of array */
};

const char *ans_help
=
"Use -h for help, -z for settings. 'man mcl' should give you the manual pages\n"
"For more information and references see\n"
"http://members.ams.chello.nl/svandong/thesis/index.html.\n"
"Report bugs to mcl-bugs@mdcc.cx\n"
;

const char *ans_version
=
"mcl 2.0\n"
"Copyright (c) 1999-2001 Stijn van Dongen. mcl comes with NO WARRANTY, to the\n"
"extent permitted by law. You may redistribute copies of mcl under\n"
"the terms of the GNU General Public License.\n"
;


mclMatrix* mcxInitialize
(  int argc
,  char* const argv[]
)
   {  int               a, i
   ;  float             f
   ;  float             f_0         =  0.0
   ;  float             f_1         =  1.0
   ;  int               i_0         =  0
   ;  int               i_1         =  1
   ;  int               i_4         =  4
   ;  int               i_100       =  100
   ;  float             f_E1        =  1e-1
  /*  float             f_E20       =  1e-20 */
   ;  mclMatrix        *mx
   ;  mclIpretParam*    ipretParam  =  mclparam->mclIpretParam

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
         ;  centerMatrix = f == 0.0 ? 0 : 1
         ;  centerMatrixWeight = f
      ;  }
         else if (flagWithArg(a, "-a"))
         {  
            diagWeight  =  (float) atof(argv[++a])
         ;  flagCheckBounds
            ("-a", "float", &diagWeight, fltGt, &f_0, NULL, NULL)
         ;  addDiag   =  1
      ;  }
         else if (flagWithArg(a, "-B"))
         {  doBool(argv[++a])
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
         ;  doBool(argv[a]+2)
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
            ;  mclVerbosityMatrixProgress = TRUE
            ;  mclVerbosityVectorProgress = FALSE
         ;  }
            else
            mclVerbosityVectorProgress = TRUE

         ;  mclVectorProgression = usrVectorProgress
      ;  }
         else if (flagWithArg(a, "-tracki"))
         {  if
            (  sscanf
               (  argv[++a]
               ,  "%d:%d"
               ,  &mclTrackNonemaPruningOfset
               ,  &mclTrackNonemaPruningBound
               )
            != 2
            )
            {  fprintf
               (  stderr
               ,  "Flag -tracki expects i:j format, j=0 denoting infinity\n"
               )
            ;  exit(1)
         ;  }
         ;  mclTrackNonemaPruning = 1
      ;  }
         else if (flagWithArg(a, "-t"))
         {  
            mcl_num_ethreads = atoi(argv[++a])
         ;  flagCheckBounds
            (  "-t"
            ,  "integer", &mcl_num_ethreads, intGq, &i_0, NULL, NULL
            )
         ;  mcl_num_ithreads = mcl_num_ethreads
         ;  mclVerbosityPruning  = FALSE
      ;  }
         else if (flagWithArg(a, "-ti"))
         {  
            mcl_num_ithreads = atoi(argv[++a])
         ;  flagCheckBounds
            (  "-ti"
            ,  "integer", &mcl_num_ithreads, intGq, &i_0, NULL, NULL
            )
         ;  mclVerbosityPruning  = FALSE
      ;  }
         else if (flagWithArg(a, "-te"))
         {  
            mcl_num_ethreads = atoi(argv[++a])
         ;  flagCheckBounds
            (  "-te"
            ,  "integer", &mcl_num_ethreads, intGq, &i_0, NULL, NULL
            )
         ;  mclVerbosityPruning  = FALSE
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
            mclTrackNonemaPruningInterval = atoi(argv[++a])
         ;  flagCheckBounds
            (  "-trackm"
            ,  "integer", &mclTrackNonemaPruningInterval, intGq, &i_1, NULL, NULL
            )
         ;  mclTrackNonemaPruning = 1
      ;  }
         else if (flagWithArg(a, "-digits"))
         {  
            int   iten  =  10;
         ;  i = atoi(argv[++a])
         ;  flagCheckBounds
            ("-digits", "integer", &i, intGq, &i_1, intLq, &iten)
         ;  mclparam->printDigits = i
         ;  expandDigits = i
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
            n_prune           =  atoi(argv[++a])
         ;  flagCheckBounds("-P", "integer", &n_prune, intGq, &i_1, NULL, NULL)
      ;  }
         else if (flagWithArg(a, "-p"))
         {  
            float g           =  atof(argv[++a])
         ;  flagCheckBounds
            ("-p", "float", &g, fltGq, &f_0, fltLq, &f_E1)
         ;  n_prune           =  (int) (1.0 / g)
      ;  }
         else if (flagWithArg(a, "-warn-factor"))
         {  i =  atoi(argv[++a])
         ;  flagCheckBounds
            (  "-warn-factor"
            ,  "integer", &i, intGq, &i_0, NULL, NULL
            )
         ;  mclWarnFactor =  i
      ;  }
         else if (flagWithArg(a, "-warn-pct"))
         {  i =  atoi(argv[++a])
         ;  flagCheckBounds
            (  "-warn-pct"
            ,  "integer", &i, intGq, &i_0, intLt, &i_100
            )
         ;  mclWarnPct  =  ((float) i) / 100.0
      ;  }
         else if (flagWithArg(a, "-scheme"))
         {  n_scheme    =  atoi(argv[++a])
         ;  flagCheckBounds
            (  "-scheme"
            ,  "integer", &n_scheme, intGq, &i_1, intLq, &i_4
            )
         ;  n_scheme--
         ;  n_prune     =  scheme[n_scheme][0]
         ;  n_select    =  scheme[n_scheme][1]
         ;  n_recover   =  scheme[n_scheme][2]
         ;  n_pct       =  scheme[n_scheme][3]
      ;  }
         else if (!strcmp(argv[a], "--show-schemes"))
         {  doInfoFlag("--show-schemes")
      ;  }
         else if (flagWithArg(a, "-pct"))
         {  n_pct       =  atoi(argv[++a])
         ;  flagCheckBounds
            (  "-pct"
            ,  "integer", &n_pct, intGq, &i_0, intLt, &i_100
            )
      ;  }
         else if (flagWithArg(a, "-R"))
         {  n_recover   =  atoi(argv[++a])
         ;  flagCheckBounds
            ("-R", "integer", &n_recover, intGq, &i_0, NULL, NULL)
      ;  }
         else if (flagWithArg(a, "-S"))
         {  n_select          =  atoi(argv[++a])
         ;  flagCheckBounds
            ("-S", "integer", &n_select, intGq, &i_0, NULL, NULL)
      ;  }
         else if (flagWithArg(a, "-M"))
         {  n_select          =  atoi(argv[++a])
         ;  n_recover         =  n_select
         ;  flagCheckBounds
            ("-m", "integer", &n_select, intGq, &i_0, NULL, NULL)
      ;  }
         else if (flagWithArg(a, "-m"))
         {  n_select          =  atoi(argv[++a])
         ;  n_recover         =  n_select
         ;  flagCheckBounds
            ("-m", "integer", &n_select, intGq, &i_0, NULL, NULL)
      ;  }
         else if (flagWithArg(a, "-ae") || flagWithArg(a, "-adapt-exponent"))
         {  mclCutExp         =  atof(argv[++a])
         ;  mclModePruning    =  MCL_PRUNING_ADAPT

         ;  flagCheckBounds
            (  "-ae"
            ,  "float", &mclCutExp, fltGq, &f_1, NULL, NULL
            )
      ;  }
         else if (flagWithArg(a, "-af") || flagWithArg(a, "-adapt-factor"))
         {  mclCutCof         =  atof(argv[++a])
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
         {  n_preprune = atoi(argv[++a])
         ;  flagCheckBounds
            ("-preprune", "integer", &n_preprune, intGq, &i_1, NULL, NULL)
      ;  }
         else if (flagWithArg(a, "-devel"))
         {  mclDevel =  atoi(argv[++a])      /* as a quick debug hook */
      ;  }
         else if (flagWithArg(a, "-dumpstem"))
         {  mclDumpStem = argv[++a]             /* bad hack? */
      ;  }
         else if (flagWithArg(a, "-v"))
         {  a++

         ;  if (strcmp(argv[a], "pruning") == 0)
            mclVerbosityPruning    =  TRUE

         ;  else if (strcmp(argv[a], "io") == 0)
            mclVerbosityIoNonema   =  TRUE

         ;  else if (strcmp(argv[a], "mcl") == 0)
            mclVerbosityMcl        =  TRUE

         ;  else if (strcmp(argv[a], "explain") == 0)
            mclVerbosityExplain    =  TRUE

         ;  else if (strcmp(argv[a], "progress") == 0)
            mclVerbosityVectorProgress =  TRUE

         ;  else if (strcmp(argv[a], "all") == 0)
            doBool("verbose")
      ;  }
         else if (flagWithArg(a, "-V"))
         {  a++

         ;  if (strcmp(argv[a], "pruning") == 0)
            mclVerbosityPruning    =  FALSE

         ;  else if (strcmp(argv[a], "io") == 0)
            mclVerbosityIoNonema   =  FALSE

         ;  else if (strcmp(argv[a], "explain") == 0)
            mclVerbosityExplain    =  FALSE

         ;  else if (strcmp(argv[a], "mcl") == 0)
            mclVerbosityMcl        =  FALSE

         ;  else if (strcmp(argv[a], "progress") == 0)
            mclVerbosityVectorProgress =  FALSE

         ;  else if (strcmp(argv[a], "all") == 0)
            doBool("silent")
      ;  }
         else if (flagWithArg(a, "-dump"))
         {  a++
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
         {  mclDumpModulo = atoi(argv[++a])
         ;  flagCheckBounds
            ("-dumpm", "integer", &mclDumpModulo, intGq, &i_1, NULL, NULL)
      ;  }
         else if (!strcmp(argv[a], "-z") || !strcmp(argv[a], "--show-settings"))
         {  doInfoFlag("-z")
      ;  }
         else
         {  fprintf(stderr, "Unrecognized flag %s\n", argv[a])
         ;  doInfoFlag("--help")
         ;  exit(1)
      ;  }
      ;  a++
   ;  }

      makeSettings()
   ;  mx =  mclMatrixRead(xfIn, EXIT_ON_FAIL)
   ;  mcxIOstreamFree(&xfIn)
   ;

      if (addDiag)
      diagAll =  mclMatrixDiag(mx->N_cols, diagWeight, NULL, 0)
   ;

  /* 
   *     because of initialization the condition below means that
   *     user has not used -progress flag or given it argument 0.
   *     This setup is very ugly, general problem when trying to
   *     make constituting elements of default settings interact.
  */
      if ((mcl_num_ethreads || mcl_num_ithreads) && !usrVectorProgress)
      {
         mclVerbosityMatrixProgress = TRUE
      ;  mclVerbosityVectorProgress = FALSE
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

   ;  if (mclTrackNonemaPruning)
      {  mclTrackStreamNonema = mcxIOstreamNew("-", "w")
      ;  mcxIOstreamOpen(mclTrackStreamNonema, EXIT_ON_FAIL)
   ;  }

   ;  return mx
;  }


void doBool
(  const char *string
)
   {
      if (!strcmp(string, "track"))
      {  mclTrackNonemaPruning   =  1
   ;  }
      else if (!strcmp(string, "overlap"))
      {  keepOverlap             =  1
   ;  }
      else if (!strcmp(string, "silent"))
      {  mclVerbosityPruning     =  FALSE
      ;  mclVerbosityIoNonema    =  FALSE
      ;  mclVerbosityExplain     =  FALSE
      ;  mclVerbosityMcl         =  FALSE
      ;  mclVerbosityVectorProgress = FALSE
   ;  }
      else if (!strcmp(string, "verbose"))
      {  mclVerbosityPruning     =  TRUE
      ;  mclVerbosityIoNonema    =  TRUE
      ;  mclVerbosityExplain     =  TRUE
      ;  mclVerbosityMcl         =  TRUE
      ;  mclVerbosityVectorProgress = TRUE
   ;  }
      else if (!strcmp(string, "ascii"))
      {    mclWriteMode          =  'a'
      ;    mclDumpMode           =  'a'
   ;  }
      else if (!strcmp(string, "expand-only"))
      {    expandOnly            =  TRUE
   ;  }
      else if (!strcmp(string, "inflate-first"))
      {    mclInflateFirst       =  TRUE
   ;  }
      else if (!strcmp(string, "inflate-first"))
      {
   ;  }
      else if (!strcmp(string, "binary"))
      {    mclWriteMode          =  'b'
      ;    mclDumpMode           =  'b'
   ;  }
      else if (!strcmp(string, "thick"))
      {  mclModeCompose = MCL_COMPOSE_DENSE
   ;  }
      else if (!strcmp(string, "rigid"))
      {  mclModePruning = MCL_PRUNING_RIGID
   ;  }
      else if (!strcmp(string, "adapt"))
      {  mclModePruning = MCL_PRUNING_ADAPT
   ;  }
      else if (!strcmp(string, "clone"))
      {  mclCloneMatrices        =  TRUE
   ;  }
      else if (!strcmp(string, "show"))
      {  mclparam->printMatrix   =  TRUE
   ;  }
      else if (!strcmp(string, "dense"))
      {  n_prune                 =  0
      ;  n_select                =  0
      ;  mclModeCompose = MCL_COMPOSE_DENSE
   ;  }
      else
      {  fprintf(stderr, "[mcl] Unrecognized flag --%s\n", string)
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


void usage(const char** lines);
void showsettings(void);
void showschemes(void);

void doInfoFlag(const char *string)
{
;  if (!strcmp(string, "--help"))         fprintf(stdout, "%s", ans_help)
;  else if (!strcmp(string, "--version")) fprintf(stdout, "%s", ans_version)
;  else if (!strcmp(string, "-h"))        usage(usageLines)
;  else if (!strcmp(string, "-z"))        showsettings()
;  else if (!strcmp(string, "--show-settings")) showsettings()
;  else if (!strcmp(string, "--show-schemes")) showschemes()
;  else                                   usage(usageLines)
;  exit(0)
;
}

void showschemes
(  void
)
   {  int i
   ;  fprintf
      (  stdout
      ,  "%20s%15s%15s%15s\n"  
      ,  "Pruning"
      ,  "Selection"
      ,  "Recovery"
      ,  "  Recover percentage"
      )
   ;  for (i=0;i<4;i++)
      fprintf
      (  stdout
      ,  "Scheme %1d%12d%15d%15d%15d\n"
      ,  i+1
      ,  scheme[i][0]
      ,  scheme[i][1]
      ,  scheme[i][2]
      ,  scheme[i][3]
      )
;  }

void makeSettings
(  void
)
   {  mclPruneNumber       =  n_prune  < 0  ?  scheme[1][0] :  n_prune
   ;  mclSelectNumber      =  n_select < 0  ?  scheme[1][1] :  n_select
   ;  mclRecoverNumber     =  n_recover< 0  ?  scheme[1][2] :  n_recover
   ;  mclPct               =  n_pct    < 0  ?  scheme[1][3] :  n_pct

   ;  mclPrecision         =  0.99999 / mclPruneNumber
   ;  mclPct              /=  100.0
;  }


void showsettings (void)  
{
   makeSettings()
;  printf("[mcl] current settings:\n");
;  printf
   (  "%-40s%8d%8s%s\n"
   ,  "Prune number", mclPruneNumber, "", "[-P n]")
;  printf
   (  "%-40s%8d%8s%s\n"
   , "Selection number", mclSelectNumber, "", "[-S n]")
;  printf
   (  "%-40s%8d%8s%s\n"
   , "Recovery number", mclRecoverNumber, "", "[-R n]")
;  printf
   (  "%-40s%8d%8s%s\n"
   , "Recovery percentage", (int) (100*mclPct+0.5), "", "[-pct n]")
;  printf
   (  "%-40s%8d%8s%s\n"
   , "nx (worst pruning instances)", mcl_nx,  "", "[-nx n]")
;  printf
   (  "%-40s%8d%8s%s\n"
   , "ny (worst pruning instances)", mcl_ny,  "", "[-ny n]")
;  printf
   (  "%-40s%11.2f%5s%s\n"
   , "adapt-exponent", mclCutExp, "", "[-ae f]")
;  printf
   (  "%-40s%11.2f%5s%s\n"
   , "adapt-factor", mclCutCof, "", "[-af f]")
;  printf
   (  "%-40s%8d%8s%s\n"
   ,  "Clone threshold (vector density)", mclCloneBarrier, "", "[-cloneat f]")
;  printf
   (  "%-40s%8s%8s%s\n"
   , "dumpstem", mclDumpStem, "", "[-dumpstem str]")
;  printf
   (  "%-40s%8d%8s%s\n"
   ,  "Initial loop length", mclparam->initLoopLength, "", "[-l n]")
;  printf
   (  "%-40s%8d%8s%s\n"
   ,  "Main loop length", mclparam->mainLoopLength, "", "[-L n]")
;  printf
   (  "%-40s%10.1f%6s%s\n"
   ,  "Initial inflation", mclparam->initInflation, "", "[-i f]")
;  printf
   (  "%-40s%10.1f%6s%s\n"
   ,  "Main inflation", mclparam->mainInflation, "", "[-I f]")
;  exit(0)
;
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


