typedef struct Decompressor {
    /* Encoding an entry gives us three "commands" that can be a character or
     * something in a further shift level. Hold them in here for future
     * consumption. */
    int16_t queue[6];
    /* How many valid entries are currently in the queue? */
    uint16_t queue_len;

    const uint16_t * input_position;

    /* Were we signalled to end reading this string and continue with the next one? */
    uint8_t eos_signalled;

    uint8_t out_buf_pos;

    /* We put our characters here. */
    char out_buf[LONGEST_NAME + 1];
} Decompressor;

void digest_one_chunk(Decompressor *ds) {
    uint16_t num = *(ds->input_position++);
    uint32_t temp;
    temp = num / 1600;
    ds->queue[ds->queue_len++] = temp;
    ds->queue[ds->queue_len++] = (num - temp * 1600) / 40;
    ds->queue[ds->queue_len++] = num % 40;
    /*fprintf(stderr, "digest one chunk, %d -> %d %d %d\n", num, ds->queue[ds->queue_len - 3], ds->queue[ds->queue_len - 2], ds->queue[ds->queue_len - 1]);*/
}

void eat_a_string( Decompressor *ds, uint32_t skip_no_cp ) {
    ds->eos_signalled = 0;
    /* We're looking for a zero to start with, we are probably trying to
    * look up a specific codepoint's name */
   if (skip_no_cp) {
       fprintf(stderr, "Have been asked to skip %lu cp's\n", skip_no_cp);
   }
    while (!ds->eos_signalled) {
        /*fprintf(stderr, "start of loop: %d codemes in queue\n", ds->queue_len);*/
        if (ds->queue_len == 0) { digest_one_chunk(ds); }
        if (ds->queue[0] == 39) {
            if (ds->queue_len == 1) { digest_one_chunk(ds); }

            /* Assume it's shifted by one */
            /* XXX too tired to check if the n parameter actually prevents buffer overflows. */
            strncpy(ds->out_buf + ds->out_buf_pos, s_table[ds->queue[1]], LONGEST_NAME - ds->out_buf_pos);
            ds->out_buf_pos += strlen(s_table[ds->queue[1]]);
            /*fprintf(stderr, "concated string number %d: %s\n", ds->queue[1], s_table[ds->queue[1]]);*/

            /* Let the two codemes flow out of the queue. */
            memmove(ds->queue, ds->queue + 2, (6 - 2) * 2);
            ds->queue_len -= 2;
        }
        else {
            ds->out_buf[ds->out_buf_pos++] = ctable[ds->queue[0]];
            if (ds->queue[0] == 0) {
                ds->eos_signalled = 1;
                ds->out_buf_pos = 0;
            }
            memmove(ds->queue, ds->queue + 1, (6 - 1) * 2);
            ds->queue_len--;
        }
        /*fprintf(stderr, "out_buf_pos now %d\n", ds->out_buf_pos);*/
    }
}
uint32_t get_cp_name (uint32_t cp) {
    Decompressor ds = {};
    uint32_t ret;
    ret = get_uninames(ds.out_buf, cp);
    if (ret == 0) {
        printf("cp: %i name: %s\n", cp, ds.out_buf);
    }
    else {
        printf("ret: %i\n", ret);
        int index =  name_index[(cp - ret) / 2];
        printf("name_index[%i]=%i, cp %lu, ret %lu, cp - ret = %lu\n", (cp - ret)/2, index, cp, ret, cp - ret);
        ds.input_position = (const unsigned short *) &uninames +  index;
        printf("(cp - ret) % 2 = %i\n", (cp - ret) % 2);
        eat_a_string(&ds, ( (cp - ret) % 2) );
        printf("cp: %i name: %s\n", cp, ds.out_buf);
    }
}
int main (void) {
    uint32_t cp = 0;
    Decompressor ds = {};
    ds.input_position = (const uint16_t *) &uninames;
    int i;
    int ret;
    get_cp_name(0x20); /* U+20 SPACE */
    for (i = 0; i <= HIGHEST_NAME_CP; i++) {
        ret = get_uninames(ds.out_buf, cp);
        if (ret == 0) {
        }
        else {
            eat_a_string(&ds, 0);
        }
        printf("U+%X '%s'\n", cp, ds.out_buf);

        cp++;
    }
    return 0;
}
