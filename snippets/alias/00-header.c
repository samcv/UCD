#include <stdio.h>
#include "../3rdparty/uthash/src/uthash.h"
struct MVMUnicodeNamedAlias {
    char *name;
    int pvaluecode;
    int strlen;
};
typedef struct MVMUnicodeNamedAlias MVMUnicodeNamedAlias;
