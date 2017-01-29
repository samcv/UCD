/* Returns the value stored in the bitfield for the specified cp */
#define get_cp_raw_value(cp, propname) mybitfield[point_index[cp]].propname
#define get_bool_prop(cp, propname) get_cp_raw_value(cp, propname)
/* Returns the value stored in the enum for a specified property. This will be the final property value */
#define get_enum_prop(cp, propname) propname[get_cp_raw_value(cp, propname)]

int main (void) {
