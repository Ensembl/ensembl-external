
/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include "util.h"
#include "parse.h"

#include "util/txt.h"
#include "util/hash.h"
#include "util/types.h"


static const char* spaces =
"                                                                           ";

/* ahem, design:
 * all the keys in a tbl are mcxTings.
 * all the vals in a tbl are dnodes.
 * all user values are stored in dnode->dat.
*/


typedef struct dnode
{
   mcxTing* dat
;  mcxHash* tbl
;
}  dnode       ;     /* data node */


                                       /* how can I do this in one step? */
static   dnode    dn__           =     { NULL, NULL } ;
static   dnode*   dnode_g        =     &dn__ ;


dnode* dnodeNew
(  const char* str
,  int n
)  ;


void dnodeFree
(  void* dnodepp
)  ;


mcxbool dnodeCut
(  dnode* dn
,  mcxTing* slot
)  ;


void dnodePrint
(  dnode* dn
,  int    level
)  ;


void yamDataSet
(  mcxTing* val
)
   {  int i
   ;  dnode* dn      =  dnode_g
   ;  mcxTing* key   =  mcxTingEmpty(NULL, 10)
   ;  mcxbool scopes =  seescope(val->str, val->len) >= 0 ? TRUE : FALSE

   ;  for (i=1;i<=n_args_g;i++)
      {  
         mcxKV* kv
      ;  if (!dn->tbl)
         dn->tbl     =  mcxHashNew(4, mcxTingHash, mcxTingCmp)
      ;  mcxTingWrite(key, key_and_args_g[i].str)
      ;  kv          =  mcxHashSearch
                        (  key
                        ,  dn->tbl
                        ,  MCX_DATUM_INSERT
                        )
      ;  if (kv->key == key)   /* autovivification, key must now be renewed */
         {  key      =  mcxTingEmpty(NULL, 10)
         ;  kv->val  =  dnodeNew(NULL, 0)
      ;  }
         dn =  (dnode*) kv->val
   ;  }

      if (scopes)
      {  
         yamSeg*  tmpseg  = yamSegPush(NULL, val)
      ;  int   x
      ;  int   ct = 0
      ;  if (!dn->tbl)
         dn->tbl = mcxHashNew(4, mcxTingHash, mcxTingCmp)

      ;  while ((x = parsescopes(tmpseg, 2, 0)) == 2)
         {  
            mcxTing* lkey  =  mcxTingNew(arg1_g->str)
         ;  mcxKV*   kv    =  mcxHashSearch(lkey, dn->tbl, MCX_DATUM_INSERT)

         ;  ct += x

         ;  if (kv->key == lkey)
            kv->val = dnodeNew(arg2_g->str, 0)
         ;  else
            {  mcxTingFree(&lkey)
            ;  mcxTingWrite(((dnode*) kv->val)->dat, arg2_g->str)
         ;  }
      ;  }

         ct += x
      ;  yamSegFree(&tmpseg)
      ;  mcxTingFree(&val)

      ;  if (ct == 1)
         {  if (dn->dat)
            {  mcxTingWrite(dn->dat, arg1_g->str)
            ;  mcxTingFree(&val)
         ;  }
            else
            dn->dat = mcxTingNew(arg1_g->str)
      ;  }
         else if (x == 1)
         yamExit
         (  "\\dset#2"
         ,  "second argument is either even vararg or simple argument\n"
            "    found 1 vararg element {%s}"
         ,  arg1_g->str  
         )
   ;  }
      else
      {  if (dn->dat)
         {  mcxTingWrite(dn->dat, val->str)
         ;  mcxTingFree(&val)
      ;  }
         else
         dn->dat = val
   ;  }

      mcxTingFree(&key)
;  }


dnode* dnodeNew
(  const char* str
,  int n
)
   {  dnode* dn      =  mcxAlloc(sizeof(dnode), EXIT_ON_FAIL)
   ;  dn->dat        =  str ? mcxTingNew(str) : NULL
   ;  dn->tbl        =  n   ? mcxHashNew(4, mcxTingHash, mcxTingCmp) : NULL
   ;  return dn
;  }


const char* yamDataGet
(  void
)
   {  int i
   ;  dnode* dn      =  dnode_g
   ;  mcxTing* key   =  mcxTingEmpty(NULL, 10)

   ;  for (i=1;i<=n_args_g;i++)
      {  mcxKV* kv
      ;  if (!dn || !dn->tbl)
         {  mcxTingFree(&key)
         ;  return NULL
      ;  }
      ;  mcxTingWrite(key, key_and_args_g[i].str)
      ;  kv          =  mcxHashSearch
                        (  key
                        ,  dn->tbl
                        ,  MCX_DATUM_FIND
                        )
      ;  if (!kv)
         {  mcxTingFree(&key)
         ;  return NULL
      ;  }
      ;  dn =  (dnode*) kv->val
   ;  }

      mcxTingFree(&key)
   ;  return dn->dat ? dn->dat->str : NULL
;  }


mcxbool yamDataFree
(  void
)
   {  int i
   ;  dnode* dn      =  dnode_g
   ;  mcxTing* key   =  mcxTingEmpty(NULL, 10)
   ;  mcxTing* slot  =  NULL
   ;  mcxbool ok     =  TRUE

   ;  for (i=1;i<n_args_g;i++)
      {  mcxKV* kv
      ;  if (!dn || !dn->tbl)
         {  mcxTingFree(&key)
         ;  return FALSE
      ;  }

         mcxTingWrite(key, key_and_args_g[i].str)
      ;  kv          =  mcxHashSearch
                        (  key
                        ,  dn->tbl
                        ,  MCX_DATUM_FIND
                        )
      ;  if (!kv)
         {  mcxTingFree(&key)
         ;  return FALSE
      ;  }
      ;  dn =  (dnode*) kv->val
   ;  }

      if (n_args_g)
      slot = mcxTingNew(key_and_args_g[n_args_g].str)
   ;  else
      slot = NULL

   ;  ok =  dnodeCut(dn, slot)

   ;  mcxTingFree(&key)
   ;  mcxTingFree(&slot)

   ;  return ok
;  }


mcxbool yamDataPrint
(  void
)
   {  int i
   ;  dnode* dn      =  dnode_g
   ;  mcxTing* key   =  mcxTingEmpty(NULL, 10)

   ;  fprintf(stdout, "# printing node <ROOT>")

   ;  for (i=1;i<=n_args_g;i++)
      {  mcxKV* kv
      ;  if (!dn || !dn->tbl)
         {  mcxTingFree(&key)
         ;  return FALSE
      ;  }
      ;  mcxTingWrite(key, key_and_args_g[i].str)
      ;  fprintf(stdout, "<%s>", key->str)
      ;  kv          =  mcxHashSearch
                        (  key
                        ,  dn->tbl
                        ,  MCX_DATUM_FIND
                        )
      ;  if (!kv)
         {  mcxTingFree(&key)
         ;  return FALSE
      ;  }
      ;  dn =  (dnode*) kv->val
   ;  }

      fprintf(stdout, "\n")
   ;  dnodePrint(dn, n_args_g)
   ;  fprintf(stdout, "# done printing data\n")
   ;  mcxTingFree(&key)
   ;  return TRUE
;  }


void dnodePrint
(  dnode* dn
,  int    level
)
   {  if (level > 74)
      {  fprintf(stdout, "%s....\n", spaces)
      ;  return
   ;  }

      if (dn->dat)
      {  fprintf(stdout, "%s", spaces+(75-level))
      ;  fprintf(stdout, "|<%s>\n", dn->dat->str)
   ;  }

   ;  if (dn->tbl)
      {  mcxHashWalk* walk = mcxHashWalkNew(dn->tbl)
      ;  mcxKV* kv

      ;  while((kv = mcxHashWalkStep(walk)))
         {  fprintf(stdout, "%s", spaces+(75-level-1))
         ;  fprintf(stdout, "*<%s>\n", ((mcxTing*) kv->key)->str)
         ;  dnodePrint((dnode*) kv->val, level+1)
      ;  }
         mcxHashWalkFree(&walk)
   ;  }
      return
;  }

/*
 * if slot exists, remove everything attached to key slot in dn->tbl.
 * otherwise, empty tbl and dat members in dn,
 * leave dn in consistent state.
*/

mcxbool dnodeCut
(  dnode* dn
,  mcxTing* slot
)
   {  if (!dn)
      return FALSE

   ;  if (slot)
      {
         mcxKV* kv   =  mcxHashSearch(slot, dn->tbl, MCX_DATUM_DELETE)
      ;  dnode* dnx  =  kv ? (dnode*) kv->val : NULL
      ;  mcxbool ok  =  kv ? dnodeCut(dnx, NULL) : FALSE
      ;  mcxTing* txt=  kv ? (mcxTing*) kv->key : NULL

      ;  mcxTingFree(&txt)
      ;  mcxKVfree(&kv)
      ;  dnodeFree(&dnx)
      ;  return ok
   ;  }
      else
      {
         mcxbool ok  =  TRUE
      ;  if (dn->dat)
         {  mcxTingFree(&(dn->dat))
      ;  }
         if (dn->tbl)
         {  mcxHashWalk* walk = mcxHashWalkNew(dn->tbl)
         ;  mcxKV* kv

         ;  while((kv = mcxHashWalkStep(walk)))
            {  dnode* dnx = (dnode*) kv->val
            ;  ok = ok && dnodeCut(dnx, NULL)
         ;  }

            mcxHashWalkFree(&walk)
         ;  mcxHashFree(&(dn->tbl), mcxTingFree_v, dnodeFree)
      ;  }
        /*  these two actions leave dnx->tbl in consistent state so that
         *  calling dnodeCut can either issue a mcxHashFree (in this branch,
         *  the (!slot) case) on the table in which dnx is a value,
         *  or it can just remove the key-value pair in which dnx is the
         *  value (in the slot! branch).
        */
         return ok
   ;  }
      return TRUE
;  }


void dnodeFree
(  void* dnodepp
)
   {  dnode* dn = *((dnode**) dnodepp)
   ;  if (dn)
      mcxFree(dn)
;  }


