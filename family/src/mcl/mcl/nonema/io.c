/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "io.h"
#include "iface.h"

#include "util/compile.h"
#include "util/parse.h"
#include "util/types.h"
#include "util/file.h"
#include "util/hash.h"
#include "util/txt.h"
#include "util/buf.h"
#include "util/alloc.h"


mcxstatus mclParseHeader
(  mcxIOstream      *xfIn
,  mcxHash          *header
)  ;


mcxstatus  mclMatrixReadAsciiHeader
(  mcxIOstream*            xfIn
,  int                     *pN_rows
,  int                     *pN_cols
)  ;


mcxstatus  mclMatrixFilePeek
(  mcxIOstream*            xfIn
,  int                     *pN_cols
,  int                     *pN_rows
,  mcxOnFail               ON_FAIL
)
   {  int   f_pos

   ;  if (!xfIn->fp && mcxIOstreamOpen(xfIn, ON_FAIL) != STATUS_OK)
      return STATUS_FAIL

   ;  f_pos          =     ftell(xfIn->fp)

   ;  if
      (  xfIn->fp != stdin
      && IoExpectMagicNumber(xfIn->fp, mclMatrixMagicNumber)
      )
      {  fread(pN_cols, sizeof(int), 1, xfIn->fp)
      ;  fread(pN_rows, sizeof(int), 1, xfIn->fp)
   ;  }
      else if (mclMatrixReadAsciiHeader(xfIn, pN_rows, pN_cols) != STATUS_OK)
      {  
         fprintf
         (  stderr
         ,  "[mclMatrixFilePeek] could not parse header\n"
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


mclMatrix* mclMatrixMaskedRead
(  mcxIOstream*            xfIn
,  const mclVector*        selector
,  mcxOnFail               ON_FAIL
)
   {  mclMatrix*           mx          =  NULL
   ;  int                  N_rows      =  0
   ;  int                  N_cols      =  0

   ;  mclMatrixFormatFound             =  'b'

   ;  if (!xfIn->fp && mcxIOstreamOpen(xfIn, ON_FAIL) != STATUS_OK)
      {  mcxIOstreamErr(xfIn, "mclMatrixMaskedRead", "can not be opened", NULL)
      ;  return NULL
   ;  }

   ;  if
      (  xfIn->fp != stdin
      && IoExpectMagicNumber(xfIn->fp, mclMatrixMagicNumber)
      )
      {
         mclVector         *vec
      ;  int               n_ivps      =  selector ? selector->n_ivps : 0
      
      ;  fread(&N_cols, sizeof(int), 1, xfIn->fp)
      ;  fread(&N_rows, sizeof(int), 1, xfIn->fp)

      ;  mx                            =  mclMatrixAllocZero(N_cols, N_rows)
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
            ;  mclVectorEmbedRead(vec + vec_idx, xfIn, EXIT_ON_FAIL)
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
            mclVectorEmbedRead(vec++, xfIn, EXIT_ON_FAIL)
      ;  }
      
      ;  if (mclVerbosityIoNonema)
         fprintf
         (  stdout
         ,  "[mclIO] Read native binary %dx%d matrix from stream [%s]\n"
         ,  mx->N_rows
         ,  mx->N_cols
         ,  xfIn->fn->str
         )
   ;  }
      else
      {  mx                         =  mclMatrixReadAscii(xfIn, ON_FAIL)
      ;  mclMatrixFormatFound       =  'a'
   ;  }
   ;  return mx
;  }


mcxstatus mclMatrixWrite
(  const mclMatrix*        mx
,  mcxIOstream*            xfOut
,  mcxOnFail               ON_FAIL
)
   {  int                  N_cols   =  mx->N_cols
   ;  mclVector*           vec      =  mx->vectors
   ;  mcxstatus            status   =  0
   ;  int                  v_pos    =  0
   ;  FILE*                fout     =  xfOut->fp

   ;  if (xfOut->fp == NULL)
      {  if ((mcxIOstreamOpen(xfOut, ON_FAIL) != STATUS_OK))
         {  fprintf
            (  stderr
            ,  "[mclMatrixWrite] cannot open stream [%s]\n"
            ,  xfOut->fn->str
            )
         ;  if (ON_FAIL == RETURN_ON_FAIL)
            return STATUS_FAIL
         ;  else
            exit(1)
      ;  }
   ;  }

   ;  IoWriteMagicNumber(fout, mclMatrixMagicNumber)
   
   ;  fwrite(&N_cols, sizeof(int), 1, fout)
   ;  fwrite(&mx->N_rows, sizeof(int), 1, fout)

      /*
      // Write vector offsets (plus one for end of matrix body)
      //
      */
   ;  v_pos = ftell(fout) + (1 + N_cols) * sizeof(int)
   ;  while (--N_cols >= 0)
      {  IoWriteInteger(fout, v_pos)
      ;  v_pos += sizeof(int) + vec->n_ivps * sizeof(mclIvp)
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
      {  status = mclVectorEmbedWrite(vec, xfOut)
      ;  if (status == STATUS_FAIL) break
      ;  vec++
   ;  }
   
   ;  if (mclVerbosityIoNonema)
      fprintf
      (  stdout
      ,  "[mclIO] Wrote native binary %dx%d matrix to stream [%s]\n"
      ,  mx->N_rows
      ,  mx->N_cols
      ,  xfOut->fn->str
      )
   ;  return status
;  }


mcxstatus  mclMatrixReadAsciiHeader
(  mcxIOstream*         xfIn
,  int                  *pN_rows
,  int                  *pN_cols
)
   {  mcxHash* header      =  mcxHashNew(4, mcxTingHash, mcxTingCmp)
   ;  mcxTing* txtmx       =  mcxTingNew("mcltype")
   ;  mcxTing* txtdim      =  mcxTingNew("dimensions")
   ;  mcxKV    *kvtp, *kvdim

   ;  if
      (  mcxFpFindInFile
         (  xfIn
         ,  "(mclheader"
         ,  "mclMatrixReadAsciiHeader"
         ,  RETURN_ON_FAIL
         )
      != STATUS_OK
      )
      {  mcxHashFree(&header, NULL, NULL)
      ;  return STATUS_FAIL
   ;  }

   ;  mclParseHeader(xfIn, header)  /* hierverder: mph must insert kv's */

   ;  kvtp  =  mcxHashSearch(txtmx, header, MCX_DATUM_FIND)
   ;  kvdim =  mcxHashSearch(txtdim, header, MCX_DATUM_FIND)

   ;  if (!kvtp)
      {  fprintf
         (  stderr
         ,  "[mclMatrixReadAsciiHeader] expected `mcltype matrix'"
            " specification not found\n"
         )
      ;  mcxIOstreamReport(xfIn, stderr)
      ;  mcxHashFree(&header, mcxTingFree_v, mcxTingFree_v)
      ;  return STATUS_FAIL
   ;  }

      if (  !kvdim
         || (sscanf(((mcxTing*) kvdim->val)->str,"%dx%d",pN_rows, pN_cols) < 2)
         )
      {  fprintf
         (  stderr
         ,  "[mclMatrixReadAsciiHeader] expected `dimensions MxN'"
            " specification not found\n"
         )
      ;  mcxIOstreamReport(xfIn, stderr)
      ;  mcxHashFree(&header, mcxTingFree_v, mcxTingFree_v)
      ;  return STATUS_FAIL
   ;  }

   ;  if (*pN_rows <= 0 || *pN_cols <= 0)
      {  fprintf
         (  stderr
         ,  "[mclMatrixReadAsciiHeader] each dimension must be positive"
            " (found %dx%d pair)\n"
         ,  *pN_rows
         ,  *pN_cols
         )
      ;  return STATUS_FAIL
   ;  }
   ;  return STATUS_OK
;  }


mclMatrix* mclMatrixReadAscii
(  mcxIOstream*            xfIn
,  mcxOnFail               ON_FAIL
)
   {  mclMatrix*           mx             =  NULL
   ;  int                  N_rows         =  0
   ;  int                  N_cols         =  0
   ;  const char*          whoiam         =  "mclMatrixReadAscii"

   ;  if (xfIn->fp == NULL && (mcxIOstreamOpen(xfIn, ON_FAIL) != STATUS_OK))
      {  fprintf
         (  stderr
         ,  "[mclMatrixReadAscii] cannot open stream [%s]\n"
         ,  xfIn->fn->str
         )
         ;  if (ON_FAIL == RETURN_ON_FAIL)
            return NULL
         ;  else
            exit(1)
   ;  }


   ;  if (mclMatrixReadAsciiHeader(xfIn, &N_rows, &N_cols) != STATUS_OK)
      {  fprintf
         (  stderr
         ,  "[mclMatrixReadAscii] could not successfully parse header\n"
         )
      ;  if (ON_FAIL == RETURN_ON_FAIL)
         return NULL
      ;  else
         exit(1)
   ;  }

   ;  mx = mclMatrixAllocZero(N_cols, N_rows)

   ;  {  
         mcxBuf            buf

      ;  mcxFpFindInFile(xfIn, "(mclmatrix", whoiam, EXIT_ON_FAIL)
      ;  mcxFpFindInFile(xfIn, "begin", whoiam, EXIT_ON_FAIL)

      ;  for (;;)
         {  
            int            cidx
         ;  mclVector*     vec

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
            ;  mclMatrixFree(&mx)
            ;  exit(1)
         ;  }

         ;  vec = mx->vectors + cidx
         ;  mcxBufInit(&buf,  &(vec->ivps), sizeof(mclIvp), 30)

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

               ;  mclIvp*  ivp      =  (mclIvp*) mcxBufExtend(&buf, 1)

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
                  ;  mclMatrixFree(&mx)
                  ;  exit(1)
               ;  }
            ;  }
         ;  }

         ;  vec->n_ivps    =  mcxBufFinalize(&buf)

         ;  mclVectorSort(vec, NULL)
         ;  mclVectorUniqueIdx(vec)
      ;  }
   ;  }

   ;  if (mclVerbosityIoNonema)
      fprintf
      (  stdout
      ,  "[mclIO] Read native ascii %dx%d matrix from stream [%s]\n"
      ,  mx->N_rows
      ,  mx->N_cols
      ,  xfIn->fn->str
      )

   ;  return mx
;  }


void  mclMatrixList
(  mclMatrix*     mx
,  FILE*          fp
,  int            x_lo
,  int            x_hi
,  int            y_lo
,  int            y_hi
,  int            width
,  int            digits
,  const char*    msg
)
   {  int   i

   ;  if (x_lo<0) x_lo = 0
   ;  if (y_lo<0) y_lo = 0

   ;  if (x_hi>mx->N_cols || x_hi == 0)
         x_hi = mx->N_cols

   ;  if (y_hi>mx->N_rows || y_hi == 0)
         y_hi = mx->N_rows

   ;  for (i=x_lo;i<x_hi;i++)
      {  fprintf(fp, "vec %d, %d ivps\n", i, (mx->vectors+i)->n_ivps)
      ;  mclVectorList  
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


mcxstatus mclMatrixTaggedWrite
(  const mclMatrix*        mx
,  const mclVector*        vecTags
,  mcxIOstream*            xfOut
,  int                     valdigits
,  mcxOnFail               ON_FAIL
)
   {  int   i
   ;  FILE* fp

   ;  if ((mx->N_cols != mx->N_rows) || (mx->N_cols != vecTags->n_ivps))
      {  fprintf
         (  stderr
         ,  "[mclMatrixTaggedWrite] dimensions not right\n"
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
            ,  "[mclMatrixTaggedWrite] cannot open stream [%s]\n"
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
         mclVector*  tvec  =  mx->vectors+i
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
   ;  if (mclVerbosityIoNonema)
      fprintf
      (  stdout
      ,  "[mclIO] Wrote native ascii %dx%d matrix to stream [%s]\n"
      ,  mx->N_rows
      ,  mx->N_cols
      ,  xfOut->fn->str
      )
   ;  return STATUS_OK
;  }


mcxstatus mclMatrixWriteAscii
(  const mclMatrix*        mx
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
            ,  "[mclMatrixWriteAscii] cannot open stream [%s]\n"
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
         mclVectorDumpAscii
         (  mx->vectors+i
         ,  fp
         ,  i
         ,  idxwidth
         ,  valdigits
         ,  0
         )  ;
      }

   ;  fprintf(fp, ")\n")
   ;  if (mclVerbosityIoNonema)
      fprintf
      (  stdout
      ,  "[mclIO] Wrote native ascii %dx%d matrix to stream [%s]\n"
      ,  mx->N_rows
      ,  mx->N_cols
      ,  xfOut->fn->str
      )
   ;  return STATUS_OK
;  }


void mcxPrettyPrint
(  const mclMatrix*        mx
,  FILE*                   fp
,  int                     width
,  int                     digits
,  const char              msg[]
)
   {  int   i, t
   ;  char     bgl[]       =  " [ "
   ;  char     eol[]       =  "  ]"
   ;  mclMatrix*  tp       =  mclMatrixTranspose(mx)
   ;  char  voidstring[20]

   ;  width                =  MAX(2, width)
   ;  width                =  MIN(width, 15)

   ;  memset(voidstring, ' ', width-2)
   ;  *(voidstring+width-2) = '\0'

   ;  for (i=0;i<tp->N_cols;i++)
      {  int      last        =  0
      ;  mclIvp*     ivpPtr      =  (tp->vectors+i)->ivps
      ;  mclIvp*     ivpPtrMax   =  ivpPtr + (tp->vectors+i)->n_ivps

      ;  fprintf(fp, "%s", bgl)
      ;  while (ivpPtr < ivpPtrMax)

         {  for (t=last;t<ivpPtr->idx;t++)
            fprintf(fp, " %s--", voidstring)

         ;  fprintf(fp, " %*.*f", width, digits, ivpPtr->val)

         ;  last = (ivpPtr++)->idx + 1
      ;  }

      ;  for (t=last;t<tp->N_rows;t++)
         fprintf(fp, " %s--", voidstring)

      ;  fprintf(fp, "%s\n", eol)
   ;  }

   ;  mclMatrixFree(&tp)
   ;  if (msg)
      fprintf(fp, "^ %s\n", msg)
;  }


void mclMatrixBoolPrint
(  mclMatrix*     mx
,  int            mode
)
   {  int      i, t                 
   ;  const char  *space   =  mode & 1 ? "" : " "
   ;  const char  *empty   =  mode & 1 ? " " : "  "

   ;  fprintf(stdout, "\n  ")        
   ;  for (i=0;i<mx->N_rows;i++)    
      {  fprintf(stdout, "%d%s", i % 10, space)   
   ;  }
   ;  fprintf(stdout, "\n")

   ;  for (i=0;i<mx->N_cols;i++)
      {  int      last        =  0
      ;  mclIvp*     ivpPtr      =  (mx->vectors+i)->ivps
      ;  mclIvp*     ivpPtrMax   =  ivpPtr + (mx->vectors+i)->n_ivps
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


void  mclVectorList
(  mclVector*        vec
,  FILE*          fp
,  int            lo
,  int            hi
,  int            width
,  int            digits
,  const char*    pre
,  const char*    msg
)
   {  mclIvp*        ivpPtr      =  vec->ivps
   ;  mclIvp*        ivpPtrMax   =  vec->ivps + vec->n_ivps

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


void mclVectorDumpAscii
(  const mclVector*        vec
,  FILE*                   fp
,  int                     idfidx         /* identifies vector */
,  int                     idxwidth
,  int                     valdigits
,  int                     doHeader
)
   {  int i
   ;  int nr_chars   =     0
   ;  int fieldwidth =     idxwidth+1
   ;  const char* eov =    "$\n"
                                          /* works for 0.xxx 1.xxx .. */
   ;  if (valdigits >= 0)
      fieldwidth += valdigits + 3

   ;  if (!vec)
      mclVectorAlert("mclVectorDumpAscii")

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


static void report_vector_size
(  const char*             action
,  const mclVector*           vec
)
   {  char                 report[80]

   ;  sprintf
      (  report, "%s %d pair%s"
      ,  action
      ,  vec->n_ivps
      ,  vec->n_ivps == 1 ? "" : "s"
      )
   ;  fprintf(stderr, "%s\n", report)
;  }


mcxstatus mclVectorEmbedRead
(  mclVector*              vec
,  mcxIOstream*            xfIn
,  mcxOnFail               ON_FAIL
)
   {  int                  n_ivps            =  0

   ;  n_ivps = IoReadInteger(xfIn->fp)

   ;  if
      (  n_ivps
      && mclVectorInstantiate(vec, n_ivps, NULL)
      )  
      {  fread(vec->ivps, sizeof(mclIvp), n_ivps, xfIn->fp)
      ;  mclVectorSort(vec, NULL)
      ;  mclVectorUniqueIdx(vec)
      ;  return STATUS_OK
   ;  }
      else
      {  mclVectorInstantiate(vec, 0, NULL)
   ;  }
   ;  return STATUS_OK
;  }


mclVector* mclVectorRead
(  mclVector*              vec
,  mcxIOstream*            xfIn
,  mcxOnFail               ON_FAIL
)
   {  if (!IoExpectMagicNumber(xfIn->fp, mclVectorMagicNumber))
      {  fprintf
         (  stderr
         ,  "[mclVectorRead] Did not find magic number\n"
            "[mclVectorRead] Trying to read ascii format\n"
         )
      ;  return mclVectorReadAscii(xfIn, ON_FAIL)
   ;  }
      else
      {  mclVector*        new_vec = mclVectorInit(vec)
      ;  mclVectorEmbedRead(new_vec, xfIn, ON_FAIL)
      ;  return new_vec
   ;  }
;  }


mclVector* mclVectorReadAscii
(  mcxIOstream*            xfIn
,  mcxOnFail               ON_FAIL
)
   {  mclVector*           vec            =  mclVectorInit(NULL)
   ;  const char*          whoiam         =  "mclVectorReadAscii"

   ;  mcxFpFindInFile(xfIn, "(mclheader", whoiam, EXIT_ON_FAIL)
   ;  mcxFpSkipSpace(xfIn, whoiam)

   ;  mcxFpParse(xfIn,  "mcltype", whoiam, EXIT_ON_FAIL)
   ;  mcxFpSkipSpace(xfIn, whoiam)
   ;  mcxFpParse(xfIn,  "vector", whoiam, EXIT_ON_FAIL)
   ;  mcxFpSkipSpace(xfIn, whoiam)

   ;  {  
         mcxBuf buf
      ;  mcxBufInit(&buf, &(vec->ivps), sizeof(mclIvp), 30)

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
            ;  mclIvp*  ivp      =  (mclIvp*) mcxBufExtend(&buf, 1)
            ;  ivp->val          =  val
            ;  ivp->idx          =  idx
         ;  }
      ;  }


      ;  vec->n_ivps    =    mcxBufFinalize(&buf)

      ;  mclVectorSort(vec, NULL)
      ;  mclVectorUniqueIdx(vec)
   ;  }
   ;  return vec
;  }


mcxstatus mclVectorEmbedWrite
(  const mclVector*        vec
,  mcxIOstream*            xfOut
)
   {  if (!vec)
      {  mclVectorAlert("mclVectorEmbedWrite")
      ;  exit(1)
   ;  }

   ;  IoWriteInteger(xfOut->fp, vec->n_ivps)
   ;  if (vec->n_ivps)
      fwrite(vec->ivps, sizeof(mclIvp), vec->n_ivps, xfOut->fp)

   ;  return STATUS_OK
;  }


mcxstatus mclVectorWrite
(  const mclVector*        vec
,  mcxIOstream*            xfOut
,  mcxOnFail               ON_FAIL
)
   {  mcxstatus            status

   ;  if (!vec)
      {  mclVectorAlert("mclVectorWrite")
      ;  exit(1)
   ;  }

   ;  if (xfOut->fp == NULL)
      {  if ((mcxIOstreamOpen(xfOut, ON_FAIL) != STATUS_OK))
         {  fprintf
            (  stderr
            ,  "[mclVectorWrite] cannot open stream [%s]\n"
            ,  xfOut->fn->str
            )
         ;  if (ON_FAIL == RETURN_ON_FAIL)
            return STATUS_FAIL
         ;  else
            exit(1)
      ;  }
   ;  }

   ;  IoWriteMagicNumber(xfOut->fp, mclVectorMagicNumber)
   ;  status = mclVectorEmbedWrite(vec, xfOut)
   ;  if (status == STATUS_OK)
      report_vector_size("wrote", vec)

   ;  return status
;  }


mcxstatus mclParseHeader
(  mcxIOstream             *xfIn
,  mcxHash                 *header
)
   {  int  i, n
   ;  mcxTing   *keyTxt  =  (mcxTing*) mcxTingInit(NULL)
   ;  mcxTing   *valTxt  =  (mcxTing*) mcxTingInit(NULL)
   ;  mcxTing   *lineTxt =  (mcxTing*) mcxTingInit(NULL)

   ;  while (!xfIn->ateof)
      {  
         mcxIOstreamReadLine(xfIn, lineTxt, MCX_READLINE_CHOMP)

      ;  if (*(lineTxt->str+0) == ')')
         break

      ;  mcxTingEnsure(keyTxt, lineTxt->len)
      ;  mcxTingEnsure(valTxt, lineTxt->len)

      ;  n  = sscanf(lineTxt->str, "%s%s", keyTxt->str, valTxt->str)

      ;  if (n < 2)
         continue
      ;  else
         {  mcxTing* key   =  mcxTingNew(keyTxt->str)
         ;  mcxTing* val   =  mcxTingNew(valTxt->str)
         ;  mcxKV*   kv    =  mcxHashSearch(key, header, MCX_DATUM_INSERT)
         ;  kv->val        =  val
      ;  }
   ;  }

   ;  mcxTingFree(&lineTxt)
   ;  mcxTingFree(&valTxt)
   ;  mcxTingFree(&keyTxt)
   ;  return STATUS_OK
;  }



my_inline mclMatrix* mclMatrixRead
(  mcxIOstream*      xfIn
,  mcxOnFail         ON_FAIL
)  
   {  return mclMatrixMaskedRead(xfIn, NULL, ON_FAIL)
;  }


my_inline void mclFlowPrettyPrint
(  const mclMatrix*  mx
,  FILE*             fp
,  int               digits
,  const char        msg[]
)
   {  mcxPrettyPrint
      (  mx
      ,  fp
      ,  digits+2
      ,  digits
      ,  msg
      )
;  }


my_inline void mclVectorWriteAscii
(  const mclVector*  vec
,  FILE*             fp
,  int               valdigits
)  
   {  mclVectorDumpAscii
      (  vec
      ,  fp
      ,  -1
      ,  1
      ,  valdigits
      ,  1
      )
;  }

