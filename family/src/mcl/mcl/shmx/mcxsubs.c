/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <string.h>

#include "nonema/matrix.h"
#include "nonema/vector.h"
#include "nonema/ivp.h"
#include "nonema/io.h"
#include "mcl/interpret.h"
#include "util/txt.h"
#include "util/types.h"
#include "util/buf.h"

#include "intalg/parse.h"
#include "intalg/la.h"


typedef struct
{  
   mcxTing*    tagTxt
;  mcxTing*    specTxt          /*  text representation of spec   */
;  mclVector*  cVec             /*  contains col indices    */
;  mclVector*  rVec             /*  contains row indices    */
;  mcxbool     tagIsFname
;  
}  subSpec     ;


const char* usagelines[];
const char* speclines[];


void usage
(  const char**
)  ;


mclVector*  vectorFromString
(  const char* str
,  mclMatrix*  cl
,  mclVector*  vecV
)  ;


int main
(  int                  argc
,  const char*          argv[]
)  
   {  mcxIOstream       *xfCl       =  NULL
   ;  mcxIOstream       *xfMx       =  NULL

   ;  mclMatrix         *cl         =  NULL
   ;  mclVector         *vecCltags  =  NULL
   ;  mclMatrix         *mx         =  NULL
   ;  mclVector         *vecV       =  NULL

   ;  mcxTing            *fstem      =  mcxTingNew("out.sub-")

   ;  subSpec           *specList   =  NULL
   ;  int               n_spec      =  0
   ;  mcxBuf            specBuf

   ;  int               N           =  0
   ;  int               status      =  0
   ;  int               digits      =  3
   ;  int               a           =  1
   ;  int               i           =  0
   ;  int               bCltag      =  0

   ;  mcxBufInit(&specBuf,  &specList, sizeof(subSpec), 30)

   ;  if (argc==1)
      goto help

   ;  while(a < argc)
      {  if (!strcmp(argv[a], "-icl"))
         {  if (a++ + 1 < argc)
            {  xfCl  =  mcxIOstreamNew(argv[a], "r")
            ;  mcxIOstreamOpen(xfCl, EXIT_ON_FAIL)
         ;  }
            else goto arg_missing
      ;  }
         else if (!strcmp(argv[a], "-stem"))
         {  if (a++ + 1 < argc)
            mcxTingWrite(fstem, argv[a])
         ;  else goto arg_missing
      ;  }
         else if (!strcmp(argv[a], "--tag"))
         {  bCltag   =  1
      ;  }
         else if (!strcmp(argv[a], "-spec-defs"))
         {  usage(speclines)
         ;  exit(0)
      ;  }
         else if (!strcmp(argv[a], "-digits"))
         {  if (a++ + 1 < argc)
            digits   =  atoi(argv[a])
         ;  else goto arg_missing
      ;  }
         else if (!strcmp(argv[a], "-imx"))
         {  if (a++ + 1 < argc)
            {  xfMx  =  mcxIOstreamNew(argv[a], "r")
            ;  mcxIOstreamOpen(xfMx, EXIT_ON_FAIL)
         ;  }
            else goto arg_missing
      ;  }
         else if (!strcmp(argv[a], "-h"))
         {  goto help
      ;  }
         else if (0)
         {  die:
            status   =  1
         ;  goto help
      ;  }
         else if (0)
         {  help:
         ;  usage(usagelines)
         ;  exit(status)
      ;  }
         else if (0)
         {  arg_missing:
         ;  fprintf
            (  stderr
            ,  "[mcxsubs] Flag %s needs argument; see help (-h)\n"
            ,  argv[argc-1]
            )
         ;  exit(1)
      ;  }
         else
         {  
            subSpec*    spec     =  (subSpec*) mcxBufExtend(&specBuf, 1)

         ;  spec->specTxt        =  mcxTingNew(argv[a])
         ;  spec->tagTxt         =  NULL
         ;  spec->tagIsFname     =  0
         ;  spec->cVec           =  mclVectorInit(NULL)
         ;  spec->rVec           =  mclVectorInit(NULL)
      ;  }
      ;  a++
   ;  }

   ;  n_spec =  mcxBufFinalize(&specBuf)

   ;  if (!xfMx)
      {  fprintf
         (  stderr
         ,  "[mcxsubs] -imx flag is obligatory, see help (-h)\n"
         )
      ;  exit(1)
   ;  }
      else
      {  mx    =  mclMatrixRead(xfMx, EXIT_ON_FAIL)
      ;  if (mx->N_cols != mx->N_rows)
            fprintf(stderr, "[mcxsubs] matrix is not square!\n")
         ,  exit(1)
      ;  N     =  mx->N_cols
      ;  vecV  =  mclVectorComplete(NULL, N, 1.0)
   ;  }

   ;  if (xfCl)
      {  
         cl    =  mclMatrixRead(xfCl, EXIT_ON_FAIL)

      ;  if (cl->N_rows != mx->N_cols)
            fprintf
            (  stderr
            ,  "[mcxsubs] matrix dimension [%d]"
               " does not match clustering range [%d]\n"
            ,  mx->N_cols
            ,  cl->N_rows
            )
         ,  exit(1)
   ;  }

   ;  mcxIOstreamFree(&xfMx)
   ;  mcxIOstreamFree(&xfCl)

   ;  if (bCltag)
      {  
         mclMatrix*  el2cl
      ;  int   x

      ;  if (!cl)
         {  fprintf
            (  stderr
            ,  "[mcxsubs] option --tag requires -icl input\n"
            )
         ;  exit(1)
      ;  }

      ;  el2cl =  mclMatrixTranspose(cl)
      ;  vecCltags               =  mclVectorComplete(NULL, cl->N_rows, 1.0)

      ;  for (x=0;x<vecCltags->n_ivps;x++)
         {  
            mclIvp      *ivp     =  (el2cl->vectors+x)->ivps+0
         ;  (vecCltags->ivps+x)->idx   =  ivp ? ivp->idx : -1
      ;  }

      ;  mclMatrixFree(&el2cl)
   ;  }


   ;  for (i=0;i<n_spec;i++)
      {
         subSpec        *spec          =  specList+i

      ;  mclVector      *colVec        =  NULL
      ;  mclVector      *rowVec        =  NULL

      ;  char           *specStr       =  mcxTingStr(spec->specTxt)

      ;  char           *rTag          =  NULL
      ;  char           *cTag          =  NULL
      ;  char           *rSpec         =  NULL
      ;  char           *cSpec         =  NULL

      ;  char           rType          =  '\0'
      ;  char           cType          =  '\0'

      ;  char           *tagPtr        =  strchr(specStr, '#')

      ;  if (tagPtr)
         {  
            *tagPtr        =  '\0'
         ;  tagPtr++

         ;  if (*tagPtr == '#')
            {  
               spec->tagIsFname  =  1
            ;  tagPtr++
         ;  }
         ;  spec->tagTxt   =  mcxTingNew(tagPtr)
      ;  }
         else
         {  spec->tagTxt   =  mcxTingNew(spec->specTxt->str)
      ;  }


      ;  cTag              =  strpbrk(specStr, "cC")
      ;  rTag              =  strpbrk(specStr, "rR")

      ;  if (cTag)
         {
            cType          =  *cTag
         ;  cSpec          =  strchr(cTag+1, ':')

         ;  if (!cSpec)
            {
               fprintf
               (  stderr
               ,  "[mcxsubs] cannot find ':' tag after ´%c' tag\n"
               ,  cType
               )
            ;  exit(1)
         ;  }
         ;  cSpec++
      ;  }

         if (rTag)
         {
            rType          =  *rTag
         ;  rSpec          =  strchr(rTag+1, ':')

         ;  if (!rSpec)
            {
               fprintf
               (  stderr
               ,  "[mcxsubs] cannot find ':' tag after ´%c' tag\n"
               ,  rType
               )
            ;  exit(1)
         ;  }
         ;  rSpec++
      ;  }

         if (cTag)
         *cTag             =  '\0'
      ;  if (rTag)
         *rTag             =  '\0'

      ;  if (cTag)
         {  
            fprintf(stdout, "[mcxsubs] parsing column poly-spec [%s]\n", cSpec)
         ;  colVec         =  vectorFromString(cSpec, cl, vecV)
         ;  if (cType == 'C')
            {  colVec      =  mclVectorSetMinus(vecV, colVec, colVec)
         ;  }
      ;  }
         else
         {  colVec         =  mclVectorInstantiate
                              (colVec, vecV->n_ivps, vecV->ivps)
      ;  }

      ;  if (rTag)
         {  
            fprintf(stdout, "[mcxsubs] parsing row poly-spec [%s]\n", rSpec)
         ;  rowVec         =  vectorFromString(rSpec, cl, vecV)
         ;  if (rType == 'R')
            {  rowVec      =  mclVectorSetMinus(vecV, rowVec, rowVec)
         ;  }
      ;  }
         else
         {  rowVec         =  mclVectorInstantiate
                              (rowVec, vecV->n_ivps, vecV->ivps)
      ;  }

      ;  spec->cVec        =  colVec
      ;  spec->rVec        =  rowVec

      ;  if (mclVectorCheck
               (rowVec, mx->N_rows, RETURN_ON_FAIL) != STATUS_OK
            )
         {  fprintf(stderr, "[mcxsubs] row specification out of bounds\n")
         ;  exit(1)
      ;  }

      ;  if (mclVectorCheck
               (colVec, mx->N_cols, RETURN_ON_FAIL) != STATUS_OK
            )
         {  fprintf(stderr, "[mcxsubs] column specification out of bounds\n")
         ;  exit(1)
      ;  }
   ;  }

   ;  for (i=0;i<n_spec;i++)
      {
         mclMatrix*           sub

      ;  subSpec*             spec     =  specList+i
      ;  mcxTing*              tagTxt   =  (specList+i)->tagTxt

      ;  mcxTing               *fname   =     spec->tagIsFname
                                          ?  mcxTingInit(NULL)
                                          :  mcxTingNew(fstem->str)
      ;  mcxIOstream          *xf
      ;  int                  j        =  0

      ;  mcxTingAppend(fname, tagTxt->str)
      ;  xf    =  mcxIOstreamNew(fname->str, "w")

      ;  if (mcxIOstreamOpen(xf, RETURN_ON_FAIL) == STATUS_FAIL)
         {  fprintf
            (  stderr
            ,  "[mcxsubs] cannot open file [%s] for writing! Ignoring\n"
            ,  xf->fn->str
            )
         ;  mcxTingFree(&fname)
         ;  mcxIOstreamFree(&xf)
         ;  continue
      ;  }

      ;  sub
         =  mclMatrixSub
            (  mx
            ,  spec->cVec
            ,  spec->rVec
            )

      ;  if (bCltag)
         mclMatrixTaggedWrite(sub, vecCltags, xf, digits, RETURN_ON_FAIL)
      ;  else
         mclMatrixWriteAscii(sub, xf, digits, RETURN_ON_FAIL)

      ;  mclMatrixFree(&sub)
      ;  mcxTingFree(&fname)
      ;  mcxIOstreamFree(&xf)
   ;  }
   ;  return 0
;  }

const char* speclines[] = {
"[mcxsubs submatrix specification]",
"\n",
"The loosely formal definition of a submatrix specification follows below",
"Skip to the examples at the end if you must",
"\n",
"<sub-spec>     =     {c|C}:<poly-spec>{r|R}:<poly-spec>",
"                   | {c|C}:<poly-spec>",
"                   | {r|R}:<poly-spec>",
"                   | {c|C}{r|R}:<poly-spec>",
"\n",
"{x|X}          =     literal x or X",
":              =     literal ':'",
"\n",
"c: specify columns indices by taking the set yielded by poly-spec.",
"C: specify columns indices by taking the complement of this set.",
"\n",
"r: specify row indices by taking the set yielded by poly-spec.",
"R: specify row indices by taking the complement of this set.",
"\n",
"Omitting an 'r'/'R' specification silently implies taking all possible",
"entries for the row specification.",
"Omitting a 'c'/'C' specification silently implies taking all possible",
"entries for the column specification.",
"\n",
"<poly-spec>    =     {i|I}<idx-list>{s|S}<idx-list>",
"                   | {i|I}<idx-list>",
"                   | {s|S}<idx-list>",
"                   | {}                      ({} denotes empty string)",
"\n",
"                     <poly-spec> is allowed to be the empty string.",
"\n",
"<idx-list>     =     comma-separated list of indices and ranges of indices,",
"                     e.g.  0,1,3-5,4,8,6-10. Overlap and repeat is allowed.",
"\n",
"                     <idx-list> is allowed to be the empty string.",
"\n",
"i: specify a set of indices as the set yielded by idx-list.",
"I: specify a set of indices as the complement of this set.",
"\n",
"s: specify a set of indices by interpreting each entry in idx-list",
"   as the index of a cluster, and take the union of all indices",
"   in all clusters thus specified.",
"S: specify a set of indices by interpreting each entry in idx-list",
"   as the index of a cluster, and take the complement of the union",
"   of all indices in all clusters thus specified.",
"\n",
"cr:s14",
"   'Diagonal' submatrix corresponding with cluster indexed 14: (diagonal",
"   means row and column indices are taken from the same set).",
"\n",
"r:i1-10,12s108,106c:s14",
"   Row indices are from the set {1-10,12} plus the indices in clusters",
"   108 and 106, column indices are from cluster 14.",
"\n",
"cR:s14 | c:s14R:s14 | c:s14r:S14",
"   Column entries *in* cluster 14 and row entries *not in* cluster 14.",
"\n",
"The specification ':' yields the full original matrix ('rc:I' and 'RC:i'",
"do the same), this can be useful if you want the original matrix in",
"tagged form, using --tag.",
"\n",
""
}  ;

const char* usagelines[] = {
"Usage: mcxsubs <options> <sub-spec>+",
"\n",
"Mandatory option:",
"-imx    <fname>  read graph in MCL matrix format",
"\n",
"Optional options:",
"-icl    <fname>  read clustering, must pertain to matrix given by -imx",
"-stem   <str>    use str as stem for output file names (default out.sub-)",
"-digits <int i>  output i significant decimals for matrix entries (default 3)",
"                    i=-1 suppresses printing of values",
"--tag            tag matrix indices with the cluster they are in",
"-spec-defs       print definition of sub-spec. Required reading!",
"                 The examples will get you going immediately.",
"\n",
"You can instruct mcxsubs to extract and return `the submatrix        ",
"corresponding with column entries A and row entries B', or,          ",
"alternatively, `the edges going from A to B'. The sets A and B can be",
"specified using unions of simple indices and clusters and complements",
"of these. Do -spec-defs for how to instruct mcxsubs.                    ",
"\n",
"You may append a string '#tag' or '##tag' to a sub-spec. The former  ",
"will cause the specified submatrix to be written in the file named   ",
"<stem>-tag, where <stem> is default 'out.sub-' and changeable using  ",
"the -stem option. Using '##tag' will simply result in a file named   ",
"'tag'. Not using a '#' or '##' induced tag makes the sub-spec itself ",
"the tag.                                                             ",
"\n",
"Do 'mcxsubs -spec-defs' for learning about submatrix specification",
"\n",

""             /* denotes end of array */
}  ;


mclVector*  vectorFromString
(  const char*    str
,  mclMatrix*     cl
,  mclVector*     vecV
)
   {  mcxTing*     txt     =     mcxTingNew(str)
   ;  char*       mystr    =     mcxTingStr(txt)
   ;  char*       iPtr     =     strpbrk(mystr, "iI")
   ;  char*       sPtr     =     strpbrk(mystr, "sS")
   ;  mclVector   *iVec    =     NULL
   ;  mclVector   *sVec    =     mclVectorInit(NULL)     /* cluster vector */
   ;  mclVector   *subVec  =     NULL

   ;  char        iType    =     '\0'
   ;  char        sType    =     '\0'

   ;  if (iPtr)
      {  iType =  *iPtr
      ;  *iPtr =  '\0'
   ;  }
   ;  if (sPtr)
      {  sType =  *sPtr
      ;  *sPtr =  '\0'
   ;  }


   ;  if (txt->len && !iPtr && !sPtr)
      {
         fprintf
         (  stderr
         ,  "[mcxsubs] warning: no 'i', 'I', 's', or 'S' tag in"
            " specification [%s]\n"
         ,  txt->str
         )
   ;  }

   ;  if (iPtr)
      {
         Ilist *intList
      ;  fprintf
         (stdout, "[mcxsubs] Parsing simple index set [%c%s]\n", iType, iPtr+1)

      ;  intList           =  ilParseIntSet(iPtr+1, EXIT_ON_FAIL)
      ;  iVec              =  mclVectorFromIlist(NULL, intList, 1.0)
      ;  ilFree(&intList)
      ;  if (iType == 'I')
         iVec              =  mclVectorSetMinus(vecV, iVec, iVec)
   ;  }
      else
      {  iVec              =  mclVectorInit(NULL)
   ;  }

   ;  if (sPtr)
      {
         int   x
      ;  Ilist *clsList

      ;  fprintf
         (stdout, "[mcxsubs] Parsing cluster index set [%c%s]\n", sType, sPtr+1)
      ;  clsList           =  ilParseIntSet(sPtr+1, EXIT_ON_FAIL)

      ;  if (!cl)
         {  fprintf
            (  stderr
            ,  "[mcxsubs] {s|S}<idx-list> specification requires -icl input\n"
            )
         ;  exit(1)
      ;  }

      ;  for (x=0;x<clsList->n;x++)
         {  
            int   clusIdx  =  *(clsList->list+x)
         ;  if (clusIdx < 0 || clusIdx >= cl->N_cols)
            {
               fprintf
               (  stderr
               ,  "[mcxsubs] index <%d> out of cluster index bounds [0,%d)\n"
               ,  clusIdx
               ,  cl->N_cols
               )
            ;  exit(1)
         ;  }
         ;  sVec           =  mclVectorSetMerge(sVec, cl->vectors+clusIdx, sVec)
      ;  }
      ;  ilFree(&clsList)

      ;  if (sType == 'S')
         sVec              =  mclVectorSetMinus(vecV, sVec, sVec)
   ;  }

   ;  subVec               =  mclVectorSetMerge(iVec, sVec, subVec)
   ;  mclVectorFree(&iVec)
   ;  mclVectorFree(&sVec)
   ;  return(subVec)
;  }


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

      fprintf(stdout, "[mcxsubs] Printed %d lines\n", i+1)
;  }


