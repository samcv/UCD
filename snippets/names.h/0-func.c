typedef struct Decompressor {
    /* Encoding an entry gives us three "commands" that can be a character or
     * something in a further shift level. Hold them in here for future
     * consumption. */
    int16_t queue[6];
    /* How many valid entries are currently in the queue? */
    uint16_t queue_len;

    const unsigned short * input_position;

    /* Were we signalled to end reading this string and continue with the next one? */
    uint8_t eos_signalled;

    uint8_t out_buf_pos;

    /* We put our characters here. */
    char out_buf[LONGEST_NAME + 1];
} Decompressor;
void digest_one_chunk(Decompressor *ds);
void eat_a_string( Decompressor *ds );
char * get_uninames ( char * out, uint32_t cp );
