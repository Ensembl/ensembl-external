/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdio.h>

#include "equate.h"
#include "checkbounds.h"


int checkBoundsUsage
(  const char*    type
,  void*          var
,  int            (*lftRlt) (const void*, const void*)
,  void*          lftBound
,  int            (*rgtRlt) (const void*, const void*)
,  void*          rgtBound
)  ;


int (*rltFunctions[8])(const void* f1, const void* f2) =  
{  intGt  ,  intGq  ,  fltGt,  fltGq
,  intLt  ,  intLq  ,  fltLt,  fltLq
}  ;


static const char* blame         =  "Checkbound exception, "
                                    "programmer's stupdity";


int checkBoundsPrintDigits       =  5;
char* flagCheckBoundsCaller      =  (char *) "mcl";


const char* rltSigns[8] =
{  "(",  "[",  "(",  "["
,  ")",  "]",  ")",  "]"
}  ;


/*    returns
 *    0  for matching bounds
 *    1  for non-matching bounds
*/

int checkBounds
(  const char*    type
,  void*          var
,  int            (*lftRlt) (const void*, const void*)
,  void*          lftBound
,  int            (*rgtRlt) (const void*, const void*)
,  void*          rgtBound
)
   {  int lftOk, rgtOk
   ;  if (checkBoundsUsage(type, var, lftRlt, lftBound, rgtRlt, rgtBound))
      {  fprintf (stderr, "[mcl Considering this fatal]\n")
      ;  exit(1)
   ;  }
      lftOk =   !lftRlt || lftRlt(var, lftBound)
   ;  rgtOk =   !rgtRlt || rgtRlt(var, rgtBound)
   ;  return (lftOk && rgtOk) ? 0 : 1
;  }


/* todo: NULL lftbound argument & non-NULL lftRelate argument */
/* idem for rgt */

int checkBoundsUsage
(  const char*    type
,  void*          var
,  int            (*lftRlt) (const void*, const void*)
,  void*          lftBound
,  int            (*rgtRlt) (const void*, const void*)
,  void*          rgtBound
)
   {  int  i

   ;  if (!strcmp(type, "float"))
   ;  else if (!strcmp(type, "integer"))
   ;  else
      {  fprintf
         (  stderr, "[%s] unsupported checkbound type `%s'\n"
         ,  blame, type
         )
      ;  return 1
   ;  }

      if ((lftRlt && !lftBound)||(!lftRlt && lftBound))
      {  fprintf
         (  stderr
         ,  "[%s] abusive lftRlt lftBound combination\n"
         ,  blame
         )
      ;  return 1
   ;  }
      if ((rgtRlt && !rgtBound)||(!rgtRlt && rgtBound))
      {  fprintf
         (  stderr
         ,  "[%s] abusive rgtRlt rgtBound combination\n"
         ,  blame
         )
      ;  return 1
   ;  }

      if (lftRlt)
      {  for(i=0;i<4;i++) if (lftRlt == rltFunctions[i]) break
      ;  if (i == 4)
         {  fprintf
            (  stderr
            ,  "[%s] lftRlt should use gt or gq arg\n"
            ,  blame
            )
         ;  return 1
      ;  }
   ;  }

      if (rgtRlt)
      {  for(i=4;i<8;i++) if (rgtRlt == rltFunctions[i]) break
      ;  if (i==8)
         {  fprintf
            (  stderr
            ,  "[%s] rgtRlt should use lt or lq arg\n"
            ,  blame
            )
         ;  return 1
      ;  }
   ;  }
      return 0
;  }


mcxTing* checkBoundsRange
(  const char*    type
,  void*          var
,  int            (*lftRlt) (const void*, const void*)
,  void*          lftBound
,  int            (*rgtRlt) (const void*, const void*)
,  void*          rgtBound
)
   {  mcxTing*  textRange   =  mcxTingEnsure(NULL, 40)
   ;  char* lftToken       =  (char *) "<?"
   ;  char* rgtToken       =  (char *) "?>"
   ;  int i

   ;  if (lftRlt)
      {  for(i=0;i<4;i++)
            if (lftRlt == rltFunctions[i])
               break
      ;  if (i<4)
            lftToken = (char *) rltSigns[i]
   ;  }
      else
      {  lftToken = (char *) "("
   ;  }

   ;  textRange->len += sprintf( textRange->str+textRange->len, "%s", lftToken )

   ;  if (lftBound)
      {  if (!strcmp(type, "float"))
         {  textRange->len +=
            sprintf
            (  textRange->str+textRange->len, "%.*f"
            ,  checkBoundsPrintDigits, *((float*)lftBound)
            )
      ;  }
         else if (!strcmp(type, "integer"))  
         {  textRange->len +=
            sprintf
            (  textRange->str+textRange->len, "%d", *((int*)lftBound) )
      ;  }
   ;  }
      else
      {  textRange->len += sprintf(textRange->str+textRange->len, "%s", "<-")
   ;  }

   ;  textRange->len += sprintf(textRange->str+textRange->len, "%s", ",")

   ;  if (rgtBound)
      {  if (!strcmp(type, "float"))
         {  textRange->len +=
            sprintf
            (  textRange->str+textRange->len, "%.*f"
            ,  checkBoundsPrintDigits, *((float*)rgtBound)
            )
      ;  }
         else if (!strcmp(type, "integer"))  
         {  textRange->len +=
            sprintf(textRange->str+textRange->len, "%d", *((int*)rgtBound))
      ;  }
   ;  }
      else
      {  textRange->len += sprintf(textRange->str+textRange->len, "%s", "->")
   ;  }

   ;  if (rgtRlt)
      {  for(i=4;i<8;i++)
            if (rgtRlt == rltFunctions[i])
               break
      ;  if (i<8)
            rgtToken = (char *) rltSigns[i]
   ;  }
      else
      rgtToken = (char *) ")"

   ;  textRange->len += sprintf(textRange->str+textRange->len, "%s", rgtToken)

   ;  return textRange
;  }


void flagCheckBounds
(  const char*    flag
,  const char*    type
,  void*          var
,  int            (*lftRlt) (const void*, const void*)
,  void*          lftBound
,  int            (*rgtRlt) (const void*, const void*)
,  void*          rgtBound
)  {
      mcxTing* textRange

   ;  if (checkBounds(type, var, lftRlt, lftBound, rgtRlt, rgtBound))
      {  textRange =
         checkBoundsRange(type, var, lftRlt, lftBound, rgtRlt, rgtBound)
      ;  fprintf
         (  stderr
         ,  "[%s] %s argument to %s should be in range %s\n"
         ,  flagCheckBoundsCaller, type, flag, textRange->str
         )
      ;  mcxTingFree(&textRange)
      ;  exit(1)
   ;  }
      else
      {  return
   ;  }
;  }

