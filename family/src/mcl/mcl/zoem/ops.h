/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef zoem_ops_h__
#define zoem_ops_h__

#include "segment.h"

#include "util/types.h"
#include "util/txt.h"

mcxbool  yamOpList
(  const char* mode
)  ;

void yamOpsStats
(  void
)  ;

void yamOpsInitialize
(  int n
)  ;

void yamOpsMakeComposites
(  void
)  ;

xpnfnc yamOpGet
(  mcxTing* txt
)  ;

yamSeg* expandSwitch2   (  yamSeg*  seg)  ;
yamSeg* expandStore2    (  yamSeg*  seg)  ;
yamSeg* expandDofile2   (  yamSeg*  seg)  ;
yamSeg* expandWrite3    (  yamSeg*  seg)  ;
yamSeg* expandSetx2     (  yamSeg*  seg)  ;
yamSeg* expandFormatted1(  yamSeg*  seg)  ;
yamSeg* expandApply2    (  yamSeg*  seg)  ;
yamSeg* expandWhile2    (  yamSeg*  seg)  ;
yamSeg* expandTable5    (  yamSeg*  seg)  ;
yamSeg* expandMeta3     (  yamSeg*  seg)  ;
yamSeg* expandBang1     (  yamSeg*  seg)  ;
yamSeg* expandBang0     (  yamSeg*  seg)  ;
yamSeg* expandRefload6  (  yamSeg*  seg)  ;
yamSeg* expandRef2      (  yamSeg*  seg)  ;
yamSeg* expandDollar2   (  yamSeg*  seg)  ;
yamSeg* expandIfdef3    (  yamSeg*  seg)  ;
yamSeg* expandIfdefl3   (  yamSeg*  seg)  ;
yamSeg* expandUndef1    (  yamSeg*  seg)  ;
yamSeg* expandIfeq4     (  yamSeg*  seg)  ;
yamSeg* expandDset2     (  yamSeg*  seg)  ;
yamSeg* expandDsetx2    (  yamSeg*  seg)  ;
yamSeg* expandDget1     (  yamSeg*  seg)  ;
yamSeg* expandDfree1    (  yamSeg*  seg)  ;
yamSeg* expandDprint1   (  yamSeg*  seg)  ;
yamSeg* expandSet2      (  yamSeg*  seg)  ;
yamSeg* expandEnv3      (  yamSeg*  seg)  ;
yamSeg* expandBegin1    (  yamSeg*  seg)  ;
yamSeg* expandEnd1      (  yamSeg*  seg)  ;
yamSeg* expandDef2      (  yamSeg*  seg)  ;
yamSeg* expandConstant1 (  yamSeg*  seg)  ;
yamSeg* expandSpecial1  (  yamSeg*  seg)  ;
yamSeg* expandQuit0     (  yamSeg*  seg)  ;
yamSeg* expandExit0     (  yamSeg*  seg)  ;
yamSeg* expandPush0     (  yamSeg*  seg)  ;
yamSeg* expandPop0      (  yamSeg*  seg)  ;
yamSeg* expandCtrset2   (  yamSeg*  seg)  ;
yamSeg* expandCtrput1   (  yamSeg*  seg)  ;
yamSeg* expandIcmp5     (  yamSeg*  seg)  ;
yamSeg* expandCtradd2   (  yamSeg*  seg)  ;
yamSeg* expandTrace1    (  yamSeg*  seg)  ;
yamSeg* expandIsum1     (  yamSeg*  seg)  ;
yamSeg* expandIclc3     (  yamSeg*  seg)  ;

#endif

