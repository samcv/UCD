typedef struct Decompressor {
    /* Encoding an entry gives us three "commands" that can be a character or
     * something in a further shift level. Hold them in here for future
     * consumption. */
    int16_t queue[6];
    /* How many valid entries are currently in the queue? */
    unsigned short queue_len;

    const unsigned short * input_position;

    /* Were we signalled to end reading this string and continue with the next one? */
    uint8_t eos_signalled;

    uint8_t out_buf_pos;

    /* We put our characters here. */
    char out_buf[LONGEST_NAME + 1];
} Decompressor;

void digest_one_chunk(Decompressor *ds) {
    unsigned short num = *(ds->input_position++);
    unsigned int temp;
    temp = num / 1600;
    ds->queue[ds->queue_len++] = temp;
    ds->queue[ds->queue_len++] = (num - temp * 1600) / 40;
    ds->queue[ds->queue_len++] = num % 40;
    fprintf(stderr, "digest one chunk, %d -> %d %d %d\n", num, ds->queue[ds->queue_len - 3], ds->queue[ds->queue_len - 2], ds->queue[ds->queue_len - 1]);
}

void eat_a_string( Decompressor *ds ) {
    ds->eos_signalled = 0;
    while (!ds->eos_signalled) {
        fprintf(stderr, "start of loop: %d codemes in queue\n", ds->queue_len);
        if (ds->queue_len == 0) { digest_one_chunk(ds); }
        if (ds->queue[0] == 39) {
            if (ds->queue_len == 1) { digest_one_chunk(ds); }

            /* Assume it's shifted by one */
            /* XXX too tired to check if the n parameter actually prevents buffer overflows. */
            strncpy(ds->out_buf + ds->out_buf_pos, s_table[ds->queue[1]], LONGEST_NAME - ds->out_buf_pos);
            ds->out_buf_pos += strlen(s_table[ds->queue[1]]);
            fprintf(stderr, "concated string number %d: %s\n", ds->queue[1], s_table[ds->queue[1]]);

            /* Let the two codemes flow out of the queue. */
            memmove(ds->queue, ds->queue + 2, (6 - 2) * 2);
            ds->queue_len -= 2;
        } else {
            ds->out_buf[ds->out_buf_pos++] = ctable[ds->queue[0]];
            fprintf(stderr, "added character %d\n", ds->queue[0]);
            if (ds->queue[0] == 0) {
                ds->eos_signalled = 1;
                ds->out_buf_pos = 0;
                ds->queue_len = 1;
            }
            memmove(ds->queue, ds->queue + 1, (6 - 1) * 2);
            ds->queue_len--;
        }
        fprintf(stderr, "out_buf_pos now %d\n", ds->out_buf_pos);
    }
}

int main (void) {
    int cp = 0;
    Decompressor ds = {};
    ds.input_position = &uninames;
    while (ds.input_position < uninames + 30) {
        eat_a_string(&ds);
        printf("U+%X '%s'\n", cp, ds.out_buf);
        cp++;
    }
    return 0;
}
