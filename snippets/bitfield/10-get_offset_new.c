
int get_offset_new (uint32_t cp) {
    int i = 0;
    for (;1;i++) {
        if (cp < sorted_table[i+1].high) {
            printf("i %i high %i low %i\n", i, sorted_table[i].high, sorted_table[i].low);
            if (cp <= sorted_table[i].high && cp >= sorted_table[i].low) {
                return sorted_table[i].bitfield_row;
            }
            else {
                printf("missed %i\n", sorted_table[i].miss);
                return point_index[cp - sorted_table[i].miss];
            }
        }
    }
}
