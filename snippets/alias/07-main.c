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
int normalize (char *input, char *output) {
    int strlen_ = strlen(input);
    int i, b = 0;
    for (i = 0; i < strlen_; i++) {
        if (65 <= input[i] && input[i] <= 90) {
            output[b] = input[i] + 32;
            b++;
        }
        else if (97 <= input[i] && input[i] <= 122) {
            output[b] = input[i];
            b++;
        }
    }
    output[b] = '\0';
    return b;
}
int find (MVMUnicodeNamedAlias_hash *my_hash, char *query) {
    MVMUnicodeNamedAlias_hash *kv;
    HASH_FIND(hh, my_hash, query, strlen(query), kv);
    if (!kv) {
        char new[20];
        int slen = normalize(query, new);
        fprintf(stderr, "Couldn't find %s\n", query);
        HASH_FIND(hh, my_hash, new, slen, kv);
        if (!kv) {
            fprintf(stderr, "Couldn't find %s\n", new);
            return -1;
        }
        else {
            fprintf(stderr, "Found using normalized version %s\n", new);
        }
    }
    printf("%s %i\n", query, kv->pvaluecode);
    return kv->pvaluecode;
}

int main (int argc, char *argv[]) {
    MVMUnicodeNamedAlias_hash *kv;
    MVMUnicodeNamedAlias_hash *alias_names_hash = load_hash_3(alias_names, alias_names_elems);
    char *query = "Glue_After_Zwj";
    char *property_name = "Grapheme_Cluster_Break";
    if (2 <= argc) {
        property_name = argv[1];
        query = argv[2];
    }
    int propcode = find(alias_names_hash, property_name);
    if (0 <= propcode) {
        MVMUnicodeNamedAlias_hash *pvalue_hash = load_hash_3(mapping[propcode].alias, mapping[propcode].elems);
        find(pvalue_hash, query);
        return 0;
    }
    return 1;
}
