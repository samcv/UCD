int get_chars ( unsigned short num, char *out ) {
    unsigned int temp;
    temp = num/1600;
    *out = ctable[temp];
    temp = (num - temp * 1600) / 40;
    *(out + 1) = ctable[temp];
    temp = num % 40;
    *(out + 2) = ctable[temp];
    return 0;
}

int main (void) {
    int cp = 0;
    for (int j = 0; j < uninames_elems;) {
        int len = uninames[j];
        if (len == 0) {
            j++;
            cp++;
            continue;
        }
        char string[len * 3];
        for (int i = 1; i <= len; i++) {
            get_chars(uninames[j + i],  string + (i - 1) * 3);
        }
        string[len * 3] = '\0';
        printf("U+%X '%s'\n", cp, string);
        j = j + len + 1;
        cp++;
    }
    return 0;
}
