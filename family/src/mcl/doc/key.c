

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

#include "doc/key.h"
#include "util/txt.h"
#include "util/array.h"
#include "util/hash.h"


static   mcxTxt      key_and_args_g[10];
static   mcxTxt*     key_g             =  key_and_args_g+0;
static   mcxTxt*     arg1_g            =  key_and_args_g+1;
static   mcxTxt*     arg2_g            =  key_and_args_g+2;
static   mcxTxt*     arg3_g            =  key_and_args_g+3;

static   int         n_args_g;

static   yamTables*  tables_g          =  NULL;

static   const char* arg_padding_g[10] =  {  "#0" , "#1" , "#2"
                                          ,  "#3" , "#4" , "#5"
                                          ,  "#6" , "#7" , "#8"
                                          ,  "#9"
                                          }  ;

static   const char* arg_tag_g[10]     =  {  "\\0" , "\\1" , "\\2"
                                          ,  "\\3" , "\\4" , "\\5"
                                          ,  "\\6" , "\\7" , "\\8"
                                          ,  "\\9"
                                          }  ;


void  yamErr
(  yamSlice *slice
,  const char  *caller
,  const char  *msg
)  ;


yamSlice*  dokey
(  yamSlice *slice
)  ;


yamSlice*   expandkey
(  yamSlice*   slice
)  ;


int   findkey
(  yamSlice  *snt
)  ;


int  parsekey
(  yamSlice    *line
)  ;


void setkey
(  yamSlice*   slice
)  ;


void  yamSliceFree
(  yamSlice*   slice
)  ;


/*
 *    txt->str[offset] must be '{'.
 *    returns l such that txt->str[offset+l] is matching '}',
 *    -1 if the latter does not exist.
*/

int   closingcurly
(
   yamSlice    *slice
,  int         offset
)  ;


int   tagoffset
(
   mcxTxt      *txt
,  int         argnum
,  int         offset
)  ;


/*
 *    returns l such that txt->str[offset+l] starts "\\k", k = argnum.
*/

int   tagoffset
(
   mcxTxt      *txt
,  int         argnum
,  int         offset
)
   {
      char* o     =  txt->str + offset
   ;  char* p     =  o
   ;  char* z     =  txt->str + txt->len

   ;  char  n     =  (char) ('0' + argnum)
   ;  int   esc   =  p && (*p == '\\')

   ;  while (++p < z)
      {
         if (esc)
         {
            if (*p == n)
            return (offset + (p-o-1))
         ;  else
            esc   =  0
      ;  }
         else if (*p == '\\')
         esc      =  1
   ;  }

   ;  return(-1)
;  }


/*
 *    txt->str[offset] must be '{'.
 *    returns l such that txt->str[offset+l] == '}'.
*/

int   closingcurly
(
   yamSlice    *slice
,  int         offset
)
   {
      mcxTxt* txt =  slice->txt
   ;  char* o     =  txt->str + offset
   ;  char* p     =  o
   ;  char* z     =  txt->str + txt->len

   ;  int   n     =  1           /* 1 open bracket */
   ;  int   lc    =  (*p == '\n') ? 1 : 0
   ;  int   esc   =  0

   ;  if (*p != '{')
         fprintf(stderr, "[closingcurly PBD] no curly no currency\n")
      ,  exit(1)

   ;  while(++p < z)
      {
         if (*p == '\n')
         lc++

      ;  if (esc)
         {  esc   =  0           /* no checks for validity */
         ;  continue
      ;  }

         else if (*p == '\\')
         esc++

      ;  else
         switch(*p)
         {  case  '{' :  n++ ;  break
         ;  case  '}' :  n--
      ;  }

      ;  if (!n)
         break
   ;  }

   ;  slice->linect  += lc
   ;  return(n ? -1 : p-o)
;  }


/*
 *    Sets slice offset to slash introducing keyword if present,
 *    leaves it alone otherwise.
*/

int   findkey
(
   yamSlice    *slice
)
   {
      mcxTxt*  txt   =  slice->txt
   ;  int   offset   =  slice->offset
   ;  int   x

   ;  char*    a     =  txt->str
   ;  char*    o     =  a + offset
   ;  char*    p     =  a + offset
   ;  char*    z     =  a + txt->len

   ;  int   esc      =  p && (*p == '\\')
   ;  int   lc       =  p && (*p == '\n') ? 1 : 0
   ;  int   found    =  0

   ;  while (++p < z)
      {
         if (*p == '\n')
         lc++

      ;  if (esc)                           /* a backslash, that is */
         {
            if (isalpha(*p))
            {
               found =  1
            ;  slice->offset     =  offset + (p-o-1)
            ;  break
         ;  }
            else
               switch(*p)
               {
                  case  '\\'  :  case  '}'   :  case  '{'   :  case ','
               :  esc   =  0
               ;  break
               ;
                  case '@'
               :  while (isalpha(*++p))    /* first non-alpha */

               ;  if (*p != '{')
                     yamErr
                     (  slice
                     ,  "findkey"
                     ,  "'\\@' takes form \\@{...} or \\@<key>{...}"
                     )
                  ,  exit(1)

               ;  if ((x =  closingcurly(slice, p-a)) < 0)
                     yamErr(slice, "findkey", "'\\@{' not closed")
                  ,  exit(1)
               ;  p    +=  x + 1
               ;  esc   =  0
               ;  break
               ;
                  default
               :  yamErr(slice, "findkey", "")
               ,  fprintf
                  (  stderr
                  ,  "[%d, %d] illegal escape sequence <%c%c>\n"
                  ,  offset, offset + p-o
                  ,  *(p-1), *p
                  )
               ;  exit(1)
            ;  }
      ;  }
         else if (*p == '\\')
         esc      =  1
   ;  }

   ;  slice->linect += lc
   ;  return (found ? slice->offset : -1)
;  }


/*
 *    expects offset to match a slash introducing a keyword.
 *    Sets slice offset beyond keyword + args.
 *    sets n_args_g, and fills key_and_args_g.
 *    padds key with the number of arguments.
*/

int  parsekey
(
   yamSlice    *slice
)
   {
      int  offset =  slice->offset
   ;  mcxTxt* txt =  slice->txt

   ;  char* o     =  txt->str + offset
   ;  char* p     =  o
   ;  char* z     =  txt->str + txt->len

   ;  int ok      =  0
   ;  int n_args  =  0

   ;  if (*p != '\\')
         fprintf(stderr, "[parsekey PBD] no slash no rose\n")
      ,  exit(1)

   ;  if (p+1 >= z || (!isalpha(*(p+1)) && *(p+1) != '_'))
         fprintf
         (  stderr
         ,  "[parsekey PBD] no alphanumerunderscore around line %d\n"
         ,  slice->linect
         )
      ,  exit(1)

   ;  while(++p < z && (isalpha(*p) || *p == '_'))
      ;
         
   ;  mcxTxtNWrite(key_g, o, p-o)

;if(0)printf("[parsekey] key equals [%d][%s]\n", key_g->len, key_g->str)

   ;  while (p<z && *p == '{')
      {  
         int   c       =  closingcurly(slice, offset + p-o)

      ;  if (c<0)
            fprintf(stdout, "[parsekey] error parsing arg\n")
         ,  exit(1)

      ;  if (++n_args>9)
            fprintf(stdout, "too many arguments for key %s\n", key_g->str)
         ,  exit(1)

      ;  mcxTxtNWrite((key_and_args_g+n_args),p+1, c-1)
      ;  p              =  p+c+1    /* position beyond closing curly */
   ;  }

   ;  mcxTxtAppend(key_g, arg_padding_g[n_args])

   ;  n_args_g          =  n_args
   ;  slice->offset     =  offset + (p-o)

;if(0)printf("[parsekey] key <%s> slice %d offset %d\n"
   , key_g->str, slice->idx, slice->offset)

   ;  return 0
;  }


yamSlice*  dokey
(
   yamSlice *slice
)
   {
      int   status   =  parsekey(slice)

   ;  if (status)
      {  fprintf(stdout, "[dokey error: %s]\n", "parsekey")
      ;  return(NULL)
   ;  }

   ;  return expandkey(slice)
;  }


/*
 *    Is called after parsekey in dokey. parsekey fills key_and_args_g
 *    and updates slice->offset.
 *    Pops a new slice onto the stack.
*/

yamSlice*  expandkey
(
   yamSlice *slice
)
   {
      int         i
   ;  yamSlice*   newslice   =  NULL
   ;  mcxTxt     *repl       =  NULL
 
   ;  if (!strcmp(key_g->str, "\\set#3"))
      {  
         setkey(slice)
      ;  return slice
   ;  }
      else
      {
         mcxKV*   kv
         =  (mcxKV*) mcxHashSearch
            (  key_g
            ,  *(tables_g->tables+0)
            ,  DATUM_FIND
            )

      ;  if (!kv)
            yamErr(slice, "expandkey", "")
         ,  fprintf
            (  stderr
            ,  "key [%d]<%s> not found  in hash %p\n"
            ,  key_g->len
            ,  key_g->str
            ,  *(tables_g->tables+0)
            )
         ,  exit(1)

      ;  else
         {
            repl           =  mcxTxtNew( ((mcxTxt*) (kv->val))->str )

         ;  for (i=1;i<=n_args_g;i++)
            {
              /*
               *     expansion will not construct
               *     an illegal key because bsbs remains bsbs.
              */

               int   o     =  0

            ;  while( (o = tagoffset(repl, i, o)) > 0)
               {
                  mcxTxtSplice
                  (  repl
                  ,  (const char**) &((key_and_args_g+i)->str)
                  ,  o                                /* offset oh         */
                  ,  2                                /* delete 2          */
                  ,  0                                /* offset zero       */
                  ,  (key_and_args_g+i)->len          /* insert this much  */
                  )
               ;  if(0)printf("[expandkey] repl <%s>\n", repl->str)
            ;  }
         ;  }
         ;  newslice          =  yamSliceNew(repl)
         ;  newslice->next    =  slice
         ;  newslice->idx     =  slice->idx + 1
         ;  newslice->linect  =  slice->linect
      ;  }

      ;  return newslice
   ;  }

   ;  return NULL
;  }


void  yamSliceFree
(
   yamSlice*   slice
)
   {
      mcxTxtFree(&slice->txt)
   ;  free(slice)
;  }


yamSlice*  yamSliceNew
(
   mcxTxt*  txt
)
   {
      yamSlice*   slice    =  (yamSlice*)  malloc(sizeof(yamSlice))
   ;  slice->txt           =  txt
   ;  slice->offset        =  0
   ;  slice->linect        =  1
   ;  slice->stack_size    =  0
   ;  slice->idx           =  0
   ;  slice->next          =  NULL
   ;  return slice
;  }


void setkey
(
   yamSlice*   slice
)
   {
      mcxKV*   kv
   ;  mcxTxt*  key      =  mcxTxtNew(arg1_g->str)
   ;  int      keylen   =  key_g->len
   ;  int      n_args   =  0
   ;  int      ok       =  1
   ;  char*    p        =  key->str

   ;  if (n_args_g != 3)
         yamErr(slice, "setkey", "\\set takes three arguments\n")
      ,  exit(1)

   ;  ok      =  (*p == '\\')
   ;  while (*++p && isalpha(*p))
      ;
   ;  if (!ok || *p)
         yamErr(slice, "setkey", "")
      ,  fprintf
         (  stderr
         ,  "first argument (%s) must take form \\[a-zA-Z_]+\n"
         ,  key->str
         )
      ,  exit(1)

   ;  n_args  =  *(arg2_g->str) - '0'
   ;  if (n_args < 0 || n_args > 9)
         yamErr(slice, "setkey", "")
      ,  fprintf(stderr, "second argument should be in range [0-9]\n")
      ,  exit(1)

   ;  mcxTxtAppend(key, arg_padding_g[n_args])

   ;  kv    =        mcxHashSearch
                     (  key
                     ,  *(tables_g->tables+0)
                     ,  DATUM_INSERT
                     )

   ;  if (!kv)
         fprintf(stderr, "[setkey panic & PBD] cannot insert key\n")
      ,  exit(1)

   ;  else
      {
         if (kv->key != key)
            fprintf(stderr, "[setkey warning] overwriting key <%s>\n",key->str)
         ,  mcxTxtFree(&key)

      ;  if (kv->val)
         mcxTxtWrite((mcxTxt*) (kv->val), arg3_g->str)
      ;  else
         kv->val  =  mcxTxtNew(arg3_g->str)
   ;  }


   ;  if(0)printf
      (  "[setkey] made key-val [%d]<%s><%s> in %p\n"
      ,  ((mcxTxt*) (kv->key))->len
      ,  ((mcxTxt*) (kv->key))->str
      ,  ((mcxTxt*) (kv->val))->str
      ,  *(tables_g->tables+0)
      )
;  }


int   filter_html
(
   mcxTxt*     txt
,  int         offset
,  int         bound
)
   {

      char     c        =  *(txt->str+bound)
   ;  char    *d        =  txt->str+offset

   ;  *(txt->str+bound) =  '\0'

   ;  printf("%s", d)
   ;  *(txt->str+bound) =  c
   ;  return (0)
;  }


/*
 *    if filter is NULL do not produce output.
 *
*/

int   digest
(
   yamTables   *stack                            /* read/write symbols   */
,  mcxTxt      *txt                              /* interpret slice        */
,  int         filter(mcxTxt* txt, int offset, int bound)
)
   {

      yamSlice *slice         =  yamSliceNew(txt)
   ;  int      offset         =  slice->offset
   ;  int      i

   ;  tables_g                =  stack

   ;  for(i=0;i<10;i++)  
      mcxTxtInit(key_and_args_g+i)

   ;  while(slice)
      {
         int         prev_offset =  slice->offset
      ;  yamSlice*   prev_slice  =  slice

      ;  if ((offset = findkey(slice)) >= 0)
         {
            filter(slice->txt, prev_offset, offset)
         ;  slice                =  dokey(slice)
      ;  }

         else
         {
            filter(slice->txt, prev_offset, slice->txt->len)
         ;  slice                =  slice->next
         ;  yamSliceFree(prev_slice)
      ;  }
   ;  }

   ;  return   0
;  }



void  yamErr
(
   yamSlice *slice
,  const char  *caller
,  const char  *msg
)
   {
      fflush(NULL)

   ;  fprintf
      (  stderr
      ,  "\nparse error in [%s] (around line %d)%s%s\n"
      ,  caller
      ,  slice->linect
      ,  *msg ? "\n" : ""
      ,  msg
      )
;  }

