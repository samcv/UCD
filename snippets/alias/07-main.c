int main (void) {
    struct MVMUnicodeNamedAlias_hash {
        const char *name;
        int pvaluecode;
        UT_hash_handle hh;
    };
    //typedef struct MVMUnicodeNamedAlias_hash MVMUnicodeNamedAlias_hash;
    struct MVMUnicodeNamedAlias_hash *users = NULL;
    int i;
    struct MVMUnicodeNamedAlias_hash *kv;
    int found;
    char *query;
    MVMUnicodeNamedAlias *thingy = Grapheme_Cluster_Break;
    int elems = Grapheme_Cluster_Break_elems;
    for (i = 0; i < elems; i++) {
        kv = (struct MVMUnicodeNamedAlias_hash*)malloc(sizeof(struct MVMUnicodeNamedAlias_hash));
        kv->name = thingy[i].name;
        kv->pvaluecode = thingy[i].pvaluecode;
        //printf("%s %i\n", kv->name, kv->pvaluecode);
        HASH_ADD_KEYPTR(hh, users, kv->name, thingy[i].strlen, kv);
    }
    printf("searching\n");
    query = "Extend";
    HASH_FIND(hh, users, query, strlen(query), kv);
    //if (!kv) {
    //    return 1;
    //}
    printf("after\n");
    printf("%s  %i\n", query, kv->pvaluecode);
    return 0;
}
