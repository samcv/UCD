MVMUnicodeNamedAlias_hash* load_hash_3 (MVMUnicodeNamedAlias *thingy, int elems) {
    int i;
    MVMUnicodeNamedAlias_hash *users = NULL;
    MVMUnicodeNamedAlias_hash *kv;
    for (i = 0; i < elems; i++) {
        //fprintf(stderr, "%s %i\n", thingy[i].name, thingy[i].pvaluecode);
        kv = (MVMUnicodeNamedAlias_hash*)malloc(sizeof(MVMUnicodeNamedAlias_hash));
        kv->name = thingy[i].name;
        kv->pvaluecode = thingy[i].pvaluecode;
        HASH_ADD_KEYPTR(hh, users, kv->name, thingy[i].strlen, kv);
    }
    fprintf(stderr, "Loaded %i elems into hash %p\n", elems, users);
    return users;
}
int load_pvalue_hash (hash_pre *pre) {
    if (!pre->hash)
        pre->hash = load_hash_3(pre->source, pre->elems);
    return pre->hash ? 1 : 0;
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
int find (MVMUnicodeNamedAlias_hash *my_hash, char *query, char *text) {
    MVMUnicodeNamedAlias_hash *kv;
    HASH_FIND(hh, my_hash, query, strlen(query), kv);
    if (!kv) {
        char new[20];
        int slen = normalize(query, new);
        fprintf(stderr, "Couldn't find %s in %p\n", query, my_hash);
        HASH_FIND(hh, my_hash, new, slen, kv);
        if (!kv) {
            fprintf(stderr, "Couldn't find %s in %p\n", new, my_hash);
            return -1;
        }
        else {
            fprintf(stderr, "Found using normalized version %s\n", new);
        }
    }
    printf("%s %s %i\n", text, query, kv->pvaluecode);
    return kv->pvaluecode;
}
int lookup_propcode (char *query, hash_pre *alias_names_hash) {
    if (!alias_names_hash->hash)
        alias_names_hash->hash = load_hash_3(alias_names_hash->source, alias_names_hash->elems);
    return find(alias_names_hash->hash, query, "propcode");
}
int lookup_pvalue (int propcode, char *query) {
    if (propcode <= 0) {
        fprintf(stderr, "Can't look up propcode '%i', 0 or below not allowed\n");
        return -1;
    }
    int offset  = 0;
    int offset2 = 0;
    int final   = pvalue_meta_c_array[propcode + offset] + offset2;
    load_pvalue_hash(&mapping[ pvalue_meta_c_array[propcode + offset] + offset2 ]);
    fprintf(stderr, "pvalue_meta_c_array[propcode + %i] = ", offset);
    fprintf(stderr, "pvalue_meta_c_array[%i + %i = %i] = %i \n\t=> mapping[%i + %i] = mapping[%i]\n",
        propcode,
        offset,
        propcode + offset,
        pvalue_meta_c_array[propcode + offset],
        pvalue_meta_c_array[propcode + offset],
        offset2,
        final
    );
    return find(mapping[ pvalue_meta_c_array[propcode + offset] + offset2 ].hash, query, "pvalue");
}
int main (int argc, char *argv[]) {
    MVMUnicodeNamedAlias_hash *kv;
    char *query = "Glue_After_Zwj";
    char *property_name = "Grapheme_Cluster_Break";
    if (2 <= argc) {
        property_name = argv[1];
        if (2 < argc) query = argv[2];
    }
    int propcode = lookup_propcode(property_name, &alias_names_hash);
    if (0 < propcode && 2 < argc) {
        lookup_pvalue(propcode, query);
        return 0;
    }
    return 1;
}
