/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#ifndef equate_h__
#define equate_h__

int fltCmp
(  const void*          f1
,  const void*          f2
)  ;

int fltRevCmp
(  const void*          f1
,  const void*          f2
)  ;

int intCmp
(  const void*          i1
,  const void*          i2
)  ;

int intRevCmp
(  const void*          i1
,  const void*          i2
)  ;

int intnCmp
(  const int*          i1
,  const int*          i2
,  int   n
)  ;

int intLt
(  const void*             i1
,  const void*             i2
)  ;

int intLq
(  const void*             i1
,  const void*             i2
)  ;

int intGt
(  const void*             i1
,  const void*             i2
)  ;

int intGq
(  const void*             i1
,  const void*             i2
)  ;

int fltLt
(  const void*             f1
,  const void*             f2
)  ;

int fltLq
(  const void*             f1
,  const void*             f2
)  ;

int fltGt
(  const void*             f1
,  const void*             f2
)  ;

int fltGq
(  const void*             f1
,  const void*             f2
)  ;

#endif /* EQUATE_H */

