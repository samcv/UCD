int test (void) {
    int cp, propcode;
    char type;
    setvbuf(stdout, 0, _IONBF, 0);
    while (1) {
        scanf("%i %c%i", &cp, &type, &propcode);
        if (type == 's') {
            printf("0x%X %c%i %s\n", cp, type, propcode, get_prop_str(cp, propcode));
        }
        else if (type == 'i') {
             printf("0x%X %c%i %s\n", cp, type, propcode, get_prop_int(cp, propcode));
        }
        else if (type == 'e') {
            printf("0x%X %c%i %s\n", cp, type, propcode, get_prop_enum(cp, propcode));
        }
    }
}
