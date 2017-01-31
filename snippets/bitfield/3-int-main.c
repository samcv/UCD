    char gc[3];
    char * printf_s = "U+%X [%c] GC: %s Bidi_Mirrored: %u GCB: %s(%i)\n";
    char * printf_s_control = "U+%X GC: %s Bidi_Mirrored: %u GCB: %s(%i)\n";
    for (char n = '0'; n <= '9'; n++) {
        printf("U+%X [%c] Numeric_Value_Numerator: %" PRIi64 "\n", n, n, get_enum_prop(n, Numeric_Value_Numerator));
    }
    printf("index %i\n", point_index['6']);
    unsigned int cp = 0x28;
    for (int i = 0; i < 150; i++) {
           int cp_index = (int) point_index[i];
           if ( cp_index > max_bitfield_index ) {
               printf("Character has no values we know of\n");
               return 1;
           }
           unsigned int cp_GCB = get_cp_raw_value(i, Grapheme_Cluster_Break);
           get_gencat(i, gc);
           if (cp_GCB != Uni_PVal_GRAPHEME_CLUSTER_BREAK_Control ) {
               printf(printf_s, i, (char) i, gc, get_bool_prop(i, Bidi_Mirrored), Grapheme_Cluster_Break[cp_GCB], cp_GCB );
           }
           else {
               printf(printf_s_control, i, gc, get_bool_prop(i, Bidi_Mirrored), Grapheme_Cluster_Break[cp_GCB], cp_GCB );
           }
    }
