
const static int get_offset_new (uint32_t cp) {
    int i = 0;
    for (;1;i++) {
        if (cp < sorted_table[i+1].low) {
            //printf("i %i high %i low %i\n", i, sorted_table[i].high, sorted_table[i].low);
            if (cp >= sorted_table[i].low && cp <= sorted_table[i].high) {
                return sorted_table[i].bitfield_row;
            }
            /* Case to catch cp's less than the first point in the table
             * eventually there should be an extra row at the beginning of the table for this? */
            else if (cp < sorted_table[i].low) {
                //fprintf(stderr, "lower than lowest\n");
                return point_index[cp];
            }
            else {
                //printf("missed %i\n", sorted_table[i].miss);
                return point_index[cp - sorted_table[i].miss];
            }
        }
    }
}
