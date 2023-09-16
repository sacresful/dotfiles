#include "config.h"

#include "block.h"
#include "util.h"

Block blocks[] = {
//    {"",	       x,     10},	
//    {"",	       x,      9},	
//    {"",	       x,      8},	
    {"sb-updates",  3600,      7},	
    {"sb-disk",	    3600,      6},	
    {"sb-memory",     10,      5},	
    {"sb-network",     0,      4},	
    {"sb-volume",      0,      3},	
    {"sb-clock",      60,      2},
    {"sb-battery",    10,      1},	
};

const unsigned short blockCount = LEN(blocks);
