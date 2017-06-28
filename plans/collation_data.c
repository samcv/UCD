#include <stdio.h>
#include <stdlib.h>
struct main_node {
    //int special_link;
    int codepoint;
    int min;
    int max;
    int sub_node_elems;
    int collation_key_elems;
    int link;
};
/* If min and max are -1 then link refers to a collation_key */
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
sub_node main_nodes[1] = {
{119128,119141,119141,1,0,0}};

#define sub_nodes_elems 6
sub_node sub_nodes[6] = {
{119141,119150,119154,5,0,1},{119154,-1,-1,0,3,0},{119150,-1,-1,0,3,3},{119153,
-1,-1,0,3,6},{119151,-1,-1,0,3,9},{119152,-1,-1,0,3,12}};

#define special_collation_keys_elems 15
collation_key special_collation_keys[15] = {
{4389,32,2,1},{0,0,0,0},{0,0,0,0},{4389,32,2,1},{0,0,0,0},{0,0,0,0},{4389,32,2,
1},{0,0,0,0},{0,0,0,0},{4389,32,2,1},{0,0,0,0},{0,0,0,0},{4389,32,2,1},{0,0,0,
0},{0,0,0,0}};

int get_main_node (int cp) {
    int i;
    for (i = 0; i < main_nodes_elems; i++) {
        if (main_nodes[i].codepoint == cp) {
            return i;
        }
    }
    return -1;
}
int get_first_subnode_elem (sub_node my_main_node, int *cp, int start_cp_array_elem, int cp_array_length) {
    printf("get_first_subnode_elem: start: %i, length: %i\n", start_cp_array_elem, cp_array_length);
    int result;
    if ( cp[start_cp_array_elem] < my_main_node.min || my_main_node.max < cp[start_cp_array_elem]) {
        printf("node is not a match for min or max\n");
        return -1;
    }
    /* If it passed the above check, and there's only one element, we're already know the element */
    if (my_main_node.sub_node_elems == 1) {
        result = my_main_node.link;
        printf("result %i\n", result);
        if (sub_nodes[result].codepoint != cp[start_cp_array_elem]) {
            printf("Error subnode[%i].codepoint should have equaled %i\n", result, cp[start_cp_array_elem]);
            return -1;
        }
        return get_first_subnode_elem(sub_nodes[result], cp, start_cp_array_elem+1, cp_array_length);
    }
    printf("min %i max %i elems %i cp[start_cp_array_elem] %i\n", my_main_node.min, my_main_node.max, my_main_node.sub_node_elems, cp[start_cp_array_elem]);
    printf("cp[start_cp_array_elem]-min = %i max - min = %i. (%i)/( %i/(%i) )\n", cp[start_cp_array_elem] - my_main_node.min, my_main_node.max - my_main_node.min,
                                        cp[start_cp_array_elem]-my_main_node.min, my_main_node.sub_node_elems, my_main_node.max - my_main_node.min);
    result = (cp[start_cp_array_elem]-my_main_node.min)/( my_main_node.sub_node_elems/(my_main_node.max - my_main_node.min) );
    printf("The guessed element for for codepoint %i\n", sub_nodes[result].codepoint);
    if (sub_nodes[result].codepoint == cp[start_cp_array_elem])
        return result;
    /* If cp[start_cp_array_elem] < sub_nodes[result].codepoint we need to search forward */
    if (cp[start_cp_array_elem] < sub_nodes[result].codepoint) {
        int i;
        for (i = result + 1 ; i < my_main_node.link + my_main_node.sub_node_elems; i++) {
            if (sub_nodes[i].codepoint == cp[start_cp_array_elem])
                return i;
            /* The codpoint doesn't exist in this case */
            if (sub_nodes[i].codepoint < cp[start_cp_array_elem])
                return -1;
        }
    }
    if (sub_nodes[result].codepoint < cp[start_cp_array_elem]) {
        int i;
        for (i = result - 1 ; my_main_node.link < i; i--) {
            if (sub_nodes[i].codepoint == cp[start_cp_array_elem])
                return i;
            /* The codepoint doesn't exist in this case */
            if (cp[start_cp_array_elem] < sub_nodes[i].codepoint)
                return -1;
        }
    }

    return -1;
}
int get_collation_elements (int *cp, int cp_elems) {

    int main_node_elem = get_main_node(cp[0]);
    int guessed;
    if (main_node_elem == -1) {
        printf("Could not find codepoint %i\n", cp[0]);
        return 0;
    }

    guessed = get_first_subnode_elem(main_nodes[main_node_elem], cp, 1, cp_elems);
    printf("it could be %i element\n", guessed);
    printf("I found codepoint %i at element %i\n", sub_nodes[guessed].codepoint, guessed);
    if (2 < cp_elems) {

    }

    return 1;
}
int main (void) {
    int cp[3] = {119128, 119141, 119153};
    int cp_elems = 3;
    get_collation_elements(cp, cp_elems);

    return 0;
}
