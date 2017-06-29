#include <stdio.h>
#include <stdlib.h>
/* If min and max are -1 then link refers to a collation_key */
struct sub_node {
    int codepoint;
    int min;
    int max;
    int sub_node_elems;
    int sub_node_link;
    int collation_key_elems;
    int collation_key_link;
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
#define main_nodes_elems 1
sub_node main_nodes[1] = {
{4018,3953,3968,2,0,0,0}};

#define sub_nodes_elems 8
sub_node sub_nodes[8] = {
{3953,3953,3968,2,1,-1,-1},{3953,3968,3968,1,2,-1,-1},{3968,-1,-1,0,-1,1,0},
{3968,-1,-1,0,-1,1,1},{3968,3953,3968,2,5,-1,-1},{3953,3968,3968,1,6,-1,-1},
{3968,-1,-1,0,-1,1,2},{3968,-1,-1,0,-1,1,3}};

#define special_collation_keys_elems 4
collation_key special_collation_keys[4] = {
{11902,32,2,0},{11901,32,2,0},{11902,32,2,0},{11901,32,2,0}};

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
        result = my_main_node.sub_node_link;
        printf("result %i\n", result);
        if (sub_nodes[result].codepoint != cp[start_cp_array_elem]) {
            printf("Error subnode[%i].codepoint should have equaled %i\n", result, cp[start_cp_array_elem]);
            return -1;
        }
        return get_first_subnode_elem(sub_nodes[result], cp, start_cp_array_elem+1, cp_array_length, result);
    }
    /* If it matches min, then we know to go to sub_node_link */
    /* Removing this will cause floating point divide by zero error */
    if (cp[start_cp_array_elem] == my_main_node.min) {
        printf("cp %i equals my_main_node.min %i. Check if codepoint matches for next node (it should otherwise there's an error). Nextcodepoint is %i\n",
            cp[start_cp_array_elem], my_main_node.min, sub_nodes[my_main_node.sub_node_link].codepoint);
        if (cp[start_cp_array_elem] == sub_nodes[my_main_node.sub_node_link].codepoint) {
            result = my_main_node.sub_node_link;
            return get_first_subnode_elem(sub_nodes[result], cp, start_cp_array_elem+1, cp_array_length, result);
        }
        return -1;
    }
    /* If it matches max then we know to go to sub_node_link + sub_node_elems */
    /* Probably shouldn't remove this. Could cause math errors as in the above conditional */
    if (cp[start_cp_array_elem] == my_main_node.max) {
        printf("cp %i equals my_main_node.max %i. Check if codepoint matches for next node + node elems(it should otherwise there's an error). Nextcodepoint is %i\n",
            cp[start_cp_array_elem], my_main_node.max, sub_nodes[my_main_node.sub_node_link + my_main_node.sub_node_elems].codepoint);
        if (cp[start_cp_array_elem] == sub_nodes[my_main_node.sub_node_link + my_main_node.sub_node_elems].codepoint) {
            result = my_main_node.sub_node_link + my_main_node.sub_node_elems;
            return get_first_subnode_elem(sub_nodes[result], cp, start_cp_array_elem+1, cp_array_length, result);
        }
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
        for (i = result + 1 ; i < my_main_node.sub_node_link + my_main_node.sub_node_elems; i++) {
            printf("Trying node index %i\n", i);
            if (sub_nodes[i].codepoint == cp[start_cp_array_elem]) {
                result = i;
                return get_first_subnode_elem(sub_nodes[result], cp, start_cp_array_elem+1, cp_array_length, result);
            }
            /* The codpoint doesn't exist in this case */
            if (cp[start_cp_array_elem] < sub_nodes[i].codepoint)
                return -1;
        }
    }
    /* Search backward */
    if (cp[start_cp_array_elem] < sub_nodes[result].codepoint) {
        int i;
        printf("The current cp is less than the node %i I found\n", result);
        for (i = result - 1 ; my_main_node.sub_node_link < i; i--) {
            if (sub_nodes[i].codepoint == cp[start_cp_array_elem]) {
                result = i;
                return get_first_subnode_elem(sub_nodes[result], cp, start_cp_array_elem+1, cp_array_length, result);
            }
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
    collation_element_start = sub_nodes[terminal_subnode].collation_key_link;
    printf("collation array start %i collation elements total: %i\n", collation_element_start, collation_element_elems);
    for (i = collation_element_start; i < collation_element_start + collation_element_elems; i++) {
        printf("[%i.%i.%i]", special_collation_keys[i].primary, special_collation_keys[i].secondary, special_collation_keys[i].tertiary);
    }
    printf("\n");
    return 1;
}
int main (void) {
    int cp[2] = {4018, 3968};
    int cp_elems = 2;
    get_collation_elements(cp, cp_elems);

    return 0;
}
