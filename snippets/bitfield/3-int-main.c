    for (int i = 0; i < 150; i++) {
        int cp_index = (int) point_index[i];
        if ( cp_index > max_bitfield_index ) {
            printf("Character has no values we know of\n");
            return 1;
        }
        unsigned int cp_GCB = mybitfield[cp_index].Grapheme_Cluster_Break;
        char * printf_s = "U+%X [%c] Bidi_Mirrored: %i GCB: %s(%i)\n";
        char * printf_s_control = "U+%X Bidi_Mirrored: %i GCB: %s(%i)\n";
        if (cp_GCB != Uni_PVal_GRAPHEME_CLUSTER_BREAK_Control ) {
            printf(printf_s, i, (char) i, mybitfield[cp_index].Bidi_Mirrored, Grapheme_Cluster_Break[cp_GCB], cp_GCB );
        }
        else {
            printf(printf_s_control, i, mybitfield[cp_index].Bidi_Mirrored, Grapheme_Cluster_Break[cp_GCB], cp_GCB );
        }
    }
