
#include <stdlib.h>
#include <stdio.h>
#include "nonema/iface.h"
#include "util/file.h"

int   mcxVerbosityIoNonema             =  1;
int   mcxWarningNonema                 =  1;

/*
 * all mcxTrackNonemaPruning stuff is obsolete, kept because it might
 * be transfered and reinstated in mcl/compose.c
*/
int   mcxTrackNonemaPruning            =  0;
int   mcxTrackNonemaPruningInterval    =  1;
int   mcxTrackNonemaPruningOfset       =  0;
int   mcxTrackNonemaPruningBound       =  0;

int   mcxVectorSizeCmp                 =  1;

int   mcxMatrixFormatFound             =  'b';




mcxIOstream*   mcxTrackStreamNonema    =  NULL;

