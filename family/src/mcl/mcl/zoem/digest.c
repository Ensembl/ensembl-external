/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "digest.h"
#include "filter.h"
#include "parse.h"
#include "iface.h"
#include "util.h"

#include "util/txt.h"

/*
 *    creates successively new segs, and these segs
 *    and their content will be freed. The input txt is left
 *    alone however, and is responsibility of caller.
*/

void yamOutput
(  mcxTing     *txtin
,  int         filter(yamFilterData* fd, mcxTing* txt, int offset, int length)
,  yamFilterData*   fd
)
   {  yamSeg   *seg
   ;  int      offset

   ;  if (!txtin)
      yamExit("yamOutput", "[yamOutput PBD] void argument")

   ;  seg                  =  yamSegPush(NULL, txtin)

               /* todo: the fd->fp in dofilter should not be necessary (?) */
   ;  while(seg)
      {
         int  prev_offset  =  seg->offset
      ;  yamSeg* prev_seg  =  seg
      ;  mcxbool dofilter  =  filter && fd && fd->fp
      
      ;  int offset        =  findkey(seg)
      ;  mcxbool done      =  offset < 0
      ;  int len

      ;  if (done)
         offset = seg->txt->len
      
      ;  len = offset - prev_offset

      ;  if (tracing_g & ZOEM_TRACE_OUTPUT)
         fprintf
         (  stdout
         ,  "\n________>"
            " %s seg %d stack %d offset %d len %d txt len %d%s"
         ,  dofilter ? "filtering" : "skipping"
         ,  seg->idx
         ,  yamStackIdx()
         ,  prev_offset
         ,  len
         ,  seg->txt->len
         ,  dofilter && len ? "\n[>]" : "\n"
         )

      ;  if (len && dofilter)
         filter(fd, seg->txt, prev_offset, len)

      ;  if (tracing_g & ZOEM_TRACE_OUTPUT)
         fprintf
         (  stdout
         ,  "%s<~~~~~~~~ output %s seg %d and stack %d\n\n"
         ,  dofilter && len ? "\n" : ""
         ,  done ? "finished" : "continuing"
         ,  seg->idx
         ,  yamStackIdx()
         )

      ;  if (done)
         {  seg  =  seg->prev
         ;  yamSegFree(&prev_seg)
      ;  }
         else
         seg  =  dokey(seg)
   ;  }
   }


mcxTing*  yamDigest
(  mcxTing      *txtin
,  mcxTing      *txtout
)
   {  yamSeg      *seg
   ;  int         offset

   ;  mcxTing*     txt     = (txtin == txtout) ? NULL : txtout

   ;  if (!txtin)
      yamExit("yamDigest", "[yamDigest PBD] void argument")

   ;  if (txtin == txtout && !strchr(txtin->str, '\\'))
      return txtin

   ;  txt                  =  mcxTingEmpty(txt, 30)

   ;  seg                  =  yamSegPush(NULL, txtin)
   ;  offset               =  seg->offset

   ;  while(seg)
      {
         int prev_offset   =  seg->offset
      ;  yamSeg* prev_seg  =  seg

      ;  int offset        =  findkey(seg)
      ;  mcxbool done      =  offset < 0
      ;  int len

      ;  if (done)
         offset = seg->txt->len

      ;  len = offset - prev_offset

      ;  if (tracing_g & ZOEM_TRACE_OUTPUT)
         fprintf
         (  stdout
         ,  "\n________> "
            "appending seg %d stack %d offset %d length %d text length %d\n"
            "%s"
         ,  seg->idx
         ,  yamStackIdx()
         ,  prev_offset
         ,  len
         ,  seg->txt->len
         ,  len ? "[>]" : ""
         )

      ;  if (len)
         mcxTingNAppend
         (  txt
         ,  seg->txt->str+prev_offset
         ,  len
         )

      ;  if (tracing_g & ZOEM_TRACE_OUTPUT)
         {  if (len)
            traceputlines(seg->txt->str+prev_offset, len)
         ;  fprintf
            (  stdout
            ,  "%s<~~~~~~~~ digest %s seg %d and stack %d\n\n"
            ,  len ? "\n" : ""
            ,  done ? "finished" : "continuing"
            ,  seg->idx
            ,  yamStackIdx()
            )
      ;  }

         if (done)
         {  seg  =  seg->prev
         ;  yamSegFree(&prev_seg)
      ;  }
         else
         seg = dokey(seg)
   ;  }

      if (txtout == txtin)
      {  mcxTingWrite(txtin, txt->str)
      ;  mcxTingFree(&txt)
      ;  return txtin
   ;  }

   ;  return txt
;  }

