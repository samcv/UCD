struct MVMUnicodeNamedAlias_hash {
    const char *name;
    int pvaluecode;
    UT_hash_handle hh;
};
typedef struct MVMUnicodeNamedAlias_hash MVMUnicodeNamedAlias_hash;
MVMUnicodeNamedAlias_hash* load_hash_3 (MVMUnicodeNamedAlias *thingy, int elems) {
    int i;
    struct MVMUnicodeNamedAlias_hash *users = NULL;
    struct MVMUnicodeNamedAlias_hash *kv;
    for (i = 0; i < elems; i++) {
        kv = (struct MVMUnicodeNamedAlias_hash*)malloc(sizeof(struct MVMUnicodeNamedAlias_hash));
        kv->name = thingy[i].name;
        kv->pvaluecode = thingy[i].pvaluecode;
        HASH_ADD_KEYPTR(hh, users, kv->name, thingy[i].strlen, kv);
    }
    return users;
}
int main (void) {
    MVMUnicodeNamedAlias_hash *users = load_hash_3(mapping[20].alias, mapping[20].elems);
    MVMUnicodeNamedAlias_hash *kv;
    int found;
    char *query;
    printf("searching\n");
    query = "Extend";
    HASH_FIND(hh, users, query, strlen(query), kv);
    if (!kv) {
        return 1;
    }
    printf("after\n");
    printf("%s  %i\n", query, kv->pvaluecode);
    return 0;
}
