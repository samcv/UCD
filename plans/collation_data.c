#include <stdio.h>
#include <stdlib.h>
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
    unsigned int primary;
    unsigned int secondary :7;
    unsigned int tertiary  :4;
    unsigned int special   :1;
};
typedef struct sub_node sub_node;
typedef struct main_node main_node;
typedef struct collation_key collation_key;
#define main_nodes_elems 6
//Composing array [main_nodes] type: sub_node
sub_node main_nodes[6] = {
{1513,1468,1468,1,0,0},{119226,119141,119141,1,0,3},{4018,3953,3953,1,0,6},
{119225,119141,119141,1,0,8},{4019,3953,3953,1,0,11},{119128,119141,119141,1,0,
13}};

#define sub_nodes_elems 19
//Composing array [sub_nodes] type: sub_node
sub_node sub_nodes[19] = {
{1468,1473,1474,2,-1,1},{1473,-1,-1,0,3,0},{1474,-1,-1,0,3,3},{119141,119150,
119151,2,-1,4},{119150,-1,-1,0,3,6},{119151,-1,-1,0,3,9},{3953,3968,3968,1,-1,
7},{3968,-1,-1,0,1,12},{119141,119150,119151,2,-1,9},{119150,-1,-1,0,3,13},
{119151,-1,-1,0,3,16},{3953,3968,3968,1,-1,12},{3968,-1,-1,0,1,19},{119141,
119150,119154,5,-1,14},{119150,-1,-1,0,3,20},{119151,-1,-1,0,3,23},{119152,-1,
-1,0,3,26},{119153,-1,-1,0,3,29},{119154,-1,-1,0,3,32}};

#define special_collation_keys_elems 35
//Composing array [special_collation_keys] type: collation_key
collation_key special_collation_keys[35] = {
{8907,32,2,0},{0,95,2,0},{0,94,2,0},{8907,32,2,0},{0,95,2,0},{0,93,2,0},{4442,
32,2,1},{0,0,0,0},{0,0,0,0},{4442,32,2,1},{0,0,0,0},{0,0,0,0},{11902,32,2,0},
{4441,32,2,1},{0,0,0,0},{0,0,0,0},{4441,32,2,1},{0,0,0,0},{0,0,0,0},{11904,32,2,
0},{4389,32,2,1},{0,0,0,0},{0,0,0,0},{4389,32,2,1},{0,0,0,0},{0,0,0,0},{4389,32,
2,1},{0,0,0,0},{0,0,0,0},{4389,32,2,1},{0,0,0,0},{0,0,0,0},{4389,32,2,1},{0,0,0,
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
int get_first_subnode_elem (sub_node my_main_node, int *cp, int start_cp_array_elem, int cp_array_length, int last_result) {
    printf("get_first_subnode_elem: start: %i, length: %i curr_cp: %i\n", start_cp_array_elem, cp_array_length, cp[start_cp_array_elem]);
    int result = -1;
    if (start_cp_array_elem == cp_array_length) {
        printf("I went too far. This is past the array end\nReturning the last result\n");
        return last_result;
    }
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
        return get_first_subnode_elem(sub_nodes[result], cp, start_cp_array_elem+1, cp_array_length, result);
    }
    printf("min %i max %i elems %i cp[start_cp_array_elem] %i\n", my_main_node.min, my_main_node.max, my_main_node.sub_node_elems, cp[start_cp_array_elem]);
    printf("cp[start_cp_array_elem]-min = %i max - min = %i. (%i)/( %i/(%i) )\n", cp[start_cp_array_elem] - my_main_node.min, my_main_node.max - my_main_node.min,
                                        cp[start_cp_array_elem]-my_main_node.min, my_main_node.sub_node_elems, my_main_node.max - my_main_node.min);
    result = (cp[start_cp_array_elem]-my_main_node.min)/( my_main_node.sub_node_elems/(my_main_node.max - my_main_node.min) );
    printf("The guessed element for for codepoint %i\n", sub_nodes[result].codepoint);
    if (sub_nodes[result].codepoint == cp[start_cp_array_elem])
        return result;
    /* Search forward */
    if (sub_nodes[result].codepoint < cp[start_cp_array_elem]) {
        int i;
        printf("The current cp %i is more than %i located at node index %i\n", cp[start_cp_array_elem], sub_nodes[result].codepoint, result);
        for (i = result + 1 ; i < my_main_node.link + my_main_node.sub_node_elems; i++) {
            printf("Trying node index %i\n", i);
            if (sub_nodes[i].codepoint == cp[start_cp_array_elem])
                return i;
            /* The codpoint doesn't exist in this case */
            if (cp[start_cp_array_elem] < sub_nodes[i].codepoint)
                return -1;
        }
    }
    /* Search backward */
    if (cp[start_cp_array_elem] < sub_nodes[result].codepoint) {
        int i;
        printf("The current cp is less than the node %i I found\n", result);
        for (i = result - 1 ; my_main_node.link < i; i--) {
            if (sub_nodes[i].codepoint == cp[start_cp_array_elem])
                return i;
            /* The codepoint doesn't exist in this case */
            if (sub_nodes[i].codepoint < cp[start_cp_array_elem])
                return -1;
        }
    }

    return -1;
}
int get_collation_elements (int *cp, int cp_elems) {
    int i;
    int main_node_elem = get_main_node(cp[0]);
    int terminal_subnode;
    int collation_element_elems;
    int collation_element_start;
    if (main_node_elem == -1) {
        printf("Could not find codepoint %i\n", cp[0]);
        return 0;
    }

    terminal_subnode = get_first_subnode_elem(main_nodes[main_node_elem], cp, 1, cp_elems, -1);
    printf("it could be %i element\n", terminal_subnode);
    printf("I found codepoint %i at element %i\n", sub_nodes[terminal_subnode].codepoint, terminal_subnode);
    collation_element_elems = sub_nodes[terminal_subnode].collation_key_elems;
    collation_element_start = sub_nodes[terminal_subnode].link;
    printf("collation array start %i collation elements total: %i\n", collation_element_start, collation_element_elems);
    for (i = collation_element_start; i < collation_element_start + collation_element_elems; i++) {
        printf("[%i.%i.%i]", special_collation_keys[i].primary, special_collation_keys[i].secondary, special_collation_keys[i].tertiary);
    }
    printf("\n");
    return 1;
}
int main (void) {
    int cp[3] = /*{119128, 119141, 119154}*/     {4019, 3953, 3968};
    int cp_elems = 3;
    get_collation_elements(cp, cp_elems);

    return 0;
}
