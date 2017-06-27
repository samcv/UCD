#include <stdio.h>
#include <stdlib.h>
struct main_node {
    //int special_link;
    int codepoint;
    int min;
    int max;
    int elems;
    int link;
};
struct sub_node {
    int codepoint;
    int min;
    int max;
    int sub_node_elems;
    int collation_key_elems;
    int link;
};
struct collation_key {
    int primary  :16;
    int secondary :6;
    int tertiary  :4;
    int special   :1;
};
typedef struct sub_node sub_node;
typedef struct main_node main_node;
typedef struct collation_key collation_key;
#define main_nodes_elems 1
main_node main_nodes[1] = {
{3652,3585,3630,46,0}};
sub_node sub_nodes[46] = {
{3623,-1,-1,0,2,0},{3620,-1,-1,0,2,2},{3611,-1,-1,0,2,4},{3622,-1,-1,0,2,6},
{3617,-1,-1,0,2,8},{3608,-1,-1,0,2,10},{3606,-1,-1,0,2,12},{3591,-1,-1,0,2,14},
{3586,-1,-1,0,2,16},{3629,-1,-1,0,2,18},{3627,-1,-1,0,2,20},{3615,-1,-1,0,2,22},
{3609,-1,-1,0,2,24},{3600,-1,-1,0,2,26},{3599,-1,-1,0,2,28},{3597,-1,-1,0,2,30},
{3590,-1,-1,0,2,32},{3624,-1,-1,0,2,34},{3621,-1,-1,0,2,36},{3607,-1,-1,0,2,38},
{3604,-1,-1,0,2,40},{3603,-1,-1,0,2,42},{3595,-1,-1,0,2,44},{3588,-1,-1,0,2,46},
{3613,-1,-1,0,2,48},{3596,-1,-1,0,2,50},{3593,-1,-1,0,2,52},{3587,-1,-1,0,2,54},
{3630,-1,-1,0,2,56},{3628,-1,-1,0,2,58},{3619,-1,-1,0,2,60},{3612,-1,-1,0,2,62},
{3610,-1,-1,0,2,64},{3605,-1,-1,0,2,66},{3602,-1,-1,0,2,68},{3601,-1,-1,0,2,70},
{3592,-1,-1,0,2,72},{3618,-1,-1,0,2,74},{3616,-1,-1,0,2,76},{3594,-1,-1,0,2,78},
{3626,-1,-1,0,2,80},{3625,-1,-1,0,2,82},{3614,-1,-1,0,2,84},{3598,-1,-1,0,2,86},
{3589,-1,-1,0,2,88},{3585,-1,-1,0,2,90}};
collation_key special_collation_keys[] = {
{11673,32,2,0},{11697,32,2,0},{11670,32,2,0},{11697,32,2,0},{11661,32,2,0},
{11697,32,2,0},{11672,32,2,0},{11697,32,2,0},{11667,32,2,0},{11697,32,2,0},
{11658,32,2,0},{11697,32,2,0},{11656,32,2,0},{11697,32,2,0},{11641,32,2,0},
{11697,32,2,0},{11636,32,2,0},{11697,32,2,0},{11679,32,2,0},{11697,32,2,0},
{11677,32,2,0},{11697,32,2,0},{11665,32,2,0},{11697,32,2,0},{11659,32,2,0},
{11697,32,2,0},{11650,32,2,0},{11697,32,2,0},{11649,32,2,0},{11697,32,2,0},
{11647,32,2,0},{11697,32,2,0},{11640,32,2,0},{11697,32,2,0},{11674,32,2,0},
{11697,32,2,0},{11671,32,2,0},{11697,32,2,0},{11657,32,2,0},{11697,32,2,0},
{11654,32,2,0},{11697,32,2,0},{11653,32,2,0},{11697,32,2,0},{11645,32,2,0},
{11697,32,2,0},{11638,32,2,0},{11697,32,2,0},{11663,32,2,0},{11697,32,2,0},
{11646,32,2,0},{11697,32,2,0},{11643,32,2,0},{11697,32,2,0},{11637,32,2,0},
{11697,32,2,0},{11680,32,2,0},{11697,32,2,0},{11678,32,2,0},{11697,32,2,0},
{11669,32,2,0},{11697,32,2,0},{11662,32,2,0},{11697,32,2,0},{11660,32,2,0},
{11697,32,2,0},{11655,32,2,0},{11697,32,2,0},{11652,32,2,0},{11697,32,2,0},
{11651,32,2,0},{11697,32,2,0},{11642,32,2,0},{11697,32,2,0},{11668,32,2,0},
{11697,32,2,0},{11666,32,2,0},{11697,32,2,0},{11644,32,2,0},{11697,32,2,0},
{11676,32,2,0},{11697,32,2,0},{11675,32,2,0},{11697,32,2,0},{11664,32,2,0},
{11697,32,2,0},{11648,32,2,0},{11697,32,2,0},{11639,32,2,0},{11697,32,2,0},
{11635,32,2,0},{11697,32,2,0}};
int get_main_node (int cp) {
    int i;
    for (i = 0; i < main_nodes_elems; i++) {
        if (main_nodes[i].codepoint == cp) {
            return i;
        }
    }
    return -1;
}
int guess_elem (main_node my_main_node, int cp) {
    printf("min %i max %i elems %i cp %i\n", my_main_node.min, my_main_node.max, my_main_node.elems, cp);
    printf("cp-min = %i max - min = %i. (%i)/( %i/(%i) )\n", cp - my_main_node.min, my_main_node.max - my_main_node.min,
                                        cp-my_main_node.min, my_main_node.elems, my_main_node.max - my_main_node.min);
    int result =  (cp-my_main_node.min)/( my_main_node.elems/(my_main_node.max - my_main_node.min) );
    printf("The guessed element for for codepoint %i\n", sub_nodes[result].codepoint);
    if (sub_nodes[result].codepoint == cp)
        return result;
    /* If cp < sub_nodes[result].codepoint we need to search forward */
    if (cp < sub_nodes[result].codepoint) {
        int i;
        for (i = result + 1 ; i < my_main_node.link + my_main_node.elems; i++) {
            if (sub_nodes[i].codepoint == cp)
                return i;
            /* The codpoint doesn't exist in this case */
            if (sub_nodes[i].codepoint < cp)
                return -1;
        }
    }
    if (sub_nodes[result].codepoint < cp) {
        int i;
        for (i = result - 1 ; my_main_node.link < i; i--) {
            if (sub_nodes[i].codepoint == cp)
                return i;
            /* The codepoint doesn't exist in this case */
            if (cp < sub_nodes[i].codepoint)
                return -1;
        }
    }

    return -1;
}
int main (void) {
    int cp[2] = {3652, 3600};
    int main_node_elem = get_main_node(cp[0]);
    int guessed;
    if (main_node_elem != -1) {
        if (main_nodes[main_node_elem].min <= cp[1] && cp[1] <= main_nodes[main_node_elem].max) {
            printf("it could be %i element\n",
            guessed = guess_elem(main_nodes[main_node_elem], cp[1])
            );
            printf("I found codepoint %i at element %i\n", sub_nodes[guessed].codepoint, guessed);
        }
    }
    else {
        printf("Could not find codepoint %i\n", cp[0]);
    }
    return 0;
}
