/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <ctype.h>

#include "parse.h"

#include "file.h"
#include "iface.h"
#include "curly.h"
#include "constant.h"
#include "util.h"
#include "ops.h"
#include "key.h"

#include "util/minmax.h"


static   const char* arg_padding_g[10] =  {  "#0" , "#1" , "#2"
                                          ,  "#3" , "#4" , "#5"
                                          ,  "#6" , "#7" , "#8"
                                          ,  "#9"
                                          }  ;

            int         tracing_g      =  0;
static      int         tracing_gp     =  0;    /* previous value */
static      int         tracect_g      =  0;


mcxTing      key_and_args_g[10];

mcxTing*     key_g                     =  key_and_args_g+0;

mcxTing*     arg1_g                    =  key_and_args_g+1;
mcxTing*     arg2_g                    =  key_and_args_g+2;
mcxTing*     arg3_g                    =  key_and_args_g+3;
mcxTing*     arg4_g                    =  key_and_args_g+4;
mcxTing*     arg5_g                    =  key_and_args_g+5;
mcxTing*     arg6_g                    =  key_and_args_g+6;
mcxTing*     arg7_g                    =  key_and_args_g+7;
mcxTing*     arg8_g                    =  key_and_args_g+8;
mcxTing*     arg9_g                    =  key_and_args_g+9;
mcxTing*     arg10_g                   =  key_and_args_g+10;

int          n_args_g;

void traceput
(  char     c
,  mcxTing* txt
)  ;

int tagoffset
(  mcxTing      *txt
,  int         offset
)  ;

/* 
 *  -*=+H+=*-    -*=+H+=*-    -*=+H+=*-    -*=+H+=*-    -*=+H+=*-    -*=+H+=*-
 *
 *    all zoem primitives are handled in the same way, by an expand routine.
 *    expandUser handles all user macros.
 *    expansion will not construct  an illegal key because bsbs remains bsbs.
 *
 *    If anon is true, the k from '#k' is off by one and is ignored.
*/

yamSeg* expandUser
(  yamSeg*  seg
)
   {  yamSeg*  newseg   =  NULL
   ;  mcxbool  anon     =  *(key_g->str+0) == '_' && *(key_g->str+1) == '#'
   ;  mcxTing* val      =  anon ? arg1_g : yamKeyGet(key_g)

   ;  if (!val)
      yamExit("expand", "no definition found for key <%s>", key_g->str)

   ;  else
      {  mcxTing* repl  =  mcxTingEmpty(NULL, 30)
      ;  int      po    =  0                    /* previous offset   */
      ;  int      o     =  0
      ;  int      delta =  anon ? 1 : 0

      ;  if (n_args_g)
         {
            while( (o = tagoffset(val, o)) >= 0)
            {
               int   i  =  *(val->str+o+1) - '0'

            ;  mcxTingNAppend(repl, val->str+po, o-po)   /* skip \k  */

            ;  if (i < 1 || i+delta > n_args_g)
               yamExit("expand", "argument \\%d out of range", i)

            ;  mcxTingAppend(repl, (key_and_args_g+delta+i)->str)
            ;  o       +=  2
            ;  po       =  o
         ;  }
      ;  }

      ;  mcxTingNAppend(repl, val->str+po, val->len-po)
      ;  newseg = yamSegPush(seg, repl)
   ;  }
   ;  return newseg
;  }



/*
 *    returns l such that txt->str[offset+l] starts "\\k", k = argnum.
*/

int tagoffset
(  mcxTing      *txt
,  int         offset
)
   {  char* o     =  txt->str + offset
   ;  char* p     =  o
   ;  char* z     =  txt->str + txt->len

   ;  int   esc   =  p && (*p == '\\')

   ;  while (++p < z)
      {
         if (esc)
         {
            if (*p >= '1' && *p <= '9')
            return (offset + (p-o-1))

         ;  esc = 0
      ;  }
         else if (*p == '\\')
         esc = 1
   ;  }

      return -1
;  }



/*
 * returns index of '{' if it is first non-white space character,
 * -1 otherwise.
*/

int seescope
(  char* p
,  int   len
)
   {  char* o = p
   ;  char* z = p + len
   ;  while(isspace(*p) && p < z)
      ++p
   ;  if (*p == '{')
      return (p-o)
   ;  return -1
;  }


/*
 * returns length of key found, -1 if error occurred.
*/

int checkusrsig
(  char* p
,  int   len
,  int*  kp
)
   {  int   namelen  =  -1
   ;  int   taglen   =  -1
     
   ;  namelen = checkusrname(p, len)

   ;  if (namelen <= 0)
      return -1
   ;  else if (namelen == len || *(p+namelen) != '#')    /* a simple key */
      {  if (kp)
         *kp = 0
      ;  return namelen
   ;  }

      taglen = checkusrtag(p+namelen, len-namelen, kp)

   ;  if (taglen < 0)
      return -1

   ;  return (namelen + taglen)
;  }


/*
 * returns length of tag found, -1 if error occurred.
*/

int checkusrtag
(  char* p
,  int   len
,  int*  kp
)
   {  char*  o = p         /* offset */
   ;  char*  q = p + 1
   ;  char*  z = p + len
   ;  int    k = 0

   ;  if (*p != '#' || !isdigit(*q))
      return -1

   ;  while (++p < z && isdigit(*p))
      {  k *= 10
      ;  k += *p - '0'
   ;  }

   ;  if (kp)
      *kp = k

   ;  return (p-o)
;  }


/*
 * returns length of block found, -1 if error occurred.
*/

int checkblock
(  mcxTing* txt
,  int offset
)
   {  int cc = closingcurly(txt, offset, NULL, RETURN_ON_FAIL)
   ;  return cc > 0 ? cc + 1 : -1
;  }


/*
 * returns length of name found, -1 if error occurred.
*/

int checkusrname
(  char* p
,  int   len
)
   {  char*  o = p         /* offset */
   ;  char*  z = p + len

   ;  if (p >= z || (!isalpha(*p) && *p != '_' && *p != '$' && *p != '"'))
      return -1

   ;  if (*p == '"')
      {  while (++p<z && *p != '"')
         {  if (*p == '\\' || *p == '{' || *p == '}')
            return -1
      ;  }

      ;  if (*p == '"')
         p++
      ;  else
         return -1
   ;  }

      else
      {  if (*p == '$')
      ;  while (p<z && *++p && (isalnum(*p) || *p == '_'))
   ;  }

      return (p-o)
;  }




/*
 *    Sets seg offset to slash introducing keyword if present,
 *    leaves it alone otherwise.
 *    Leaves the "\" string as it is: this is currently a feature
 *    used by \meta#2.
*/

int findkey
(  yamSeg    *seg
)
   {  mcxTing*  txt  =  seg->txt
   ;  int   offset   =  seg->offset
   ;  int   x

   ;  char*    a     =  txt->str
   ;  char*    o     =  a + offset
   ;  char*    p     =  a + offset
   ;  char*    z     =  a + txt->len

   ;  int   esc      =  p && (*p == '\\')
   ;  int   lc       =  p && (*p == '\n') ? 1 : 0   /* *p may be '\n' indeed */
   ;  int   found    =  0

   ;  if (seg->flags & SEGMENT_CONSTANT)
      return -1

   ;  while (++p < z)
      {
         if (*p == '\n')
         lc++

      ;  if (esc)                           /* a backslash, that is */
         {
            if
            (  isalpha(*p) || *p == '$' || *p == '_' || *p == '"' || *p == '!'
            )
            {  found =  1
            ;  seg->offset     =  offset + (p-o-1)
            ;  break
         ;  }
            else
               switch(*p)
               {
                  case '\\'
               :  case '}'
               :  case '{'
               :  case '\n'
               :  case '~'             /* \~ encodes &nbsp;          */
               :  case '|'             /* \| encodes <br>            */
               :  case '-'             /* \- encodes &emdash;        */
               :  case ','             /* \, is atom separator       */
               :  {  esc   =  0
                  ;  break
               ;  }

                  case '@'
               :  {
                     p++
                  ;  if ((x = closingcurly(txt, p-a, &lc, RETURN_ON_FAIL)) < 0)
                     {
                        yamInputIncrLc(txt, lc)
                     ;  scopeErr(seg, "findkey (while closing at scope)", x)
                  ;  }

                  ;  p    +=  x     /* now *p == '}', while() will skip it */
                  ;  esc   =  0
                  ;  break
               ;  }

                  case '*'
               :  {
                     if ((x =  eoconstant(txt, p-a)) < 0)
                     yamExit("findkey", "format error in constant expression")

                  ;  p    +=  x     /* now *p == '*', while() will skip it */
                  ;  esc   =  0
                  ;  break
               ;  }

                  default
               :  {  if (*p >= '0' && *p <= '9')
                     {  esc   =  0
                     ;  break
                  ;  }
                     else
                     {  yamInputIncrLc(txt, lc)
                     ;  yamExit
                        ("findkey", "illegal escape sequence <\\%c>\n", *p)
                  ;  }
               ;  }
            ;  }
      ;  }
         else if (*p == '\\')
         esc      =  1
   ;  }

      yamInputIncrLc(txt, lc)
   ;  return (found ? seg->offset : -1)
;  }


/*
 *    Expects offset to match a slash introducing a keyword.  Sets seg offset
 *    beyond keyword + args.  sets n_args_g, and fills key_and_args_g.  padds
 *    key with the number of arguments.
 *
 *    I chose not to unify with parsescopes for various reasons.  - parsescopes
 *    interface would need an extra skipspace boolean, it would probably need
 *    magic n=0 behaviour, and it would be unclear how to do the n>9 error
 *    handling. If you need to reconsider this, think before coding.
*/

int  parsekey
(  yamSeg    *seg
)
   {  int  offset       =  seg->offset
   ;  mcxTing* txt      =  seg->txt

   ;  char* o           =  txt->str + offset
   ;  char* z           =  txt->str + txt->len
   ;  char* p           =  o+1

   ;  int n_args        =  0
   ;  int n_anon        =  0
   ;  int lc            =  0

   /* this is ugly. should create checkparseable that wraps around
    * checkusrname (and does other things)
   */
   ;  mcxbool meta      =  *p == '!'
   ;  int namelen       =  meta ? 1 : checkusrname(p, z-o-1)
   ;  mcxbool anon      =  namelen == 1 && *p == '_'

   ;  if (namelen < 1)
      yamExit("parsekey", "invalid key")

   ;  p += namelen

   ;  if (anon && *(p) == '#')
      {  if (*(p+1) < '1' || *(p+1) > '9' || *(p+2) != '{')
         yamExit("parsekey", "Anonymous key not ok")
      ;  n_anon         =  *(p+1) - '0'
      ;  p += 2
   ;  }

   ;  mcxTingNWrite(key_g, o+1, namelen)

   ;  while (p<z && *p == '{')
      {  
         int c = closingcurly(txt, offset + p-o, &lc, EXIT_ON_FAIL)

      ;  if (++n_args>9)
         yamExit("parsekey", "too many arguments for key %s\n", key_g->str)

      ;  mcxTingNWrite((key_and_args_g+n_args),p+1, c-1)
      ;  p              =  p+c+1    /* position beyond closing curly */

      ;  if (meta)
         break
   ;  }

      yamInputIncrLc(txt, lc)
   ;  lc = 0

   ;  if (n_anon && n_anon + 1 != n_args)
      yamExit
      (  "parsekeyk"
      ,  "found anon _#%d{%s} with %d arguments"
      ,  n_anon
      ,  arg1_g->str
      ,  n_args - 1
      )
   ;  else if (n_args)
      mcxTingAppend(key_g, arg_padding_g[n_args])

   ;  n_args_g          =  n_args
   ;  seg->offset       =  offset + (p-o)

   ;  return 0
;  }



yamSeg*  dokey
(  yamSeg *seg
)
   {  parsekey(seg)
   ;  return expandkey(seg)
;  }



/*
 *    returns number of scopes found, possibly less than n.
*/

int parsescopes
(  yamSeg*  seg
,  int      n
,  int      delta
)
   {  int   offset      =  seg->offset
   ;  mcxTing* txt      =  seg->txt
   ;  char* o           =  txt->str + offset
   ;  char* p           =  o
   ;  char* z           =  txt->str + txt->len
   ;  int   count       =  0

   ;  if (delta + n > 9)
      yamExit("parsescopes", "PBD not that many (%d) scopes allowed", n)

   ;  if (tracing_g & (ZOEM_TRACE_SCOPES))
      printf("* sco: parsing up to %d scopes\n", n)

   ;  while(count < n)
      {
         int cc   /* closing curly */

      ;  while(isspace(*p) && p < z)
         ++p

      ;  if (p==z || *p != '{')
         break                   /* bugtrap: seg->offset nu goed? */

      ;  if ((cc = closingcurly(txt, offset + p-o, NULL, RETURN_ON_FAIL)) < 0)
         scopeErr(seg, "parsescopes", cc)

      ;  mcxTingNWrite(key_and_args_g+(delta + ++count), p+1, cc-1)
      ;  p +=  cc + 1

      ;  if (tracing_g & (ZOEM_TRACE_SCOPES))
         traceput('{', key_and_args_g+delta+count)
   ;  }

   ;  if (tracing_g & (ZOEM_TRACE_SCOPES))
      printf("* sco: found %d scopes\n", count)

   /*  mcxTingWrite(key_g, "__parsescopes__") */
   /* caller should fill key_g */
   ;  n_args_g       =  count + delta
   ;  seg->offset    =  offset + p-o
   ;  return count
;  }




/*
 *  Is called after parsekey in dokey. parsekey fills key_and_args_g
 *  and updates seg->offset.
 *  Pops a new seg onto the stack.
*/

yamSeg*  expandkey
(  yamSeg *seg
)
   {  xpnfnc yamop

   ;  if (tracing_g)
      {
         int i
      ;  tracect_g++
      ;  printf
         (  "* key %d: %s (seg %d stack %d)\n"
         ,  tracect_g
         ,  key_g->str
         ,  seg->idx
         ,  yamStackIdx()
         )

      ;  if (tracing_g & (ZOEM_TRACE_DEFS))
         {  mcxTing* def = yamKeyGet(key_g)
         ;  if (def)
            traceput('<', def)
      ;  }

      ;  if (tracing_g & (ZOEM_TRACE_ARGS))
         {  for (i=1;i<=n_args_g;i++)
            traceput('|', key_and_args_g+i)
      ;  }
   ;  }

      yamop = yamOpGet(key_g)
   ;  return yamop ? yamop(seg) : expandUser(seg)
;  }


void yamParseInitialize
(  int   traceflags
)
   {  int i

   ;  for(i=0;i<10;i++)  
         mcxTingInit(key_and_args_g+i)
      ,  mcxTingWrite(key_and_args_g+i, "_atstart_")

   ;  tracing_g = traceflags
;  }


int yamTracingSet
(  int   traceflags
)
   {  int prev       =  tracing_g

   ;  if (traceflags == -2)
      tracing_g = ZOEM_TRACE_ALL_LONG
   ;  else if (traceflags == -1)
      tracing_g = ZOEM_TRACE_ALL
   ;  else
      tracing_g = traceflags

   ;  return prev
;  }


/*
 *    '{'   for scopes
 *    '|'   for arguments
 *    '<'   for key defs
 *    '['   for segments
*/

void traceput
(  char     c
,  mcxTing* txt
)
   {  const char* s  =  txt->str
   ;  char d         =  c == '{' ? '}' : c == '<' ? '>' : c == '|' ? '|' : ']'
   ;  int l          =  txt->len
   ;  char* nl       =  strchr(s, '\n')
   ;  int i_nl       =  nl ? nl - s : l
   ;  int LEN        =  50
   ;  char* cont
   ;  int n

   ;  n = MAX(0, MIN(i_nl, MIN(l, LEN)))

   ;  cont =   nl && i_nl < LEN
               ?  "(\\n)"
               :  nl && i_nl >= LEN
                  ?  "(..\\n)"
                  :  n < l
                     ?  "(..)"
                     :  ""

   ;  if (c != '[' && tracing_g & (ZOEM_TRACE_LONG))
      {  printf("__%c", c)
      ;  traceputlines(s, -1)
      ;  printf("%c__ [%d]\n", d, l)
   ;  }
      else
      printf("  %c%.*s%c%s [%d]\n", c, n, s, d, cont, l)
;  }


void traceputlines
(  const char* s
,  int len
)
   {  const char* z = len >= 0 ? s + len : NULL

   ;  while (*s && (!z || s < z))
      {  if (*s == '\n')
         printf("\n...")
      ;  else
         putc(*s, stdout)
      ;  s++
   ;  }
;  }

