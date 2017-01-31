/* Returns the value stored in the bitfield for the specified cp */
#define get_cp_raw_value(cp, propname) mybitfield[point_index[cp]].propname
#define get_bool_prop(cp, propname) get_cp_raw_value(cp, propname)
/* Returns the value stored in the enum for a specified property. This will be the final property value */
#define get_enum_prop(cp, propname) propname[get_cp_raw_value(cp, propname)]

int get_gencat ( uint32_t cp ) {
    char gc[3];
    gc[2] = '\0';
    gc[0] = get_enum_prop(cp, General_Category_1);
    gc[1] =  get_enum_prop(cp, General_Category_2);
    printf("%i", get_enum_prop(cp, General_Category_1));
    printf("gencat %s\n", gc);
}

int main (void) {
