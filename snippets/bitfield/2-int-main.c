
const static int get_gencat ( uint32_t cp, char * gc) {
    gc[2] = '\0';
    gc[0] = get_enum_prop(cp, General_Category_1);
    gc[1] =  get_enum_prop(cp, General_Category_2);
    return 1;
}

int main (void) {
