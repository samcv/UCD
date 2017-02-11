    char gc[3];
    char * printf_s = "0x%X d%i [%c] GC: %s Bidi_Mirrored: %u GCB: %s(%i)\n";
    char * printf_s_control = "0x%X d%i GC: %s Bidi_Mirrored: %u GCB: %s(%i)\n";
    for (char n = '0'; n <= '9'; n++) {
        printf("U+%X [%c] Numeric_Value_Numerator: %" PRIi64 "\n", n, n, get_enum_prop(n, Numeric_Value_Numerator));
    }
    for (int i = 0; i < 'Z' + 1; i++) {
          printf("0x%X d%i get_bitfield_offset(%i)\n", i, i, get_bitfield_offset(i));
          unsigned int cp_GCB = get_bool_prop(i, Grapheme_Cluster_Break);
          get_gencat(i, gc);
          if (cp_GCB != Uni_PVal_GRAPHEME_CLUSTER_BREAK_Control ) {
              printf(printf_s, i, i, (char) i, gc, get_bool_prop(i, Bidi_Mirrored), Grapheme_Cluster_Break[cp_GCB], cp_GCB );
          }
          else {
              printf(printf_s_control, i, i, gc, get_bool_prop(i, Bidi_Mirrored), Grapheme_Cluster_Break[cp_GCB], cp_GCB );
          }
   }
