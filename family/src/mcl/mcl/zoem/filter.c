/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "filter.h"
#include "curly.h"
#include "util.h"
#include "constant.h"
#include "iface.h"
#include "parse.h"

#include "util/minmax.h"

/* yamFilterPlain IS (confusingly) the 'device' filter.
 * yamFilterTxt   is the 'txt' filter
 * yamFilterCopy  is the 'copy' filter
 *
 * yamFilterAt is called by:
 *    yamFilterPlain
 *    yamputc in plain mode.
 *    yamPutConstant
 *    yamSpecialPut
 *
 * yamputc in plain mode is called by:
 *    yamFilterPlain
 *
 * yamputc in at mode is called by:
 *    yamFilterAt
 *
 * yamPutConstant is called by
 *    yamFilterPlain
 *
 * yamSpecialPut is called by
 *    yamFilterPlain
 *
 * yamFilterTxt calls none of the above
 * yamFilterCopy calls none of the above
*/


#define N_SPECIAL       259
#define SPECIAL_SPACE   256
#define SPECIAL_BREAK   257
#define SPECIAL_DASH    258

static mcxTing* yamSpecial[N_SPECIAL];


int yamAtDirective
(  yamFilterData*    fd
,  char              c
)  ;


int yamFilterAt
(  yamFilterData*    fd
,  mcxTing*          txt
,  int               offset
,  int               length
)  ;


int yamFilterTxt
(  yamFilterData*    fd
,  mcxTing*          txt
,  int               offset
,  int               length
)  ;


int yamFilterCopy
(  yamFilterData*      fd
,  mcxTing*          txt
,  int               offset
,  int               length
)  ;


typedef struct
{
   const char*       name
;  const char*       descr
;  fltfnc            filter
;
}  fltHook        ;


#define F_DEVICE     "device filter (customize with \\special#1)"
#define F_TXT        "interprets [\\\\][\\~][\\,][\\|][\\}][\\{]"
#define F_COPY       "identity filter (literal copy)"

static fltHook fltHookDir[]
=
{  {  "copy"         ,  F_COPY         ,  yamFilterCopy  }
,  {  "device"       ,  F_DEVICE       ,  yamFilterPlain }
,  {  "txt"          ,  F_TXT          ,  yamFilterTxt   }
,  {  NULL           ,  NULL           ,  NULL           }
}  ;


static      fltfnc      filter_g       =  NULL;
static      yamFilterData *fd_g          =  NULL;

static   mcxHash*    fltTable_g        =  NULL;    /* filters           */


void yamPutConstant
(  yamFilterData* fd
,  const char* p
)  ;

void yamSpecialPut
(  yamFilterData* fd
,  unsigned int c
)  ;

void yamputnl
(  char c
,  FILE* fp
)  ;


yamFilterData* yamFilterDataNew
(  FILE* fp
)
   {  yamFilterData* fd =  mcxAlloc(sizeof(yamFilterData), EXIT_ON_FAIL)
   ;  fd->indent        =  0
   ;  fd->n_newlines    =  1     /* count of flushed newlines */
   ;  fd->s_spaces      =  0     /* count of stacked spaces   */
   ;  fd->doformat      =  1
   ;  fd->fp            =  fp
   ;  return fd
;  }


int   yamFilterTxt
(  yamFilterData*    fd
,  mcxTing*          txt
,  int               offset
,  int               length
)
   {  FILE* fp    =  fd->fp
   ;  int   esc   =  0
   ;  char* o     =  txt->str + offset
   ;  char* z     =  o + length
   ;  char* p

   ;  for (p=o;p<z;p++)
      {
         if (esc)
         {
            switch(*p)
            {  
               case '@'
            :  {
                  int l
               =  closingcurly(txt, offset + (p-o)+1, NULL, RETURN_ON_FAIL)

               ;  if (l<0 || offset+(p-o)+1+l >= offset + length)
                  yamExit("yamFilterTxt", "PBD scope error?!")

               ;  fputs("\\@", fp)
               ;  while(--l && ++p)
                  {  if (*p == '\n')
                     yamputnl('@', fp)             /* lit at nl in txt flt */
                  ;  else
                     fputc(*p, fp)
               ;  }

                  break
            ;  }

               case '\\'   :  fputc('\\', fp)   ;  break
            ;  case '|'    :  yamputnl('|', fp) ;  break    /* \| in txt flt */
            ;  case '-'    :  fputc('-', fp)    ;  break
            ;  case '~'    :  fputc(' ', fp)    ;  break    /* wsm */
            ;  case '{'    :  fputc('{', fp)    ;  break
            ;  case '}'    :  fputc('}', fp)    ;  break
            ;  case ','    :                    ;  break
            ;  default     :  fputc(*p, fp)     ;  break
         ;  }
            esc = 0
      ;  }
         else if (*p == '\\')
         esc = 1
      ;  else
         {  if (*p == '\n')
            yamputnl('.', fp)   /* lit plain nl in txt flt */
         ;  else
            fputc(*p, fp)
      ;  }
      }
      return 0
;  }



int yamFilterCopy
(  yamFilterData*      fd
,  mcxTing*           txt
,  int               offset
,  int               length
)
   {  FILE* fp    =  fd->fp
   ;  char* p

   ;  for (p=txt->str+offset;p<txt->str+offset+length;p++)
      {  if (*p == '\n')
         yamputnl('.', fp)       /* lit nl (anywhere) in copy flt */
      ;  else
         fputc(*p, fp)
   ;  }

   ;  return 0
;  }



enum
{  F_MODE_ATnESC = 1
,  F_MODE_AT
,  F_MODE_ESC
,  F_MODE_DEFAULT
}  ;


int yamAtDirective
(  yamFilterData*    fd
,  char              c
)
   {  FILE* fp = fd->fp

   ;  switch(c)
      {  case 'N'
         :  while (fd->n_newlines < 1)
            {  fd->n_newlines++
            ;  yamputnl('%', fp) /* '%' nl in at scope */
         ;  }
            fd->s_spaces = 0     /* flush spaces */
         ;  break
      ;  case 'P'
         :  while (fd->n_newlines < 2)
            {  fd->n_newlines++
            ;  yamputnl('%', fp) /* '%' nl in at scope */
         ;  }
            fd->s_spaces = 0     /* flush spaces */
         ;  break
      ;  case 'T'
         :  fd->indent++
         ;  break
      ;  case 'B'
         :  fd->indent = MAX(fd->indent-1, 0)
         ;  break
      ;  case 'C'
         :  fd->indent = 0
         ;  break
      ;  case 'w'
         :  fd->doformat = 0
         ;  break
      ;  case 'n'
         :  yamputnl('%', fp) /* '%' nl in at scope */
         ;  fd->n_newlines++     /* yanl */
         ;  fd->s_spaces = 0     /* flush spaces */
         ;  break
      ;  case 'S'
         :  fd->s_spaces++       /* stack a sapce */
         ;  break
      ;  case 's'
         :  fputc(' ', fp)
         ;  fd->s_spaces = 0     /* flush other spaces */
         ;  fd->n_newlines = 0   /* no longer at bol */
         ;  break
      ;  case 't'
         :  yamputc(fd, '\t', 1)
         ;  break
      ;  case 'W'
         :  fd->doformat = 1
         ;  break
      ;  default
         :  yamExit("yamFilterAt", "unsupported '%%' option <%c>", c)
   ;  }
      return 1
;  }


/*
 *  We keep track of spaces and newlines. If we print by yamputc,
 *  yamputc does that for us. If we print by fputc, we do it ourselves.
 *
 *  we ignore *(txt->offset+length) (it will be '\0' or '}' or so).
*/

int yamFilterAt
(  yamFilterData*    fd
,  mcxTing*          txt
,  int               offset
,  int               length
)
   {  FILE* fp          =  fd->fp
   ;  char* o           =  txt->str + offset
   ;  char* z           =  o + length
   ;  char* p           =  o
   ;  const char* me    =  "yamFilterAt"

   ;  int fltmode       =  F_MODE_AT

   ;  while (p<z)
      {
         unsigned char c = (unsigned char) *p

      ;  switch(fltmode)
         {  
            case F_MODE_ATnESC
         :  switch(c)
            {
               case '}' :  case '{' :  case '\\'
               :  yamputc(fd, c, 1)
               ;  break

            ;  case ','
               :  break

            ;  case '*'
               :  yamExit
                  (  me
                  ,  "constant keys not allowed in at scope - found <\\%s>\n"
                  ,  p
                  )

            ;  case '~' :  case '|' :  case '-'
               :  yamExit
                  (  me
                  ,  "zoem glyphs not allowed in at scope - found <\\%c>"
                  ,  c
                  )

            ;  case 'N' :  case 'n' :  case 'P' :  case 'p'
            :  case 'C' :  case 'B' :  case 'W' :  case 'w'
            :  case 'T' :  case 's' :  case 'S'
               :  yamAtDirective(fd, *p)
               ;  break

            ;  case '%'
               :  while (p<z && *++p != '%')
                  yamAtDirective(fd, *p)   /* while loop skips closing '%' */
               ;  if (*p != '%')
                  yamExit(me, "no closing '%%' found <%c>", *p)
               ;  break

            ;  default
               :  yamExit("yamFilterAt", "unknown escape <%c>", c)
         ;  }

            fltmode  =  F_MODE_AT
         ;  break
         ;

            case F_MODE_AT
         :  switch(c)
            {
               case '\\'
               :  fltmode = F_MODE_ATnESC
               ;  break
            ;  default
               :  yamputc(fd, c, 1)
         ;  }
            break
         ;
      ;  }
      ;  p++
   ;  }
   ;  return 0
;  }


int yamFilterPlain
(  yamFilterData*      fd
,  mcxTing*           txt
,  int               offset
,  int               length
)
   {  char* o           =  txt->str + offset
   ;  char* z           =  o + length
   ;  char* p           =  o
   ;  const char* me    =  "yamFilterPlain"
   ;  int   x

   ;  int fltmode       =  F_MODE_DEFAULT
   ;

  /*
   *  we must enter yfp in this mode by design, and this deserves more
   *  explanation. hierverder.
   *
  */
      while (p<z)
      {
         unsigned char c = (unsigned char) *p

      ;  switch (fltmode)
         {
            case F_MODE_ESC
         :  switch(c)
            {
               case '@'
               :  p++
               ;  x = closingcurly(txt, offset + p-o, NULL, RETURN_ON_FAIL)
               ;  if (x<0 || offset+(p-o)+x >= offset + length)
                  yamExit(me, "PBD scope error?!")
              /*  *(txt->str+offset+(p-o)+x) == '}' */
               ;  yamFilterAt(fd, txt, offset + p-o+1, x-1)
               ;  p += x
               ;  break

            ;  case '*'
               :  {  int l = eoconstant(txt, offset + p-o)
                  ;  if (l<0 || offset+(p-o)+1+l >= offset + length)
                     yamExit(me, "PBD const error?!")
                  ;  *(p+l) = '\0'
                  ;  yamPutConstant(fd, p+1)
                  ;  p += l
                  ;  break
               ;  }

               case '}' :  case '{' :  case '\\'
               :  yamputc(fd, c, 0)
               ;  break
            ;  case '~'
               :  yamSpecialPut(fd, 256)
               ;  break
            ;  case '|'
               :  yamSpecialPut(fd, 257)
               ;  break
            ;  case '-'
               :  yamSpecialPut(fd, 258)
               ;  break
            ;  case ',' :  case '\n'
               :  break
               ;
            ;  default
               :  fprintf
                  (  stderr
                  ,  "___ [%s] mode esc, skipping escape [\\%c]\n"
                  ,  me
                  ,  c
                  )
         ;  }
            fltmode  =  F_MODE_DEFAULT
         ;  break
         ;

            case F_MODE_DEFAULT
         :  switch(c)
            {
               case '\\'
               :  fltmode = F_MODE_ESC
               ;  break
            ;  default
               :  yamputc(fd, c, 0)    /* wsm */
         ;  }
         ;  break
         ;

      ;  }
      ;  p++
   ;  }

      return 0
;  }


void yamputc
(  yamFilterData*    fd
,  unsigned char     c
,  int               atcall
)
   {  FILE* fp = fd->fp
   ;  mcxTing* special = atcall ? NULL : yamSpecial[c]

   ;  if (fd->doformat)
      {
         if (c == ' ')
         {  if (!fd->n_newlines)
            fd->s_spaces++       /* do not stack spaces at bol */
      ;  }
         else if (c == '\n')
         {  if (fd->n_newlines < 1)
            {  fd->n_newlines++
      /* yamputnl,yamputc,doformat: @/. lit nl in at or plain scope */
            ;  yamputnl(atcall ? '@' : '.', fp)
         ;  }
            fd->s_spaces = 0     /* flush all spaces when newline */
      ;  }
         else
         {
            if (fd->n_newlines)
            {
               int i       =  0
            ;  for (i=0;i<2*fd->indent;i++)
               fputc(' ', fp)
            ;  fd->n_newlines = 0
         ;  }
            else if (fd->s_spaces)
            {  fputc(' ', fp)
            ;  fd->s_spaces = 0
         ;  }

         ;  if (special)
            yamFilterAt(fd, special, 0, special->len)
         ;  else
            fputc(c, fp)
      ;  }
   ;  }
      else
      {  if (c == '\n')
         fd->n_newlines++
      ;  else if (c != '\n')
         fd->n_newlines = 0

      ;  if (c != ' ')
         fd->s_spaces = 0

      ;  if (special)
         yamFilterAt(fd, special, 0, special->len)
      ;  else
         {  if (c == '\n')
            yamputnl(atcall ?  '+' : '~' , fp)
      /* yamputnl,yamputc,dontformat: +/~ lit nl in at or plain scope */
         ;  else
            fputc(c, fp)      /* wsm */
      ;  }
   ;  }
;  }


void yamPutConstant
(  yamFilterData* fd
,  const char* p
)
   {
      mcxTing*  key  =  mcxTingNew(p)
   ;  mcxTing*  txt  =  yamConstantGet(key)

   ;  if (txt)
      yamFilterAt(fd, txt, 0, txt->len)
   ;  else
      fprintf(stderr, "___ warning: constant *%s* not found\n", key->str)

   ;  mcxTingFree(&key)
;  }


void yamSpecialPut
(  yamFilterData* fd
,  unsigned int c
)
   {  mcxTing*  spc = yamSpecial[c]
   ;  if (c < N_SPECIAL && spc)
      yamFilterAt(fd, spc, 0, spc->len)
;  }


void yamSpecialSet
(  unsigned int c
,  const char* str
)
   {  if (c >= N_SPECIAL)
      return
   ;  if (yamSpecial[c])
      mcxTingWrite(yamSpecial[c], str)
   ;  else
      yamSpecial[c] = mcxTingNew(str)
;  }


void yamFilterInitialize
(  int            n
)
   {
      fltHook* flthook     =  fltHookDir
   ;  int i

   ;  fltTable_g           =  mcxHashNew(n, mcxTingHash, mcxTingCmp)

   ;  while (flthook && flthook->name)
      {
         mcxTing*  flttxt  =  mcxTingNew(flthook->name)
      ;  mcxKV*   kv       =  mcxHashSearch(flttxt,fltTable_g, MCX_DATUM_INSERT)
      ;  kv->val           =  flthook
      ;  flthook++
   ;  }

   ;  for (i=0;i<N_SPECIAL;i++)
      yamSpecial[i]        =  NULL

   ;  yamSpecial[SPECIAL_SPACE] = mcxTingNew(" ")
   ;  yamSpecial[SPECIAL_BREAK] = mcxTingNew("\n")
   ;  yamSpecial[SPECIAL_DASH]  = mcxTingNew("-")
;  }


void yamFilterList
(  const char* mode
)
   {  mcxbool listAll = strstr(mode, "all") != NULL
   ;  if (listAll || strstr(mode, "filter"))
      {  fltHook* flthook  =  fltHookDir
      ;  fprintf
         (stdout, "\nFilter names available for the \\write#3 command\n")
      ;  while (flthook && flthook->name)
         {  fprintf(stdout, "%-15s %s\n", flthook->name, flthook->descr)
         ;  flthook++
      ;  }
   ;  }
;  }


void yamFilterSetDefaults
(  fltfnc         filter
,  yamFilterData*   fd
)
   {  

   ;  filter_g             =  filter
   ;  fd_g                 =  fd
;  }


fltfnc yamFilterGet
(  mcxTing* label
)
   {
      mcxKV *kv =  mcxHashSearch(label, fltTable_g, MCX_DATUM_FIND)
   ;  return kv ? ((fltHook*) kv->val)->filter : NULL
;  }


yamFilterData* yamFilterGetDefaultFd
(  void
)
   {  if (fd_g)
      return fd_g
   ;  else
         yamExit("filter", "request for default file data: absent!\n")
      ,  exit(1)
         
   ;  return NULL
;  }


fltfnc yamFilterGetDefaultFilter
(  void
)
   {  if (filter_g)
      return filter_g
   ;  else
         yamExit("filter", "request for default filter: absent!\n")
      ,  exit(1)
         
   ;  return NULL
;  }


void yamputnl
(  char  c
,  FILE* fp
)
   {  fputc('\n', fp)
   ;  if (tracing_g & ZOEM_TRACE_OUTPUT)
      {  fputc('[', fp)
      ;  fputc(c, fp)
      ;  fputc(']', fp)
   ;  }
   }

