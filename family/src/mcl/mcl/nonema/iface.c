/*
 *    Copyright (C) 1999-2002 Stijn van Dongen.
*/

#include <stdlib.h>
#include <stdio.h>

#include "iface.h"

#include "util/file.h"

int   mclVerbosityIoNonema             =  1;
int   mclWarningNonema                 =  1;

/*
 * all mclTrackNonemaPruning stuff is obsolete, kept because it might
 * be transfered and reinstated in mcl/compose.c
*/
int   mclTrackNonemaPruning            =  0;
int   mclTrackNonemaPruningInterval    =  1;
int   mclTrackNonemaPruningOfset       =  0;
int   mclTrackNonemaPruningBound       =  0;

int   mclVectorSizeCmp                 =  1;

int   mclMatrixFormatFound             =  'b';

mcxIOstream*   mclTrackStreamNonema    =  NULL;

