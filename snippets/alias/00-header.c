#include <stdio.h>
#include "../3rdparty/uthash/src/uthash.h"

struct MVMUnicodeNamedAlias {
    char *name;
    int pvaluecode;
    int strlen;
};
typedef struct MVMUnicodeNamedAlias MVMUnicodeNamedAlias;

struct MVMUnicodeNamedAlias_hash {
    const char *name;
    int pvaluecode;
    UT_hash_handle hh;
};
typedef struct MVMUnicodeNamedAlias_hash MVMUnicodeNamedAlias_hash;

struct hash_pre {
    MVMUnicodeNamedAlias_hash *hash;
    MVMUnicodeNamedAlias    *source;
    int elems;
};
typedef struct hash_pre hash_pre;

struct mapping_struct {
    MVMUnicodeNamedAlias *alias;
    int elems;
};
typedef struct mapping_struct mapping_struct;
