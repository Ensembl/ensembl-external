/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include "ops.h"

#include <ctype.h>
#include <stdlib.h>

#include "util.h"
#include "bind.h"
#include "digest.h"
#include "key.h"
#include "filter.h"
#include "file.h"
#include "segment.h"
#include "parse.h"
#include "ref.h"
#include "read.h"
#include "env.h"
#include "curly.h"
#include "counter.h"
#include "constant.h"

#include "util/txt.h"
#include "util/hash.h"
#include "util/file.h"

#define I_DEF_2       "{ks}{cx}         (complain if key exists)"

/*  Returns the input seg unaffected.
*/

#define I_SET_2       "{ks}{cx}         (do not complain if key exists)"

/*  Returns the input seg unaffected.
*/

#define I_SETX_2      "{ks}{ex}         (expand definition before storing)"

/*  The second argument is expanded and stored in the key named in the first.
 *  Returns the input seg unaffected.
*/

#define I_APPLY_2     "{x}{ev}          (apply key to vararg)"

/*  x is expanded and interpreted as key signature or anonymous key.
 *  Vararg is evaluated as a whole before arguments are shifted.
 *  Repeated expansions of key are appended to a new segment.
 *  This segment is pushed on the current segment stack.
 *  Pushes new seg on current stack.
*/

#define I_WHILE_2     "{x}{x}           [eval arg2 while eval arg1 nonzero]"

/*  While first x expands to nonzeo integer, second x is expanded.
 *  The successive results are appended to a new segment that is
 *  pushed on the current segment stack.
 *  Pushes new seg on current stack.
*/

#define I_TABLE_5     "{ex}{cx}{cx}{cx}{ev}  [row-len lft sep rgt, data]"

/*  The first argument should expand to an integer, row-len. The last argument
 *  is a vararg that is evaluated as a whole before it is parsed.
 *  The other three are spliced (as left border, separator, and right border)
 *  into vectors of length row-len that are successively shifted from
 *  the expanded vararg.
 *  Pushes new seg on current stack.
*/

#define I_ENV_3       "{l}{cx}{cx}      [begin, end]"

/*  Returns the input seg unaffected.
*/

#define I_BEGIN_1     "{l[cv]}          (begin key env)"

/*  The optional vararg is not expanded. Its contents (if present) are stored
 *  as (a subset of) \$1 .. \$9 in a new dollar dictionary.
 *  Pushes new seg on current stack.
*/

#define I_END_1       "{l[cv]}          (end key env)"

/*  The optional vararg is not expanded. Its contents (if present) are stored
 *  as (a subset of) \$1 .. \$9 in a new dollar dictionary.
 *  Pushes new seg on current stack.
*/

#define I_TRACE_1     "{ex}             [trace flags]"

/*  Argument is expanded and interpreted as integer
 *  Returns the input seg unaffected.
*/

#define I_WRITE_3     "{ex}{s}{x}       [fname, filter name, expression]"

/*  The first argument is expanded and used as a file name.
 *  The second must be one of 'txt', 'copy', 'device'.
 *  --?is there a use for expansion of second argument?--
 *  The third argument is expanded and written.
 *
 *  Starts a new stack and output session.
 *  Returns the input seg unaffected.
*/

#define I_DOFILE_2    "{ex}{aa[!?][+-]} [fname, mode (existence+output)]"

/*  The first argument is expanded and used as a file name.
 *  The second is a constant string and denotes the mode.
 *  --?is there a use for expansion of second argument?--
 *
 *  Starts a new stack and output session.
 *  Returns the input seg unaffected.
*/

#define I_STORE_2  "{kn}{ex}         [zero-arg key, file name] (store content)"

/*  The second argument is expanded, used as file name, and the contents
 *  of the file are put in the key specified by the first argument, without
 *  expansion.
 *  Returns the input seg unaffected.
*/

#define I_REF_2    "{l}{a[ntlcm]}    [ref, id(Number|Type|Level|Caption|Misc)]"

/*  Retrieves a member associated with a reference label.
 *  Pushes a copy of this member on the current segment stack.
 *  Pushes new seg on current stack.
*/

#define I_REFLOAD_6   "{l}{i}{cx}{cx}{cx}{cx}    [ref, lev, typ, num, title, misc]"

/*  Sets members for a label. NO MEMBER IS EVALUATED.
 *  --?what is the rationale again?--
 *  (it is currently always used with \meta#3 in combination with
 *  writing to file and reading that file in the next session).
 *  Returns the input seg unaffected.
*/

#define I_QUIT_0      "(quit parsing current stack in current file)"

/*  --?is this clean with respect to memory?--
*/

#define I_EXIT_0      "(goodbye world)"

/*  The fastest way out
*/

#define I_PUSH_0      "(push a new key dictionary)"

/*  Returns the input seg unaffected.
*/

#define I_POP_0       "(pop the top key dictionary)"

/*  Returns the input seg unaffected.
*/

#define I_CTRSET_2    "{l}{ex}          [label, integer]"

/*  Returns the input seg unaffected.
*/

#define I_CTRPUT_1    "{l}              [label]"

/*  Pushes new seg on current stack.
*/

#define I_CTRADD_2    "{l}{ex}          [label, integer]"

/*  Returns the input seg unaffected.
*/

#define I_ISUM_1      "{ev}             [constituents to be summed]"

/*  Pushes new seg on current stack.
*/

#define I_ICLC_3      "{a[+-/%*]}{ex}{ex}   [operator, integer, integer]"

/*  Pushes new seg on current stack.
*/

#define I_ICMI_5      "{ex}{ex}{x}{x}{x}  [int, int, case lt, case eq, case gt]"

/*  Pushes new seg on current stack.
*/

#define I_IFEQ_4      "{ex}{ex}{x}{x}   [op1, op2, case eq, case ne]"

/*  Pushes new seg on current stack.
*/

#define I_IFDEF_3     "{ks}{ex}{ex}     [key, case def, case not def]"

/*  Pushes new seg on current stack.
*/

#define I_IFDEFL_3    "{ks}{ex}{ex}     [key, case local def, case no local def]"

/*  Pushes new seg on current stack.
*/

#define I_UNDEF_1     "{ks}             [key]"

/*  Returns the input seg unaffected.
*/

#define I_SWITCH_2    "{ex}{v{<{ex}{x}>+{ex}?>}} [pivot, [case, eval]+ finish]"

/*  Pushes new seg on current stack.
*/

#define I_DSET_2      "{ev}{cx|cv}      [access sequence, value|{key}{value}+]"

/*  Returns the input seg unaffected.
*/

#define I_DSETX_2     "{ev}{ex|ev}      [access sequence, value|{key}{value}+]"

/*  Expands before storage.
 *  Returns the input seg unaffected.
*/

#define I_DGET_1      "{ev}             [access sequence]"

/*  Pushes new seg on current stack.
*/

#define I_DFREE_1     "{ev}             [access sequence]"

/*  Returns the input seg unaffected.
*/

#define I_DPRINT_1    "{ev}             [access sequence]"

/*  Returns the input seg unaffected.
*/

#define I_SPECIAL_1   "{v<{i}{zc}>+}    [ascii num, translation]+"

/*  Returns the input seg unaffected.
*/

#define I_CONSTANT_1  "{v<{l}{zc}>+}    [label (used as \\*l*), translation]+"

/*  Returns the input seg unaffected.
*/

#define I_DOLLAR_2    "{s}{x}           [device, eval if \\$device is device]"

/*  Pushes new seg on current stack [possibly].
*/

#define I_FORMATTED_1 "{cx}             [remove ws in cx, translate \\%nst%]"

/*  Pushes new seg on current stack.
*/

#define I_META_3      "{x}{s}{v}        [write key call with kn and args in v]"


#define I_BANG_1      "{cx}             [strip curlies]"

#define I_BANG_0      "                 [make slash]"

/*  x is expanded and interpreted as a key signature.
 *  s is a string of flags.
 *  Pushes new seg on current stack.
 *  --?why is the code so cumbersome, apart from the backslash trouble?--
*/

#define F_DEVICE     "device filter (customize with \\special#1)"
#define F_TXT        "interprets [\\\\][\\~][\\,][\\|][\\}][\\{]"
#define F_COPY       "identity filter (literal copy)"

#define  READ_INPUT     1           /* uses default file & filter */
#define  READ_IMPORT    2           /* interpretation only        */
#define  READ_READ      4           /* uses default file & filter */
#define  READ_LOAD      8           /* interpretation only        */

const char *legend_g
=
"L e g e n d\n"
"Ab   Meaning           Examples/explanation\n"
"--| |---------------| |---------------------------------------------------|\n"
"kn   key name          e.g. <foo> or <\"foo::bar-zut\"> (without the <>)\n"
"ks   key signature     e.g. <foo#2> or <\"+\"#2> (without the <>)\n"
"km   key mention       e.g. <\\foo#2> or <\\\"+\"#2> (in documentation)\n"
"ak   anonymous key     e.g. \\_#2{foo{\\1}\\bar{\\1}{\\2}}\n"
"zc   zoem constant     may contain \\@{..} \\\\ \\} \\{ \\, \\| \\~ \\-\n"
"x    expression        expanded *after* the zoem primitive was applied\n"
"v    vararg            of the form {..} {..} .. {..} (white space allowed)\n"
"ex   expression        immediately expanded by the zoem primitive\n"
"ev   vararg            immediately expanded by the zoem primitve\n"
"i    integer           e.g. '123', '-6', no arithmetic expressions allowed\n"
"l    label             name spaces for counters, refs, constants, and env\n"
"a    character         presumably a switch of some kind\n"
"s    string            presumably a label of some miscellaneous kind\n"
;

static   mcxHash*    yamTable_g        =  NULL;    /* primitives        */
static   mcxTing*    devtxt_g          =  NULL;    /* "\\$device"        */

const char *strComposites
=
   "\\def{input#1}{\\dofile{\\1}{!+}}\n"
   "\\def{import#1}{\\dofile{\\1}{!-}}\n"
   "\\def{read#1}{\\dofile{\\1}{?+}}\n"
   "\\def{load#1}{\\dofile{\\1}{?-}}\n"
   "\\def{meta#2}{\\meta{\\1}{x}{\\2}}\n"
   "\\def{meta#1}{\\meta{\\1}{x}{}}\n"
   "\\def{refcaption#1}{\\ref{\\1}{c}}\n"
   "\\def{refnumber#1}{\\ref{\\1}{n}}\n"
   "\\def{reflevel#1}{\\ref{\\1}{l}}\n"
   "\\def{refmisc#1}{\\ref{\\1}{m}}\n"
   "\\def{reftype#1}{\\ref{\\1}{t}}\n"
   "\\def{string#1}{\\ifdef{\\1}{\\1}{}}\n"
   "\\def{inc#1}{\\ctradd{\\1}{1}}\n"
   "\\def{ctr#1}{\\ctrput{\\1}}\n"
   "\\def{ctr#2}{\\ctrset{\\1}{\\2}}\n"
   "\\def{\"+\"#2}{\\iclc{+}{\\1}{\\2}}\n"
   "\\def{\"-\"#2}{\\iclc{-}{\\1}{\\2}}\n"
   "\\def{\"/\"#2}{\\iclc{/}{\\1}{\\2}}\n"
   "\\def{\"%\"#2}{\\iclc{%}{\\1}{\\2}}\n"
   "\\def{\"*\"#2}{\\iclc{*}{\\1}{\\2}}\n"
;


typedef struct
{
   const char*       name
;  const char*       descr
;  yamSeg*           (*yamfunc)(yamSeg* seg)
;
}  cmdHook           ;


static   cmdHook     cmdHookDir[]      =  
{
   {  "$#2"        ,  I_DOLLAR_2      ,  expandDollar2     }
,  {  "apply#2"    ,  I_APPLY_2       ,  expandApply2      }
,  {  "begin#1"    ,  I_BEGIN_1       ,  expandBegin1      }
,  {  "constant#1" ,  I_CONSTANT_1    ,  expandConstant1   }
,  {  "ctradd#2"   ,  I_CTRADD_2      ,  expandCtradd2     }
,  {  "ctrput#1"   ,  I_CTRPUT_1      ,  expandCtrput1     }
,  {  "ctrset#2"   ,  I_CTRSET_2      ,  expandCtrset2     }
,  {  "def#2"      ,  I_DEF_2         ,  expandDef2        }
,  {  "dfree#1"    ,  I_DFREE_1       ,  expandDfree1      }
,  {  "dget#1"     ,  I_DGET_1        ,  expandDget1       }
,  {  "dofile#2"   ,  I_DOFILE_2      ,  expandDofile2     }
,  {  "dprint#1"   ,  I_DPRINT_1      ,  expandDprint1     }
,  {  "dset#2"     ,  I_DSET_2        ,  expandDset2       }
,  {  "dsetx#2"    ,  I_DSETX_2       ,  expandDsetx2      }
,  {  "end#1"      ,  I_END_1         ,  expandEnd1        }
,  {  "env#3"      ,  I_ENV_3         ,  expandEnv3        }
,  {  "exit"       ,  I_EXIT_0        ,  expandExit0       }
,  {  "formatted#1",  I_FORMATTED_1   ,  expandFormatted1  }
,  {  "iclc#3"     ,  I_ICLC_3        ,  expandIclc3       }
,  {  "icmp#5"     ,  I_ICMI_5        ,  expandIcmp5       }
,  {  "ifdef#3"    ,  I_IFDEF_3       ,  expandIfdef3      }
,  {  "ifdefl#3"   ,  I_IFDEFL_3      ,  expandIfdefl3     }
,  {  "ifeq#4"     ,  I_IFEQ_4        ,  expandIfeq4       }
,  {  "isum#1"     ,  I_ISUM_1        ,  expandIsum1       }
,  {  "meta#3"     ,  I_META_3        ,  expandMeta3       }
,  {  "!#1"        ,  I_BANG_1        ,  expandBang1       }
,  {  "!"          ,  I_BANG_0        ,  expandBang0       }
,  {  "pop"        ,  I_POP_0         ,  expandPop0        }
,  {  "push"       ,  I_PUSH_0        ,  expandPush0       }
,  {  "quit"       ,  I_QUIT_0        ,  expandQuit0       }
,  {  "ref#2"      ,  I_REF_2         ,  expandRef2        }
,  {  "refload#6"  ,  I_REFLOAD_6     ,  expandRefload6    }
,  {  "set#2"      ,  I_SET_2         ,  expandSet2        }
,  {  "setx#2"     ,  I_SETX_2        ,  expandSetx2       }
,  {  "special#1"  ,  I_SPECIAL_1     ,  expandSpecial1    }
,  {  "store#2"    ,  I_STORE_2       ,  expandStore2      }
,  {  "switch#2"   ,  I_SWITCH_2      ,  expandSwitch2     }
,  {  "table#5"    ,  I_TABLE_5       ,  expandTable5      }
,  {  "trace#1"    ,  I_TRACE_1       ,  expandTrace1      }
,  {  "undef#1"    ,  I_UNDEF_1       ,  expandUndef1      }
,  {  "while#2"    ,  I_WHILE_2       ,  expandWhile2      }
,  {  "write#3"    ,  I_WRITE_3       ,  expandWrite3      }
,  {  NULL         ,  NULL            ,  NULL              }

}  ;


mcxbool  yamOpList
(  const char* mode
)
   {  cmdHook*    cmdhook     =  cmdHookDir
   ;  mcxbool     listAll     =  strstr(mode, "all") != NULL
   ;  mcxbool     match       =  listAll || 0

   ;  if (listAll || strstr(mode, "zoem"))
      {  while (cmdhook && cmdhook->name)
         {  fprintf(stdout, "%-15s %s\n", cmdhook->name, cmdhook->descr)
         ;  cmdhook++
      ;  }
      ;  if (!strstr(mode, "legend"))
         fprintf(stdout, "Additionally supplying \"-l legend\" prints legend\n")
      ;  match = 1
   ;  }

   ;  if (listAll || strstr(mode, "legend"))
      {  fprintf(stdout, "\n%s", legend_g)
      ;  match = 1
   ;  }

   ;  if (listAll || strstr(mode, "macro"))
      {  fprintf
         (stdout, "\nBuilt-in aliases and macro's\n%s", strComposites)
      ;  match = 1
   ;  }

      return match ? TRUE : FALSE
;  }


/*
 *    if file can not be opened, sets filetxt->str to empty string
 *    and return STATUS_FAIL
*/

mcxstatus readFile
(  mcxTing*  fname
,  mcxTing*  filetxt
)  ;


yamSeg* expandStore2
(  yamSeg*  seg
)
   {  mcxTing*  key         =  mcxTingNew(arg1_g->str)
   ;  mcxTing*  fname       =  mcxTingNew(arg2_g->str)
   ;  mcxTing*  filetxt     =  mcxTingEnsure(NULL, 100)

   ;  if (checkusrname(key->str, key->len) != key->len)
      yamExit("\\store#2", "<%s> is not a valid key", key->str)

   ;  yamDigest(fname, fname)
   ;  readFile(fname, filetxt)

   ;  yamKeyInsert(key, filetxt->str)
   ;  mcxTingFree(&filetxt)

   ;  return seg
;  }


yamSeg* expandDofile2
(  yamSeg*  seg
)
   {  mcxTing*  fname       =  mcxTingNew(arg1_g->str)
   ;  mcxTing*  opts        =  arg2_g
   ;  mcxTing*  filetxt     =  mcxTingEnsure(NULL, 100)

   ;  int            mode
   ;  yamFilterData*   fd
   ;  fltfnc         flt

   ;  if (opts->len != 2)
      {  expandDofile2die:
         yamExit("\\dofile#2", "Second arg <%s> not in {!?}x{+-}", opts->str)
   ;  }

   ;  if (*(opts->str+0) == '!')
      {  if (*(opts->str+1) == '+')
         mode = READ_INPUT
      ;  else if (*(opts->str+1) == '-')
         mode = READ_IMPORT
      ;  else
         goto expandDofile2die;
   ;  }
      else if (*(opts->str+0) == '?')
      {  if (*(opts->str+1) == '+')
         mode = READ_READ
      ;  else if (*(opts->str+1) == '-')
         mode = READ_LOAD
      ;  else
         goto expandDofile2die;
   ;  }
      else
      goto expandDofile2die
      ;

   ;  fd    =     mode & (READ_INPUT | READ_READ)
               ?  yamFilterGetDefaultFd()
               :  NULL
   ;  flt   =     mode & (READ_INPUT | READ_READ)
               ?  yamFilterGetDefaultFilter()
               :  NULL

   ;  if (!yamInputCanPush())
      yamExit
      (  "\\dofile#2", "maximum file include depth (9) reached\n"
         "___ when presented with file <%s>"
      ,  fname->str
      )

   ;  yamDigest(fname, fname)

   ;  if (readFile(fname, filetxt) != STATUS_OK)
      {
         if (mode & (READ_INPUT | READ_IMPORT))
         yamExit("\\dofile#2","failed to open file argument <%s>\n",fname->str)

      ;  else                             /* READ or LOAD */
         {  mcxTingFree(&filetxt)
         ;  mcxTingFree(&fname)
         ;  return seg
      ;  }
   ;  }

   ;  yamInputPush(fname->str, filetxt)
   ;  mcxTingFree(&fname)
   ;  yamOutput(filetxt, flt, fd)
   ;  mcxTingFree(&filetxt)
   ;  yamInputPop()

   ;  return seg
;  }


yamSeg* expandBang0
(  yamSeg*  seg
)
   {  yamSeg* newseg = yamSegPush(seg, mcxTingNew("\\"))
   ;  newseg->flags  = SEGMENT_CONSTANT
   ;  return newseg
;  }


yamSeg* expandBang1
(  yamSeg*  seg
)
   {  yamSeg* newseg = yamSegPush(seg, mcxTingNew(arg1_g->str))
   ;  newseg->flags  = SEGMENT_CONSTANT
   ;  return newseg
;  }


yamSeg* expandMeta3
(  yamSeg*  seg
)
   {  mcxTing*  key     =  mcxTingNew(arg1_g->str)
   ;  mcxTing*  mods    =  mcxTingNew(arg2_g->str)
   ;  mcxTing*  args    =  mcxTingNew(arg3_g->str)
   ;  mcxTing*  bs      =  mcxTingNew("\\")
   ;  int namelen

   ;  yamDigest(key, key)

   ;  if (key->len == 1 && *(key->str) > '0' && *(key->str) <= '9')

   ;  else if ((namelen = checkusrname(key->str, key->len)) != key->len)
      {
         char*    p     =  key->str+namelen
      ;  mcxbool  anon  =  namelen == 1 && *(key->str) == '_'
      ;  int      delta =  0
      ;  int      sigk  =  0
      ;  int      cc    =  0

      ;  if (*p == '#')
         {  if (*(p+1) < '1' || *(p+1) > '9')
            yamExit("meta#3", "tagged signature <%s> not ok", key->str)
         ;  sigk  = *(p+1) - '0'
         ;  delta = 2
      ;  }

      ;  if (namelen + delta != key->len && !anon)
         yamExit("meta#3", "signature <%s> not ok", key->str)
      
      ;  if
         (  anon
         && ((cc = closingcurly(key, namelen+delta, NULL, RETURN_ON_FAIL)) < 0)
         )
         yamExit("meta#3", "tagged anon signature <%s> not ok", key->str)

      ;  if (sigk && !anon)
            mcxTingDelete(key, namelen, 2)
         ,  fprintf(stderr, "___ key now <%s>\n", key->str)
   ;  }

   /************************************************************************
    * now need to add checking by doing a 'countscopes'.
    * along the way, decide what to do about ws in third argument
   */

   ;  if (*(mods->str+0) == 'x')
      {  mcxTingAppend(bs, key->str)
      ;  mcxTingAppend(bs, args->str)
      ;  return yamSegPush(seg, bs)
   ;  }
      else
      {  yamSeg* seg3 = yamSegPush(seg, args)
      ;  yamSeg* seg2 = yamSegPush(seg3, key)
      ;  return yamSegPush(seg2, bs)   /*  prints a single backslash */
   ;  }
                                       /*  ONE DAMN UGLY HACK. FIXME! TODO! */
      return NULL
;  }


yamSeg* expandWhile2
(  yamSeg*  seg
)
   {  mcxTing*  condition  =  mcxTingNew(arg1_g->str)
   ;  mcxTing*  data       =  mcxTingNew(arg2_g->str)
   ;  mcxTing*  condition_ =  mcxTingEmpty(NULL, 10)
   ;  mcxTing*  data_      =  mcxTingEmpty(NULL, 10)
   ;  mcxTing*  newtxt     =  mcxTingEmpty(NULL, 10)
   ;
      while(1)
      {
         mcxTingWrite(condition_, condition->str)
      ;  yamDigest(condition_, condition_)
      ;
         if (atoi(condition_->str))
         {  mcxTingWrite(data_, data->str)
         ;  yamDigest(data_, data_)
         ;  mcxTingAppend(newtxt, data_->str)  
      ;  }
         else
         {  mcxTingFree(&condition_)
         ;  break
      ;  }
   ;  }

      mcxTingFree(&data)
   ;  mcxTingFree(&data_)
   ;  mcxTingFree(&condition)
   ;  mcxTingFree(&condition_)
   ;  return yamSegPush(seg, newtxt)
;  }


yamSeg* expandApply2
(  yamSeg*  seg
)
   {  mcxTing *key         =  mcxTingNew(arg1_g->str)
   ;  mcxTing *data        =  mcxTingNew(arg2_g->str)
   ;  mcxTing *newtxt      =  mcxTingEmpty(NULL, 10)
   ;  int delta            =  0
   ;  yamSeg *tblseg

   ;  int   x, k, keylen, namelen

   ;  yamDigest(data, data)
   ;  yamDigest(key, key)

   ;  keylen               =  checkusrsig(key->str, key->len, &k)
   ;  namelen              =  checkusrname(key->str, key->len)

   ;  if (k<=0 || k > 9)
      yamExit
      (  "\\apply#2"
      ,  "loop number <%d> not in [1,9] for key <%s>"
      ,  k
      ,  key->str
      )

   ;  if (namelen == 1 && *(key->str) == '_')      /* anonymous key */
      {
         int cc            =  closingcurly(key, keylen, NULL, EXIT_ON_FAIL)

      ;  if (cc+keylen+1 != key->len)
         yamExit("\\apply#2", "anonymous key <%s> not ok", key->str)

      ;  mcxTingNWrite(key_g, key->str, keylen)
      ;  mcxTingNWrite(arg1_g, key->str+keylen+1, cc-1)
      ;  delta = 1
   ;  }
      else if (keylen != key->len)
      {  yamExit
         (  "\\apply#2"
         ,  "key <%s> is not of the right \\foo, \\\"foo::foo\", and \\$foo\n"
         ,  key->str
         )
   ;  }
      else
      {  mcxTingWrite(key_g, key->str)
   ;  }

      tblseg = yamSegPush(NULL, data)

   /* perhaps this block should be encapsulated by parse.c
    * pity we have expandkey here.
    */

   ;  while ((x = parsescopes(tblseg, k, delta)) == k)
      {
         yamSeg* rowseg  = expandkey(seg) /* todo does seg have a role here? */
      ;  mcxTingAppend(newtxt,rowseg->txt->str)
      ;  yamSegFree(&rowseg)
   ;  }

   ;  mcxTingFree(&key)
   ;  yamSegFree(&tblseg)
   ;  mcxTingFree(&data)

   ;  return yamSegPush(seg, newtxt)
;  }



/*
*/

yamSeg* expandTable5
(  yamSeg*  seg
)
   {  mcxTing *txtnum    =  mcxTingNew(arg1_g->str)
   ;  mcxTing *txtlft    =  mcxTingNew(arg2_g->str)
   ;  mcxTing *txtmdl    =  mcxTingNew(arg3_g->str)
   ;  mcxTing *txtrgt    =  mcxTingNew(arg4_g->str)
   ;  mcxTing *data      =  mcxTingNew(arg5_g->str)
   ;  yamSeg *tmpseg

   ;  mcxTing *txtall    =  mcxTingEnsure(NULL, 100)

   ;  int  x, k

   ;  yamDigest(data, data)
   ;  yamDigest(txtnum, txtnum)
   ;  k = atoi(txtnum->str)

   ;  if (k<=0)
      yamExit("\\table#5", "nonpositive loop number <%d>\n", k)

   ;  tmpseg = yamSegPush(NULL, data)

   ;  while ((x = parsescopes(tmpseg, k, 0)) == k)
      {
         int i
      ;  mcxTingAppend(txtall, txtlft->str)
      ;  for (i=1;i<k;i++)
         {  mcxTingAppend(txtall, (key_and_args_g+i)->str)
         ;  mcxTingAppend(txtall, txtmdl->str)
      ;  }
      ;  mcxTingAppend(txtall, (key_and_args_g+k)->str)
      ;  mcxTingAppend(txtall, txtrgt->str)
   ;  }
   ;  mcxTingFree(&txtnum)
   ;  mcxTingFree(&txtlft)
   ;  mcxTingFree(&txtmdl)
   ;  mcxTingFree(&txtrgt)

   ;  yamSegFree(&tmpseg)
   ;  mcxTingFree(&data)

   ;  return yamSegPush(seg, txtall)
;  }


yamSeg* expandFormatted1
(  yamSeg*  seg
)
   {
      mcxTing*  txt         =  mcxTingNew(arg1_g->str)
   ;  char* o              =  txt->str
   ;  char* p              =  o
   ;  char* q              =  o
   ;  char* z              =  o + txt->len
   ;  mcxbool formatting   =  TRUE

   ;  int   esc            =  0

   ;  while (p < z)
      {
         if (esc)
         {
            if (*p == '@')
            {  int l    =  closingcurly(txt, p+1-o, NULL, EXIT_ON_FAIL)
            ;  *(q++)   =  '\\'
            ;  *(q++)   =  '@'
            ;  while (l-- && ++p)
               *(q++)   =  *p
            ;  *(q++)   =  *++p
         ;  }
            else if (*p == '%')
            {  while (p<z && *(++p) != '%')
               {  switch(*p)
                  {  case 's' : *(q++) = ' ';  break
                  ;  case 'n' : *(q++) = '\n'; break
                  ;  case 't' : *(q++) = '\t'; break
                  ;  case '<' : formatting = FALSE ; break
                  ;  case '>' : formatting = TRUE ; break
                  ;  default  :
                     yamExit("\\formatted1", "illegal character <%c>", *p)
               ;  }
            ;  }
            ;  if (p == z)
               yamExit("\\formatted1", "missing ']'")
         ;  }
            else if (*p == ':')
            {  do { p++; } while (p<z && *p != '\n')
         ;  }
            else
            {  *(q++) = '\\'
            ;  *(q++) = *p
         ;  }

            esc   =  0
      ;  }
         else if (formatting && isspace(*p))
      ;  else if (*p == '\\')
         esc = 1
      ;  else
         *(q++) = *p

      ;  p++
   ;  }
   ;  *q = '\0'
   ;  txt->len = q-o
   ;  return yamSegPush(seg, txt)
;  }


yamSeg* expandWrite3
(  yamSeg*  seg
)
   {
      mcxTing*    fname    =  mcxTingNew(arg1_g->str)
   ;  mcxTing*    yamtxt   =  mcxTingNew(arg3_g->str)
   ;  fltfnc      filter   =  yamFilterGet(arg2_g)
   ;  mcxIOstream *xfout

   ;  if (!filter)
      yamExit("\\write#3", "filter <%s> not found\n", arg2_g->str)

   ;  yamDigest(fname, fname)
   ;  xfout =  yamOutputNew(fname->str)
   ;  mcxTingFree(&fname)

   ;  yamOutput(yamtxt, filter, (yamFilterData*) xfout->ufo)

   ;  return seg
;  }


yamSeg* expandDollar2
(  yamSeg*  seg
)
   {
      yamSeg*  newseg      =  NULL
   ;  mcxTing*  device     =  yamKeyGet(devtxt_g)

   ;  if (!device)
      yamExit
      (  "\\$"
      ,  "key [\\$device] not defined, rendering use of <%s> useless\n"
      ,  key_g->str
      )
   ;  else if (!strcmp(device->str, arg1_g->str))
      {  mcxTing* txt    =  mcxTingNew(arg2_g->str)      /* skip '\$'  */
      ;  newseg          =  yamSegPush(seg, txt)
   ;  }
      return newseg ? newseg  : seg
;  }


yamSeg* expandUndef1
(  yamSeg*  seg
)
   {  mcxTing*  val     =  yamKeyDelete(arg1_g)
   ;  if (!val)
      fprintf
      (  stderr
      ,  "___ [\\undef#1] key <%s> not defined in this scope\n"
      ,  arg1_g->str
      )
   ;  else
      mcxTingFree(&val)
   ;  return seg
;  }


yamSeg* expandIfdefl3
(  yamSeg*  seg
)
   {  mcxTing* val
   ;  mcxTing* yamtxt

   ;  if (checkusrsig(arg1_g->str, arg1_g->len, NULL) != arg1_g->len)
      yamExit
      (  "\\ifdefl#3"
      ,  "first argument <%s> is not a valid key signature"
      ,  arg1_g->str
      )

   ;  val      =  yamKeyGetLocal(arg1_g)
   ;  yamtxt   =     val
                  ?  mcxTingNew(arg2_g->str)
                  :  mcxTingNew(arg3_g->str)

   ;  return yamSegPush(seg, yamtxt)
;  }


yamSeg* expandIfdef3
(  yamSeg*  seg
)
   {  mcxTing* val
   ;  mcxTing* yamtxt

   ;  if (checkusrsig(arg1_g->str, arg1_g->len, NULL) != arg1_g->len)
      yamExit
      (  "\\ifdef#3"
      ,  "first argument <%s> is not a valid key signature"
      ,  arg1_g->str
      )

   ;  val      =  yamKeyGet(arg1_g)
   ;  yamtxt   =     val
                  ?  mcxTingNew(arg2_g->str)
                  :  mcxTingNew(arg3_g->str)

   ;  return yamSegPush(seg, yamtxt)
;  }


yamSeg* expandIfeq4
(  yamSeg*  seg
)
   {  mcxTing*  op1         =  mcxTingNew(arg1_g->str)
   ;  mcxTing*  op2         =  mcxTingNew(arg2_g->str)
   ;  mcxTing*  yamtxt      =  NULL

   ;  yamDigest(op1, op1)
   ;  yamDigest(op2, op2)

   ;  if (!strcmp(op1->str, op2->str))
      yamtxt               =  mcxTingNew(arg3_g->str)
   ;  else
      yamtxt               =  mcxTingNew(arg4_g->str)

   ;  mcxTingFree(&op1)
   ;  mcxTingFree(&op2)

   ;  return yamSegPush(seg, yamtxt)
;  }


/*
 * Does not change the contents of access, does not claim ownership.
 * *DOES* take ownership of argk_g.
*/

void yamOpsDataAccess
(  const mcxTing*    access
)
   {  if (access->len == 0)
      {  n_args_g = 0
   ;  }
      else if (seescope(access->str, access->len) >= 0)
      {  yamSeg* tmpseg = yamSegPush(NULL, (mcxTing*) access)
      ;  parsescopes(tmpseg, 9, 0)
      ;  yamSegFree(&tmpseg)
   ;  }
      else
      {  n_args_g = 1
      ;  mcxTingWrite(arg1_g, access->str)
   ;  }
;  }


yamSeg* expandDprint1
(  yamSeg*  seg
)
   {  mcxTing*  access     =  mcxTingNew(arg1_g->str)
   ;  mcxbool ok

   ;  yamDigest(access, access)
   ;  yamOpsDataAccess(access)   /* writes access sequence in argk_g */

   ;  ok = yamDataPrint()
   
   ;  if (ok != TRUE)
      fprintf
      (  stderr
      ,  "___ [\\dprint#1] no value associated with\n"
         "__> <%s>\n"
      ,  access->str
      )

   ;  mcxTingFree(&access)
   ;  return seg
;  }


yamSeg* expandDfree1
(  yamSeg*  seg
)
   {  mcxTing*  access     =  mcxTingNew(arg1_g->str)
   ;  mcxbool ok  

   ;  yamDigest(access, access)
   ;  yamOpsDataAccess(access)   /* writes access sequence in argk_g */

   ;  ok = yamDataFree()
   
   ;  if (ok != TRUE)
      fprintf
      (  stderr
      ,  "___ [\\dfree#1] no value associated with\n"
         "__> <%s>\n"
      ,  access->str
      )

   ;  mcxTingFree(&access)
   ;  return seg
;  }


yamSeg* expandDget1
(  yamSeg*  seg
)
   {  const char* str
   ;  mcxTing* access = mcxTingNew(arg1_g->str)

   ;  yamDigest(access, access)
   ;  yamOpsDataAccess(access)   /* writes access sequence in argk_g */

   ;  str = yamDataGet()

   ;  if (!str)
      {  if (0)       /* should become 'strict' option */
         fprintf
         (  stderr
         ,  "___ [\\dget#1] no value associated with\n"
            "__> <%s>\n"
         ,  access->str
         )
      ;  return seg
   ;  }

      mcxTingFree(&access)
   ;  return yamSegPush(seg, mcxTingNew(str))
;  }


void dataSet
(  mcxbool expand
)
   {  mcxTing*  access     =  mcxTingNew(arg1_g->str)
   ;  mcxTing*  val        =  mcxTingNew(arg2_g->str)

   ;  if (expand)
      yamDigest(val, val)

   ;  yamDigest(access, access)
   ;  yamOpsDataAccess(access)   /* writes access sequence in argk_g */
   ;  yamDataSet(val)            /* takes ownership */

   ;  mcxTingFree(&access)
;  }


yamSeg* expandDsetx2
(  yamSeg*  seg
)
   {  dataSet(TRUE)     /* do not expand */
   ;  return seg
;  }


yamSeg* expandDset2
(  yamSeg*  seg
)
   {  dataSet(FALSE)    /* do not expand */
   ;  return seg
;  }


yamSeg* expandSwitch2
(  yamSeg*  seg
)
   {
      mcxTing*  keytxt     =  mcxTingNew(arg1_g->str)     
   ;  mcxTing*  chktxt     =  mcxTingNew(arg2_g->str)     
   ;  mcxTing*  tsttxt     =  mcxTingEnsure(NULL, 30)
   ;  mcxTing*  yamtxt     =  NULL
   ;  int   x

   ;  yamSeg*  tmpseg      =  yamSegPush(NULL, chktxt)
   ;  yamDigest(keytxt, keytxt)

   ;  while ((x = parsescopes(tmpseg, 2, 0)) == 2)
      {
         mcxTingWrite(tsttxt, arg1_g->str)

      ;  yamDigest(tsttxt, tsttxt)

      ;  if (!strcmp(tsttxt->str, keytxt->str))
         {  yamtxt = mcxTingNew(arg2_g->str)
         ;  break
      ;  }
   ;  }
   ;  if (x == 1)
      {  yamtxt = mcxTingNew(arg1_g->str)     /* fall through / else clause */
   ;  }

      mcxTingFree(&keytxt)
   ;  mcxTingFree(&tsttxt)

   ;  yamSegFree(&tmpseg)
   ;  mcxTingFree(&chktxt)

   ;  return   yamtxt ? yamSegPush(seg, yamtxt) : seg
;  }


yamSeg* expandConstant1
(  yamSeg*  seg
)
   {
      mcxTing*  yamtxt     =  mcxTingNew(arg1_g->str)     
   ;  yamSeg*  newseg      =  yamSegPush(NULL, yamtxt)
   ;  int   x

   ;  while ((x = parsescopes(newseg, 2, 0)) == 2)
      {  mcxTing* key      =  mcxTingNew(arg1_g->str)
      ;  if (yamConstantNew(key, arg2_g->str) != key)
         mcxTingFree(&key)
   ;  }

      if (x != 0)
      {  fprintf(stderr, "___ constant & a half\n")
      ;  exit(1)
   ;  }

      yamSegFree(&newseg)
   ;  mcxTingFree(&yamtxt)

   ;  return seg
;  }


yamSeg* expandSpecial1
(  yamSeg*  seg
)
   {
      mcxTing*  yamtxt     =  mcxTingNew(arg1_g->str)     
   ;  yamSeg*  newseg      =  yamSegPush(NULL, yamtxt)
   ;  int      x

   ;  while ((x = parsescopes(newseg,2, 0)) == 2)
      {
         int   c           =  atoi(arg1_g->str)
      ;  yamSpecialSet(c, arg2_g->str)
   ;  }

      if (x != 0)
      {  fprintf(stderr, "___ special & a half\n")
      ;  exit(1)
   ;  }

      yamSegFree(&newseg)
   ;  mcxTingFree(&yamtxt)

   ;  return seg
;  }


/*
 *    first argument:   anchor
 *    second:           level
 *    third:            type
 *    fourth:           counter
 *    fifth:            caption
 *    sixth:            misc
*/

yamSeg*  expandRefload6
(  yamSeg* seg
)
   {
      mcxbool newhdl =  yamRefNew
                        (  arg1_g->str ,  arg2_g->str ,  arg3_g->str
                        ,  arg4_g->str ,  arg5_g->str ,  arg6_g->str
                        )
   ;  if (!newhdl)
      fprintf(stderr, "[\\refload#6] key <%s> multiply defined\n", arg1_g->str)

   ;  return seg
;  }


yamSeg*  expandCtrset2
(  yamSeg* seg
)
   {
      mcxTing*  label      =  mcxTingNew(arg1_g->str)
   ;  mcxTing*  newval     =  mcxTingNew(arg2_g->str)
   ;  mcxTing*  ctr        =  yamCtrGet(label)

   ;  yamDigest(newval, newval)

   ;  if (ctr)
      mcxTingFree(&label)
   ;  else
      ctr = yamCtrMake(label)

   ;  yamCtrWrite(ctr, newval->str)
   ;  mcxTingFree(&newval)

   ;  return seg
;  }


yamSeg*  expandIcmp5
(  yamSeg* seg
)
   {
      mcxTing*  t1         =  mcxTingNew(arg1_g->str)
   ;  mcxTing*  t2         =  mcxTingNew(arg2_g->str)
   ;  mcxTing*  ycase
   ;  int i1, i2

   ;  yamDigest(t1, t1)
   ;  yamDigest(t2, t2)
   ;  i1    =  atoi(t1->str)
   ;  i2    =  atoi(t2->str)

   ;  ycase =     i1 < i2
               ?  mcxTingNew(arg3_g->str)
               :     i1 == i2
                  ?  mcxTingNew(arg4_g->str)
                  :  mcxTingNew(arg5_g->str)
   ;  mcxTingFree(&t1)
   ;  mcxTingFree(&t2)
   ;  return yamSegPush(seg, ycase)
;  }


/*
*/

yamSeg*  expandCtrput1
(  yamSeg* seg
)
   {
      mcxTing*   ctr        =  yamCtrGet(arg1_g)
   ;  mcxTing*   yamtxt     =  mcxTingNew(ctr ? ctr->str : "0")

   ;  return yamSegPush(seg, yamtxt)
;  }


/*
*/

yamSeg*  expandIsum1
(  yamSeg* seg
)
   {
      mcxTing*    data        =  mcxTingNew(arg1_g->str)
   ;  mcxTing*    sumtxt
   ;  yamSeg*     sumseg
   ;  char        sumstr[20]
   ;  int         sum         =  0
   ;  int         x

   ;  yamDigest(data, data)
   ;  sumseg = yamSegPush(NULL, data)

   ;  while ((x = parsescopes(sumseg, 1, 0)) == 1)
      {
         int d = atoi(arg1_g->str)
      ;  sum += d
   ;  }

      yamSegFree(&sumseg)
   ;  mcxTingFree(&data)

   ;  sprintf(sumstr, "%d", sum)
   ;  sumtxt  =  mcxTingNew(sumstr)

   ;  return yamSegPush(seg, sumtxt)
;  }


/*
*/

yamSeg*  expandIclc3
(  yamSeg* seg
)
   {
      int       mode       =  *(arg1_g->str+0)
   ;  mcxTing*  i1txt      =  mcxTingNew(arg2_g->str)
   ;  mcxTing*  i2txt      =  mcxTingNew(arg3_g->str)
   ;  mcxTing*  i3txt
   ;  char      i3str[20]
   ;  int       i1, i2, i3 =  0

   ;  yamDigest(i1txt, i1txt)
   ;  yamDigest(i2txt, i2txt)
   ;  i1  =  atoi(i1txt->str)
   ;  i2  =  atoi(i2txt->str)
   ;  mcxTingFree(&i1txt)
   ;  mcxTingFree(&i2txt)

   ;  switch(mode)
      {
         case '+'
         :  i3 = i1 + i2 ; break
      ;  case '-'
         :  i3 = i1 - i2 ; break
      ;  case '/'
         :  i3 = i1 / (i2 ? i2 : 1) ; break
      ;  case '%'
         :  i3 = i1 % i2 ; break
      ;  case '*'
         :  i3 = i1 * i2 ; break
      ;  default
         :  yamExit("\\iclc#3", "unknown mode <%c>", mode)
   ;  }

   ;  sprintf(i3str, "%d", i3)
   ;  i3txt = mcxTingNew(i3str)

   ;  return yamSegPush(seg, i3txt)
;  }


/*
*/

yamSeg*  expandCtradd2
(  yamSeg* seg
)
   {
      mcxTing* label       =  mcxTingNew(arg1_g->str)
   ;  mcxTing* ctr         =  yamCtrGet(label)
   ;  mcxTing* addtxt      =  mcxTingNew(arg2_g->str)
   ;  int      a           =  0
   ;  int      c           =  0

   ;  yamDigest(addtxt, addtxt)
   ;  a  =  atoi(addtxt->str)
   ;  mcxTingFree(&addtxt)

   ;  if (ctr)
      {  c  =  atoi(ctr->str)
      ;  mcxTingFree(&label)
   ;  }
      else
      ctr = yamCtrMake(label)

   ;  c +=  a
   ;  yamCtrSet(ctr, c)

   ;  return seg
;  }

/*
 * Dependency with yamRefMember. Agreement:
 * it only returns NULL if second arg not in [ntlcm].
*/

yamSeg*  expandRef2
(  yamSeg* seg
)
   {
      const char* member   =  yamRefMember(arg1_g, *(arg2_g->str+0))
   ;  mcxTing* memtxt      =  member ? mcxTingNew(member) : NULL

   ;  if (!memtxt)
      yamExit("\\ref#2", "second argument invalid (not in [ntlcm]")

   ;  return yamSegPush(seg, memtxt)
;  }


yamSeg*  expandPush0
(  yamSeg* seg
)
   {  yamScopePush('u')
   ;  return seg
;  }


yamSeg*  expandPop0
(  yamSeg* seg
)
   {  yamScopePop('u')
   ;  return seg
;  }


yamSeg*  expandExit0
(  yamSeg* seg
)
   {  fprintf(stderr, "___ premature exit enforced\n___ Goodbye world\n")
   ;  exit(1)
;  }


yamSeg*  expandQuit0
(  yamSeg* seg
)
   {
      while (seg)
      {
         yamSeg* prev_seg  =  seg
      ;  seg               =  seg->prev
      ;  yamSegFree(&prev_seg)
   ;  }
   ;  return NULL
;  }


yamSeg* expandTrace1
(  yamSeg*   seg
)
   {  mcxTing* t =  mcxTingNew(arg1_g->str)
   ;  static int tracing_prev = 0
   ;  int val

   ;  yamDigest(t,t)
   ;  val = atoi(t->str)

   ;  if (val == -3)
      tracing_prev = yamTracingSet(tracing_prev)
   ;  else
      tracing_prev = yamTracingSet(val)

   ;  mcxTingFree(&t)
   ;  return seg
;  }


yamSeg* expandEnv3
(  yamSeg*   seg
)
   {  yamEnvNew(arg1_g->str, arg2_g->str, arg3_g->str)
   ;  return seg
;  }


yamSeg* expandBegin1
(  yamSeg*   seg
)
   {  yamScopePush('$')          /* localize everything */
   ;  {  const char* b = yamEnvOpenScope(arg1_g, seg)
      ;  mcxTing* val = b ? mcxTingNew(b) : NULL

      ;  if (!val)
         yamExit("\\begin#2", "env <%s> not found", arg1_g->str)
      ;  return yamSegPush(seg, val)
   ;  }
      return NULL
;  }


yamSeg* expandEnd1
(  yamSeg*   seg
)
   {  const char* e  =  yamEnvCloseScope(arg1_g->str, seg)
   ;  mcxTing* val   =  e ? mcxTingNew(e) : NULL

   ;  if (!val)
      yamExit("\\end#2", "env <%s> not found\n", arg1_g->str)
   ;  yamDigest(val, val)     /* must eval now, because we need to pop here */
   ;  yamScopePop('$')           /* no trailing garbage */
   ;  return yamSegPush(seg, val)
;  }


void keySet
(  mcxbool  warn
,  mcxbool  expand
)
   {  mcxTing*  key        =  mcxTingNew(arg1_g->str)
   ;  int keylen           =  checkusrsig(key->str, key->len, NULL)
   ;  const char* me       =  warn ? "\\def#2" : expand ? "\\setx#2" : "\\set#2"
   ;  mcxTing*  valtxt     =  expand ? mcxTingNew(arg2_g->str) : arg2_g

   ;  if (keylen < 0 || keylen != key->len)
      yamExit(me, "not a valid key signature: <%s>\n", key->str)

   ;  if (mcxHashSearch(key, yamTable_g, MCX_DATUM_FIND))
      yamExit(me, "key tagged <%s> is a zoem primitive\n", key->str)

   ;  if (expand)
      yamDigest(valtxt, valtxt)

   ;  if (yamKeyInsert(key, valtxt->str) != key)
      {  if (warn)
         fprintf(stderr, "___ overwriting key <%s>\n",key->str)
      ;  mcxTingFree(&key)
   ;  }

   ;  if (expand)
      mcxTingFree(&valtxt)
;  }


yamSeg* expandSet2
(  yamSeg*   seg
)
   {  keySet(FALSE, FALSE)     /* warn: no, expand: no */
   ;  return seg
;  }


yamSeg* expandDef2
(  yamSeg*   seg
)
   {  keySet(TRUE, FALSE)      /* warn: yes, expand: no */
   ;  return seg
;  }


yamSeg* expandSetx2
(  yamSeg*  seg
)
   {  keySet(FALSE, TRUE)      /* warn: no, expand: yes */
   ;  return seg
;  }


void yamOpsStats
(  void
)
   {  mcxHashStats(yamTable_g)
;  }


mcxstatus readFile
(  mcxTing*  fname
,  mcxTing*  filetxt
)
   {  mcxIOstream *xf

   ;  if (fname->len > 123)
      yamExit
      ("readFile", "[readFile] input file name expansion too long (>123)\n")

   ;  if (yamInlineFile(fname, filetxt))
      return STATUS_OK

   ;  else
      {  xf =  mcxIOstreamNew(fname->str, "r")

      ;  if (mcxIOstreamOpen(xf, RETURN_ON_FAIL) != STATUS_OK)
         {
            mcxIOstreamFree(&xf)
         ;  mcxTingEmpty(filetxt, 0)
         ;  return STATUS_FAIL
      ;  }
      ;  yamReadFile(xf, filetxt, 0)
      ;  mcxIOstreamFree(&xf)
      ;  return STATUS_OK
   ;  }

   ;  return STATUS_FAIL
;  }


void yamOpsInitialize
(  int   n
)
   {  cmdHook* cmdhook     =  cmdHookDir

   ;  devtxt_g             =  mcxTingNew("$device")
   ;  yamTable_g           =  mcxHashNew(n, mcxTingCThash, mcxTingCmp)

   ;  while (cmdhook && cmdhook->name)
      {
         mcxTing*  cmdtxt  =  mcxTingNew(cmdhook->name)
      ;  mcxKV*   kv       =  mcxHashSearch(cmdtxt,yamTable_g,MCX_DATUM_INSERT)
      ;  kv->val           =  cmdhook
      ;  cmdhook++
   ;  }
;  }

void yamOpsMakeComposites
(  void
)
   {  mcxTing*  composites  =  mcxTingNew(strComposites)
   ;  yamDigest(composites, composites)  
   ;  mcxTingFree(&composites)
;  }


xpnfnc yamOpGet
(  mcxTing* txt
)
   {  mcxKV* kv = mcxHashSearch(txt, yamTable_g, MCX_DATUM_FIND)
   ;  if (kv)
      return ((cmdHook*) kv->val)->yamfunc

   ;  return NULL
;  }

