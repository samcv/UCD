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
    printf("Loaded %i elems into hash %p\n", elems, thingy);
    return users;
}
int find (MVMUnicodeNamedAlias_hash *my_hash, char *query) {
    MVMUnicodeNamedAlias_hash *kv;
    HASH_FIND(hh, my_hash, query, strlen(query), kv);
    if (!kv) {
        printf("Couldn't find %s\n", query);
        return -1;
    }
    printf("%s %i\n", query, kv->pvaluecode);
    return kv->pvaluecode;
}

int main (void) {
    MVMUnicodeNamedAlias_hash *kv;
    MVMUnicodeNamedAlias_hash *alias_names_hash = load_hash_3(alias_names, alias_names_elems);
    char *query = "Glue_After_Zwj";
    char *property_name = "Grapheme_Cluster_Break";
    int propcode = find(alias_names_hash, property_name);
    if (propcode >= 0) {
        MVMUnicodeNamedAlias_hash *pvalue_hash = load_hash_3(mapping[propcode].alias, mapping[propcode].elems);
        find(pvalue_hash, query);
    }
    return 0;
}
