
const static int get_offset_new (uint32_t cp) {
    int i = 0;
    int return_val;
    for (;1;i++) {
        if (cp < sorted_table[i+1].low) {
            //fprintf(stderr, "i %i high %i low %i\n", i, sorted_table[i].high, sorted_table[i].low);
            if (cp >= sorted_table[i].low && cp <= sorted_table[i].high) {
                fprintf(stderr, "just right\n");
                return_val = sorted_table[i].bitfield_row;
                fprintf(stderr, "bitfield row %i\n", return_val);
                return return_val;
            }
            /* Case to catch cp's less than the first point in the table
             * eventually there should be an extra row at the beginning of the table for this? */
            else if (cp < sorted_table[i].low) {
                fprintf(stderr, "lower than lowest\n");
                return_val =  point_index[cp + 1];
                fprintf(stderr, "bitfield row %i point_index %i\n", return_val, cp + 1);
                return return_val;
            }
            else {
                fprintf(stderr, "missed %i\n", sorted_table[i].miss);
                return_val =  point_index[-1 + cp - sorted_table[i].miss];
                fprintf(stderr, "bitfield row %i point_index %i\n", return_val, cp - sorted_table[i].miss);
                return return_val;
            }
        }
    }
}
