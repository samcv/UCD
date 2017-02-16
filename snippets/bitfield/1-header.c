const static int get_offset_new (uint32_t cp);
/* Returns the value stored in the bitfield for the specified cp */
#define get_cp_raw_value(cp, propname) \
mybitfield[ \
    get_offset_new(cp) \
].propname

/* Returns a Boolean property's value */
#define get_bool_prop(cp, propname) \
get_cp_raw_value(cp, propname)

/* Returns the value stored in the enum for a specified property. This will be the final property value */
#define get_enum_prop(cp, propname) \
propname[ \
    get_cp_raw_value( \
        cp, propname \
    ) \
]
