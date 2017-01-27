void digest_one_chunk(Decompressor *ds) {
    uint16_t num = *(ds->input_position++);
    uint32_t temp;
    temp = num / 1600;
    ds->queue[ds->queue_len++] = temp;
    ds->queue[ds->queue_len++] = (num - temp * 1600) / 40;
    ds->queue[ds->queue_len++] = num % 40;
    /*fprintf(stderr, "digest one chunk, %d -> %d %d %d\n", num, ds->queue[ds->queue_len - 3], ds->queue[ds->queue_len - 2], ds->queue[ds->queue_len - 1]);*/
}

void eat_a_string( Decompressor *ds ) {
    ds->eos_signalled = 0;
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

int main (void) {
    int32_t cp = 0;
    Decompressor ds = {};
    ds.input_position = (const unsigned short *) &uninames;
    int i;;
    for (i = 0; i <= HIGHEST_NAME_CP; i++) {
        eat_a_string(&ds);
        if (ds.out_buf[0] == '\0') {
            get_uninames(ds.out_buf, cp);
        }
        printf("U+%X '%s'\n", cp, ds.out_buf);
        cp++;
    }
    return 0;
}
