#include <stdio.h>
#define NULL ((void *)0)
char table[40]= {
  '\0','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o',
  'p','q','r','s','t','u','v','w','x','y','z','0','1','2','3','4',
  '5','6','7','8','9',' ','\n', '\0'
};

unsigned short uninames[8] = {7,32329,31889,31881,60005,31237,31218,14960};
int get_chars ( unsigned short num, char *out ) {
    unsigned int temp;
    temp = num/1600;
    *out = table[temp];
    temp = (num - temp * 1600) / 40;
    *(out + 1) = table[temp];
    temp = num % 40;
    *(out + 2) = table[temp];
    return 0;
}

int main (void) {
    int len = uninames[0];
    char string[len *3];
    for (int i = 1; i <= len; i++) {
        get_chars(uninames[i],  string + (i-1) * 3);
    }
    string[len * 4] = '\0';
    printf("'%s'\n", string);
    return 0;
}
