
#include "nonema/io.h"
#include "nonema/iface.h"

#include "util/parse.h"
#include "util/types.h"
#include "util/file.h"
#include "util/array.h"
#include "util/txt.h"
#include "util/buf.h"
#include "util/alloc.h"

/*
////////////////////////////////////////////////////////////////////////
//
//    mcxMatrix I/O
//
*/

mcxstatus  mcxMatrixReadAsciiHeader
(  mcxIOstream*            xfIn
,  int                     *pN_rows
,  int                     *pN_cols
)  ;


mcxstatus  mcxMatrixFilePeek
(  mcxIOstream*            xfIn
,  int                     *pN_cols
,  int                     *pN_rows
,  mcxOnFail               ON_FAIL
)  {
      int   f_pos

   ;  if (!xfIn->fp && mcxIOstreamOpen(xfIn, ON_FAIL) != STATUS_OK)
      return STATUS_FAIL

   ;  f_pos          =     ftell(xfIn->fp)

   ;  if
      (  xfIn->fp != stdin
      && IoExpectMagicNumber(xfIn->fp, MatrixMagicNumber)
      )
      {  fread(pN_cols, sizeof(int), 1, xfIn->fp)
      ;  fread(pN_rows, sizeof(int), 1, xfIn->fp)
   ;  }
      else if (mcxMatrixReadAsciiHeader(xfIn, pN_rows, pN_cols) != STATUS_OK)
      {  
         fprintf
         (  stderr
         ,  "[mcxMatrixFilePeek] could not parse header\n"
         )
      ;  if (ON_FAIL == RETURN_ON_FAIL)
         return STATUS_FAIL
      ;  else
         exit(1)
   ;  }

   ;  fseek(xfIn->fp, f_pos, SEEK_SET)
   ;  mcxIOstreamRewind(xfIn)             /* temporary solution */

   ;  return STATUS_OK
;  }


mcxMatrix* mcxMatrixMaskedRead
(  mcxIOstream*            xfIn
,  const mcxVector*        selector
,  mcxOnFail               ON_FAIL
)  {
      mcxMatrix*           mx          =  NULL
   ;  int                  N_rows      =  0
   ;  int                  N_cols      =  0

   ;  mcxMatrixFormatFound             =  'b'

   ;  if (!xfIn->fp && mcxIOstreamOpen(xfIn, ON_FAIL) != STATUS_OK)
      {  mcxIOstreamErr(xfIn, "mcxMatrixMaskedRead", "can not be opened", NULL)
      ;  return NULL
   ;  }

   ;  if
      (  xfIn->fp != stdin
      && IoExpectMagicNumber(xfIn->fp, MatrixMagicNumber)
      )
      {
         mcxVector         *vec
      ;  int               n_ivps      =  selector ? selector->n_ivps : 0
      
      ;  fread(&N_cols, sizeof(int), 1, xfIn->fp)
      ;  fread(&N_rows, sizeof(int), 1, xfIn->fp)

      ;  mx                            =  mcxMatrixAllocZero(N_cols, N_rows)
      ;  vec                           =  mx->vectors

      ;  if (selector)
         {  int         f_pos          =  ftell(xfIn->fp)
         ;  int         k              =  0
         ;  int         v_pos

         ;  while (k < n_ivps)
            {  int      vec_idx        =  selector->ivps[k].idx

            ;  fseek(xfIn->fp, f_pos + vec_idx * sizeof(int), SEEK_SET)
            ;  v_pos = IoReadInteger(xfIn->fp)
            ;  fseek(xfIn->fp, v_pos, SEEK_SET)
            ;  mcxVectorEmbedRead(vec + vec_idx, xfIn, EXIT_ON_FAIL)
            ;  k++
         ;  }

            /*
            // Move to end of matrix body
            //
            */            
         ;  fseek(xfIn->fp, f_pos + N_cols * sizeof(int), SEEK_SET)
         ;  v_pos = IoReadInteger(xfIn->fp)
         ;  fseek(xfIn->fp, v_pos, SEEK_SET)
      ;  }
         else
         {  fseek(xfIn->fp, ((1 + N_cols) * sizeof(int)), SEEK_CUR)
         ;  while (--N_cols >= 0)
            mcxVectorEmbedRead(vec++, xfIn, EXIT_ON_FAIL)
      ;  }
      
      ;  if (mcxVerbosityIoNonema)
         fprintf
         (  stdout
         ,  "[mclIO] Read native binary %dx%d matrix from stream [%s]\n"
         ,  mx->N_rows
         ,  mx->N_cols
         ,  xfIn->fn->str
         )
   ;  }
      else
      {  mx                         =  mcxMatrixReadAscii(xfIn, ON_FAIL)
      ;  mcxMatrixFormatFound       =  'a'
   ;  }
   ;  return mx
;  }


mcxstatus mcxMatrixWrite
(  const mcxMatrix*        mx
,  mcxIOstream*            xfOut
,  mcxOnFail               ON_FAIL
)  {  
      int                  N_cols   =  mx->N_cols
   ;  mcxVector*           vec      =  mx->vectors
   ;  mcxstatus            status   =  0
   ;  int                  v_pos    =  0
   ;  FILE*                fout     =  xfOut->fp

   ;  if (xfOut->fp == NULL)
      {  if ((mcxIOstreamOpen(xfOut, ON_FAIL) != STATUS_OK))
         {  fprintf
            (  stderr
            ,  "[mcxMatrixWrite] cannot open stream [%s]\n"
            ,  xfOut->fn->str
            )
         ;  if (ON_FAIL == RETURN_ON_FAIL)
            return STATUS_FAIL
         ;  else
            exit(1)
      ;  }
   ;  }

   ;  IoWriteMagicNumber(fout, MatrixMagicNumber)
   
   ;  fwrite(&N_cols, sizeof(int), 1, fout)
   ;  fwrite(&mx->N_rows, sizeof(int), 1, fout)

      /*
      // Write vector offsets (plus one for end of matrix body)
      //
      */
   ;  v_pos = ftell(fout) + (1 + N_cols) * sizeof(int)
   ;  while (--N_cols >= 0)
      {  IoWriteInteger(fout, v_pos)
      ;  v_pos += sizeof(int) + vec->n_ivps * sizeof(mcxIvp)
      ;  vec++
   ;  }
   ;  IoWriteInteger(fout, v_pos)

      /*
      // Write vectors
      //
      */   
   ;  N_cols      =  mx->N_cols
   ;  vec         =  mx->vectors

   ;  while (--N_cols >= 0)
      {  status = mcxVectorEmbedWrite(vec, xfOut)
      ;  if (status == STATUS_FAIL) break
      ;  vec++
   ;  }
   
   ;  if (mcxVerbosityIoNonema)
      fprintf
      (  stdout
      ,  "[mclIO] Wrote native binary %dx%d matrix to stream [%s]\n"
      ,  mx->N_rows
      ,  mx->N_cols
      ,  xfOut->fn->str
      )
   ;  return status
;  }


mcxstatus  mcxMatrixReadAsciiHeader
(  mcxIOstream*         xfIn
,  int                  *pN_rows
,  int                  *pN_cols
)  {
      mcxTable          *headerTxtPairs   =  mcxTableNew
                                             (  2
                                             ,  2
                                             ,  sizeof(mcxTxt)
                                             ,  mcxTxtInit
                                             )
   ;  int               MCLTYPE           =  0
   ;  int               DIMENSIONS        =  1
   ;  int               KEY               =  0
   ;  int               VAL               =  1

   ;  if
      (  mcxFpFindInFile
         (  xfIn
         ,  "(mclheader"
         ,  "mcxMatrixReadAsciiHeader"
         ,  RETURN_ON_FAIL
         )
      != STATUS_OK
      )
      {  mcxTableFree(&headerTxtPairs, mcxTxtRelease)
      ;  return STATUS_FAIL
   ;  }

   ;  mcxTxtWrite
      (  (mcxTxt*) (headerTxtPairs->ls+MCLTYPE)->ls+KEY
      ,  "mcltype"
      )
   ;  mcxTxtWrite
      (  (mcxTxt*) (headerTxtPairs->ls+DIMENSIONS)->ls+KEY
      ,  "dimensions"
      )

   ;  mcxParseHeaderLines(xfIn, headerTxtPairs)

   ;  if
      (  !((mcxTxt*) (headerTxtPairs->ls+MCLTYPE)->ls+VAL)->str
      || strcmp
         (((mcxTxt*) (headerTxtPairs->ls+MCLTYPE)->ls+VAL)->str, "matrix")
      )
      {  fprintf
         (  stderr
         ,  "[mcxMatrixReadAsciiHeader] expected `mcltype matrix'"
            " specification not found\n"
         )
      ;  mcxIOstreamReport(xfIn, stderr)
      ;  mcxTableFree(&headerTxtPairs, mcxTxtRelease)
      ;  return STATUS_FAIL
   ;  }

      if
      (  !((mcxTxt*) (headerTxtPairs->ls+DIMENSIONS)->ls+VAL)->str
      || sscanf     
         (  ((mcxTxt*) (headerTxtPairs->ls+DIMENSIONS)->ls+VAL)->str
         ,  "%dx%d"
         ,  pN_rows
         ,  pN_cols
         )
         < 2
      )
      {  fprintf
         (  stderr
         ,  "[mcxMatrixReadAsciiHeader] expected `dimensions MxN'"
            " specification not found\n"
         )
      ;  mcxIOstreamReport(xfIn, stderr)
      ;  mcxTableFree(&headerTxtPairs, mcxTxtRelease)
      ;  return STATUS_FAIL
   ;  }

   ;  mcxTableFree(&headerTxtPairs, mcxTxtRelease)

   ;  if (*pN_rows <= 0 || *pN_cols <= 0)
      {  fprintf
         (  stderr
         ,  "[mcxMatrixReadAsciiHeader] each dimension must be positive"
            " (found %dx%d pair)\n"
         ,  *pN_rows
         ,  *pN_cols
         )
      ;  return STATUS_FAIL
   ;  }
   ;  return STATUS_OK
;  }


mcxMatrix* mcxMatrixReadAscii
(  mcxIOstream*            xfIn
,  mcxOnFail               ON_FAIL
)  {
      mcxMatrix*           mx             =  NULL
   ;  int                  N_rows         =  0
   ;  int                  N_cols         =  0
   ;  const char*          whoiam         =  "mcxMatrixReadAscii"

   ;  if (xfIn->fp == NULL && (mcxIOstreamOpen(xfIn, ON_FAIL) != STATUS_OK))
      {  fprintf
         (  stderr
         ,  "[mcxMatrixReadAscii] cannot open stream [%s]\n"
         ,  xfIn->fn->str
         )
         ;  if (ON_FAIL == RETURN_ON_FAIL)
            return NULL
         ;  else
            exit(1)
   ;  }


   ;  if (mcxMatrixReadAsciiHeader(xfIn, &N_rows, &N_cols) != 0)
      {  fprintf
         (  stderr
         ,  "[mcxMatrixReadAscii] could not successfully parse header\n"
         )
      ;  if (ON_FAIL == RETURN_ON_FAIL)
         return NULL
      ;  else
         exit(1)
   ;  }

   ;  mx = mcxMatrixAllocZero(N_cols, N_rows)

   ;  {  
         mcxBuf            buf

      ;  mcxFpFindInFile(xfIn, "(mclmatrix", whoiam, EXIT_ON_FAIL)
      ;  mcxFpFindInFile(xfIn, "begin", whoiam, EXIT_ON_FAIL)

      ;  for (;;)
         {  
            int            cidx
         ;  mcxVector*     vec

         ;  if (')' == mcxFpSkipSpace(xfIn, whoiam))
            break
         ;  cidx = (int) mcxFpParseNumber(xfIn, whoiam)

         ;  if (cidx < 0 || cidx >= N_cols)
            {  
               fprintf
               (  stderr
               ,  "[%s] column index [%d] geq column range [%d]\n"
               ,  whoiam
               ,  cidx
               ,  N_cols
               )
            ;  mcxIOstreamReport(xfIn, stderr)
            ;  mcxMatrixFree(&mx)
            ;  exit(1)
         ;  }

         ;  vec = mx->vectors + cidx
         ;  mcxBufInit(&buf,  &(vec->ivps), sizeof(mcxIvp), 30)

         ;  for (;;)
            {  
               if ('$' == mcxFpSkipSpace(xfIn, whoiam))
               {  mcxIOstreamStep(xfIn, fgetc(xfIn->fp))
               ;  break
            ;  }

               {  int      idx      =  (int) mcxFpParseNumber(xfIn, whoiam)
               ;  float    val      =  (':' == mcxFpSkipSpace(xfIn, whoiam))
                                    ?  (  mcxIOstreamStep
                                          (  xfIn, fgetc(xfIn->fp))
                                       ,  mcxFpParseNumber(xfIn, whoiam)
                                       )
                                    :  1.0

               ;  mcxIvp*  ivp      =  (mcxIvp*) mcxBufExtend(&buf, 1)

               ;  ivp->idx          =  idx
               ;  ivp->val          =  val

               ;  if (idx < 0 || idx >= N_rows || val < 0)
                  {  fprintf
                     (  stderr
                     ,  "[%s] "
                        "offending index-value pair specification [%d:%f]"
                        " at column [%d]\n"
                     ,  whoiam
                     ,  idx,  val, cidx
                     )
                  ;  mcxIOstreamReport(xfIn, stderr)
                  ;  mcxMatrixFree(&mx)
                  ;  exit(1)
               ;  }
            ;  }
         ;  }

         ;  vec->n_ivps    =  mcxBufFinalize(&buf)

         ;  mcxVectorSort(vec, NULL)
         ;  mcxVectorUniqueIdx(vec)
      ;  }
   ;  }

   ;  if (mcxVerbosityIoNonema)
      fprintf
      (  stdout
      ,  "[mclIO] Read native ascii %dx%d matrix from stream [%s]\n"
      ,  mx->N_rows
      ,  mx->N_cols
      ,  xfIn->fn->str
      )

   ;  return mx
;  }


void  mcxMatrixList
(  mcxMatrix*     mx
,  FILE*          fp
,  int            x_lo
,  int            x_hi
,  int            y_lo
,  int            y_hi
,  int            width
,  int            digits
,  const char*    msg
)  {  
      int   i

   ;  if (x_lo<0) x_lo = 0
   ;  if (y_lo<0) y_lo = 0

   ;  if (x_hi>mx->N_cols || x_hi == 0)
         x_hi = mx->N_cols

   ;  if (y_hi>mx->N_rows || y_hi == 0)
         y_hi = mx->N_rows

   ;  for (i=x_lo;i<x_hi;i++)
      {  fprintf(fp, "vec %d, %d ivps\n", i, (mx->vectors+i)->n_ivps)
      ;  mcxVectorList  
         (  mx->vectors+i
         ,  fp
         ,  y_lo
         ,  y_hi
         ,  width
         ,  digits
         ,  "        "
         ,  ""
         )
   ;  }
;  }


mcxstatus mcxMatrixTaggedWrite
(  const mcxMatrix*        mx
,  const mcxVector*        vecTags
,  mcxIOstream*            xfOut
,  int                     valdigits
,  mcxOnFail               ON_FAIL
)  {
      int   i
   ;  FILE* fp

   ;  if ((mx->N_cols != mx->N_rows) || (mx->N_cols != vecTags->n_ivps))
      {  fprintf
         (  stderr
         ,  "[mcxMatrixTaggedWrite] dimensions not right\n"
         )
      ;  if (ON_FAIL == RETURN_ON_FAIL)
         return STATUS_FAIL
      ;  else
         exit(1)
   ;  }

   ;  if (!xfOut->fp)
      {  if (mcxIOstreamOpen(xfOut, RETURN_ON_FAIL) != STATUS_OK)
         {  fprintf
            (  stderr
            ,  "[mcxMatrixTaggedWrite] cannot open stream [%s]\n"
            ,  xfOut->fn->str
            )
         ;  if (ON_FAIL == RETURN_ON_FAIL)
            return STATUS_FAIL
         ;  else
            exit(1)
      ;  }
   ;  }

   ;  fp =  xfOut->fp

   ;  fprintf  (  fp
               ,  "(mclheader\nmcltype taggedmatrix\ndimensions %dx%d\n)\n"
                  "(mclmatrix\nbegin\n"
               ,  mx->N_rows
               ,  mx->N_cols
               )           

   ;  for (i=0;i<mx->N_cols;i++)
      {  
         mcxVector*  tvec  =  mx->vectors+i
      ;  int         j

      ;  if (!tvec->n_ivps)
         continue

      ;  fprintf(fp, "%d(%d)  ", i, (vecTags->ivps+i)->idx)

      ;  for (j=0;j<tvec->n_ivps;j++)
         {  
            int   hidx     =  (tvec->ivps+j)->idx
         ;  float hval     =  (tvec->ivps+j)->val

         ;  if (valdigits > -1)
            fprintf
            (  fp
            ,  " %d(%d):%.*f"
            ,  hidx
            ,  (vecTags->ivps+hidx)->idx
            ,  valdigits
            ,  hval
            )
         ;  else
            fprintf
            (  fp
            ,  " %d(%d)"
            ,  hidx
            ,  (vecTags->ivps+hidx)->idx
            )
      ;  }
      ;  fprintf(fp, " $\n")
   ;  }

   ;  fprintf(fp, ")\n")
   ;  if (mcxVerbosityIoNonema)
      fprintf
      (  stdout
      ,  "[mclIO] Wrote native ascii %dx%d matrix to stream [%s]\n"
      ,  mx->N_rows
      ,  mx->N_cols
      ,  xfOut->fn->str
      )
   ;  return STATUS_OK
;  }


mcxstatus mcxMatrixWriteAscii
(  const mcxMatrix*        mx
,  mcxIOstream*            xfOut
,  int                     valdigits
,  mcxOnFail               ON_FAIL
)
   {  int   i
   ;  int   idxwidth    =  ((int) log10(mx->N_rows)) + 1
   ;  FILE* fp

   ;  if (!xfOut->fp)
      {  if (mcxIOstreamOpen(xfOut, RETURN_ON_FAIL) != STATUS_OK)
         {  fprintf
            (  stderr
            ,  "[mcxMatrixWriteAscii] cannot open stream [%s]\n"
            ,  xfOut->fn->str
            )
         ;  if (ON_FAIL == RETURN_ON_FAIL)
            return STATUS_FAIL
         ;  else
            exit(1)
      ;  }
   ;  }

   ;  fp =  xfOut->fp

   ;  fprintf  (  fp
               ,  "(mclheader\nmcltype matrix\ndimensions %dx%d\n)\n"
                  "(mclmatrix\nbegin\n"
               ,  mx->N_rows
               ,  mx->N_cols
               )           

   ;  for (i=0;i<mx->N_cols;i++)
      {  
         if ((mx->vectors+i)->n_ivps)
         mcxVectorDumpAscii
         (  mx->vectors+i
         ,  fp
         ,  i
         ,  idxwidth
         ,  valdigits
         ,  0
         )  ;
      }

   ;  fprintf(fp, ")\n")
   ;  if (mcxVerbosityIoNonema)
      fprintf
      (  stdout
      ,  "[mclIO] Wrote native ascii %dx%d matrix to stream [%s]\n"
      ,  mx->N_rows
      ,  mx->N_cols
      ,  xfOut->fn->str
      )
   ;  return STATUS_OK
;  }


void mcxFlowPrettyPrint
(  const mcxMatrix*        mx
,  FILE*                   fp
,  int                     digits
,  const char              msg[]
)
   {  int   i, t
   ;  char     bgl[]       =  " [ "
   ;  char     eol[]       =  "  ]"
   ;  mcxMatrix*  tp       =  mcxMatrixTranspose(mx)
   ;  char*    voidstring  =  (char*) rqAlloc
                              (  (digits+1)*sizeof(char)
                              ,  EXIT_ON_FAIL
                              )

   ;  memset(voidstring, ' ', digits)
   ;  *(voidstring+digits) = '\0'

   ;  for (i=0;i<tp->N_cols;i++)
      {  int      last        =  0
      ;  mcxIvp*     ivpPtr      =  (tp->vectors+i)->ivps
      ;  mcxIvp*     ivpPtrMax   =  ivpPtr + (tp->vectors+i)->n_ivps

      ;  fprintf(fp, "%s", bgl)
      ;  while (ivpPtr < ivpPtrMax)

         {  for (t=last;t<ivpPtr->idx;t++) fprintf(fp, "%s-- ", voidstring)
         ;  fprintf(fp, " %*.*f", digits+2, digits, ivpPtr->val)
         ;  last = (ivpPtr++)->idx + 1
      ;  }

      ;  for (t=last;t<tp->N_rows;t++) fprintf(fp, "%s-- ", voidstring)
      ;  fprintf(fp, "%s\n", eol)
   ;  }

   ;  mcxMatrixFree(&tp)
   ;  fprintf(fp, "^ %s\n\n", msg)
;  }


void              mcxMatrixBoolPrint
(  mcxMatrix*        mx
,  int            mode
)  {  int      i, t                 
   ;  const char  *space   =  mode & 1 ? "" : " "
   ;  const char  *empty   =  mode & 1 ? " " : "  "

   ;  fprintf(stdout, "\n  ")        
   ;  for (i=0;i<mx->N_rows;i++)    
      {  fprintf(stdout, "%d%s", i % 10, space)   
   ;  }
   ;  fprintf(stdout, "\n")

   ;  for (i=0;i<mx->N_cols;i++)
      {  int      last        =  0
      ;  mcxIvp*     ivpPtr      =  (mx->vectors+i)->ivps
      ;  mcxIvp*     ivpPtrMax   =  ivpPtr + (mx->vectors+i)->n_ivps
      ;  fprintf(stdout, "%d ", i%10)
                                    
      ;  while (ivpPtr < ivpPtrMax) 

         {  for (t=last;t<ivpPtr->idx;t++) fprintf(stdout, "%s", empty)
         ;  fprintf(stdout, "@%s", space)
         ;  last = (ivpPtr++)->idx + 1
      ;  }        

      ;  for (t=last;t<mx->N_rows;t++) fprintf(stdout, "%s", empty)
      ;  fprintf(stdout, " %d\n", i%10)   
   ;  }           
   ;  fprintf(stdout, "  ")
   ;  for (i=0;i<mx->N_rows;i++)
      {  fprintf(stdout, "%d%s", i % 10, space)
   ;  }
   ;  fprintf(stdout, "\n")
;  }


void  mcxVectorList
(  mcxVector*        vec
,  FILE*          fp
,  int            lo
,  int            hi
,  int            width
,  int            digits
,  const char*    pre
,  const char*    msg
)  {  mcxIvp*        ivpPtr      =  vec->ivps
   ;  mcxIvp*        ivpPtrMax   =  vec->ivps + vec->n_ivps

   ;  while (ivpPtr < ivpPtrMax)
      {  if (ivpPtr->idx < lo)
         {  ivpPtr++
         ;  continue
      ;  }
         else if (ivpPtr->idx >= hi)
            break

      ;  fprintf
         (  fp, "%s%-10d  %*.*f\n"
         ,   pre
         ,   ivpPtr->idx
         ,   width
         ,   digits
         ,   (ivpPtr)->val
         )
      ;  ivpPtr++
   ;  }
;  }


void mcxVectorDumpAscii
(  const mcxVector*        vec
,  FILE*                   fp
,  int                     idfidx         /* identifies vector */
,  int                     idxwidth
,  int                     valdigits
,  int                     doHeader
)  {  int i
   ;  int nr_chars   =     0
   ;  int fieldwidth =     idxwidth+1
   ;  const char* eov =    "$\n"
                                          /* works for 0.xxx 1.xxx .. */
   ;  if (valdigits >= 0)
      fieldwidth += valdigits + 3

   ;  if (!vec)
      mcxVectorAlert("mcxVectorDumpAscii")

   ;  if (doHeader)
      {  fprintf(fp , "(mclheader\nmcltype vector\n)\n" "(mclvector\nbegin\n")
      ;  eov         =     "\n)\n"
   ;  }

   ;  if (idfidx>=0)
      {  fprintf(fp, "%-*d  ", idxwidth, idfidx)
      ;  nr_chars = idxwidth + 2
   ;  }

   ;  for (i=0; i<vec->n_ivps;i++)
      {  if (valdigits > -1)
         {  fprintf  (  fp, "%*d:%-*.*f "
                     ,  idxwidth, (vec->ivps+i)->idx
                     ,  valdigits+2, valdigits, (vec->ivps+i)->val
                     )
         ;  nr_chars += idxwidth + valdigits + 4   /* 4 chars: [01]\.\:\ */
      ;  }
         else
         {  fprintf  (  fp, "%*d "
                     ,  idxwidth, (vec->ivps+i)->idx
                     )
         ;  nr_chars += idxwidth + 1
      ;  }
      ;  if (  (  (i<vec->n_ivps-2)
               && (nr_chars + fieldwidth > 80) 
               )
            ||
               (  (i==vec->n_ivps-2)
               && (nr_chars + fieldwidth + strlen(eov) > 80)
               )
            )
         {  int j
         ;  fprintf  (fp, "\n")
                                       /* below is _very_ stupid */
         ;  for (j=0;j<idxwidth+2;j++) fprintf(fp, " ")
         ;  nr_chars =  idxwidth+2
      ;  }
   ;  }
   ;  fprintf(fp, "%s", eov)
;  }

/*
//    mcxVector I/O
*/

static void report_vector_size
(  const char*             action
,  const mcxVector*           vec
)  {  char                 report[80]

   ;  sprintf
      (  report, "%s %d pair%s"
      ,  action
      ,  vec->n_ivps
      ,  vec->n_ivps == 1 ? "" : "s"
      )
   ;  fprintf(stderr, "%s\n", report)
;  }

   /*
   // mcxVectorEmbedRead: vec argument may be NULL.
   */

mcxstatus mcxVectorEmbedRead
(  mcxVector*              vec
,  mcxIOstream*            xfIn
,  mcxOnFail               ON_FAIL
)  {  
      int                  n_ivps            =  0

   ;  n_ivps = IoReadInteger(xfIn->fp)

   ;  if
      (  n_ivps
      && mcxVectorInstantiate(vec, n_ivps, NULL)
      )  
      {  fread(vec->ivps, sizeof(mcxIvp), n_ivps, xfIn->fp)
      ;  mcxVectorSort(vec, NULL)
      ;  mcxVectorUniqueIdx(vec)
      ;  return STATUS_OK
   ;  }
      else
      {  mcxVectorInstantiate(vec, 0, NULL)
   ;  }
   ;  return STATUS_OK
;  }


   /*
   // mcxVectorRead: vec argument may be NULL.
   */

mcxVector* mcxVectorRead
(  mcxVector*              vec
,  mcxIOstream*            xfIn
,  mcxOnFail               ON_FAIL
)  {  if (!IoExpectMagicNumber(xfIn->fp, mcxVectorMagicNumber))
      {  fprintf
         (  stderr
         ,  "[mcxVectorRead] Did not find magic number\n"
            "[mcxVectorRead] Trying to read ascii format\n"
         )
      ;  return mcxVectorReadAscii(xfIn, ON_FAIL)
   ;  }
      else
      {  mcxVector*        new_vec = mcxVectorInit(vec)
      ;  mcxVectorEmbedRead(new_vec, xfIn, ON_FAIL)
      ;  return new_vec
   ;  }
;  }


mcxVector* mcxVectorReadAscii
(  mcxIOstream*            xfIn
,  mcxOnFail               ON_FAIL
)  {  
      mcxVector*           vec            =  mcxVectorInit(NULL)
   ;  const char*          whoiam         =  "mcxVectorReadAscii"

   ;  mcxFpFindInFile(xfIn, "(mclheader", whoiam, EXIT_ON_FAIL)
   ;  mcxFpSkipSpace(xfIn, whoiam)

   ;  mcxFpParse(xfIn,  "mcltype", whoiam, EXIT_ON_FAIL)
   ;  mcxFpSkipSpace(xfIn, whoiam)
   ;  mcxFpParse(xfIn,  "vector", whoiam, EXIT_ON_FAIL)
   ;  mcxFpSkipSpace(xfIn, whoiam)

   ;  {  
         mcxBuf buf
      ;  mcxBufInit(&buf, &(vec->ivps), sizeof(mcxIvp), 30)

      ;  mcxFpFindInFile(xfIn, "(mclvector", whoiam, EXIT_ON_FAIL)
      ;  mcxFpFindInFile(xfIn, "begin", whoiam, EXIT_ON_FAIL)
      ;  for (;;)
         {  if (')' == mcxFpSkipSpace(xfIn, whoiam))  break

         ;  {  int      idx      =  (int) mcxFpParseNumber(xfIn, whoiam)
            ;  float    val      =  (':' == mcxFpSkipSpace(xfIn, whoiam))
                                 ?  (  mcxIOstreamStep(xfIn, fgetc(xfIn->fp))
                                    ,  mcxFpParseNumber(xfIn, whoiam)
                                    )
                                 :  1.0
            ;  mcxIvp*  ivp      =  (mcxIvp*) mcxBufExtend(&buf, 1)
            ;  ivp->val          =  val
            ;  ivp->idx          =  idx
         ;  }
      ;  }


      ;  vec->n_ivps    =    mcxBufFinalize(&buf)

      ;  mcxVectorSort(vec, NULL)
      ;  mcxVectorUniqueIdx(vec)
   ;  }
   ;  return vec
;  }


mcxstatus mcxVectorEmbedWrite
(  const mcxVector*        vec
,  mcxIOstream*            xfOut
)  {  
      if (!vec)
      {  mcxVectorAlert("mcxVectorEmbedWrite")
      ;  exit(1)
   ;  }

   ;  IoWriteInteger(xfOut->fp, vec->n_ivps)
   ;  if (vec->n_ivps)
      fwrite(vec->ivps, sizeof(mcxIvp), vec->n_ivps, xfOut->fp)

   ;  return STATUS_OK
;  }


mcxstatus mcxVectorWrite
(  const mcxVector*        vec
,  mcxIOstream*            xfOut
,  mcxOnFail               ON_FAIL
)  {  
      mcxstatus            status

   ;  if (!vec)
      {  mcxVectorAlert("mcxVectorWrite")
      ;  exit(1)
   ;  }

   ;  if (xfOut->fp == NULL)
      {  if ((mcxIOstreamOpen(xfOut, ON_FAIL) != STATUS_OK))
         {  fprintf
            (  stderr
            ,  "[mcxVectorWrite] cannot open stream [%s]\n"
            ,  xfOut->fn->str
            )
         ;  if (ON_FAIL == RETURN_ON_FAIL)
            return STATUS_FAIL
         ;  else
            exit(1)
      ;  }
   ;  }

   ;  IoWriteMagicNumber(xfOut->fp, mcxVectorMagicNumber)
   ;  status = mcxVectorEmbedWrite(vec, xfOut)
   ;  if (status == STATUS_OK)
      report_vector_size("wrote", vec)

   ;  return status
;  }


mcxstatus mcxParseHeaderLines
(  mcxIOstream             *xfIn
,  mcxTable                *txtTable
)  {
      int      i, n
   ;  mcxTxt   *keyTxt  =  (mcxTxt*) mcxTxtInit(NULL)
   ;  mcxTxt   *valTxt  =  (mcxTxt*) mcxTxtInit(NULL)
   ;  mcxTxt   *lineTxt =  (mcxTxt*) mcxTxtInit(NULL)

   ;  for(i=0;i<txtTable->n;i++)
      {  
         mcxArray   *KEYlist  =  txtTable->ls+i

      ;  if (!((mcxTxt*) KEYlist->ls+0)->str)
         {  fprintf
            (  stderr
            ,  "[mcxParseHeaderLines fatal] key at index [%d] nonexistent\n"
            ,  i
            )
         ;  exit(1)
      ;  }
         if (KEYlist->n < 2)
         {  fprintf
            (  stderr
            ,  "[mcxParseHeaderLines fatal] not enough storage for key [%s]\n"
            ,  ((mcxTxt*) KEYlist->ls+0)->str
            )
         ;  exit(1)
      ;  }
   ;  }

   ;  while (!xfIn->ateof)
      {  
         mcxIOstreamReadLine(xfIn, lineTxt, READLINE_CHOMP)

      ;  if (*(lineTxt->str+0) == ')')
         break

      ;  mcxTxtEnsure(keyTxt, lineTxt->len)
      ;  mcxTxtEnsure(valTxt, lineTxt->len)

      ;  n  = sscanf(lineTxt->str, "%s%s", keyTxt->str, valTxt->str)

      ;  if (n < 2)
         continue
      ;  else
         {  keyTxt->len =  strlen(keyTxt->str)
         ;  valTxt->len =  strlen(valTxt->str)
      ;  }

      ;  for(i=0;i<txtTable->n;i++)
         {  
            mcxArray    *KEYlist =  txtTable->ls+i
         ;  mcxTxt      *KEYtxt  =  (mcxTxt*) KEYlist->ls+0

         ;  if (!strcmp(KEYtxt->str, keyTxt->str))
            {  
               if (((mcxTxt*) KEYlist->ls+1)->len)
               {  fprintf
                  (  stderr
                  ,  "[mcxParseHeaderLines warning] overwriting value [%s]"
                     " for key [%s]\n"
                     "[mcxParseHeaderLines warning] new value is [%s]\n"
                  ,  ((mcxTxt*) KEYlist->ls+1)->str
                  ,  ((mcxTxt*) KEYlist->ls+0)->str
                  ,  valTxt->str
                  )
            ;  }
            ;  mcxTxtWrite((mcxTxt*) KEYlist->ls+1, valTxt->str)
         ;  }
      ;  }

   ;  }

   ;  mcxTxtFree(&lineTxt)
   ;  mcxTxtFree(&valTxt)
   ;  mcxTxtFree(&keyTxt)
   ;  return STATUS_OK
;  }


