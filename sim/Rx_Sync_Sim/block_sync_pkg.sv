

package block_sync_pkg;

    /* Parameters */
    parameter DATA_WIDTH = 32;
    parameter HDR_WIDTH = 2;

    /* Variables/Structs */
    typedef struct{
        logic [HDR_WIDTH-1:0] sync_hdr;
        logic [DATA_WIDTH-1:0] data_word [1:0];
    } encoded_data_t;

    /* Data Queues */
    encoded_data_t ref_model[$];
    logic data_stream[$];

    /* Synchronization Events */
    event data_transmitted;

    //---------------------------------------------------------------------
    // This function generates a 66 bit block of data in the format output
    // by a 64b/66b encoder:
    //
    //  {data_words[65:2], sync_hdr[1:0]}
    //
    // It then appends each bit from this block into a data_stream queue
    // for data transmission & adds the full encoded data to a reference 
    // queue for comparison.
    //---------------------------------------------------------------------
    function void generate_66b_block();

        encoded_data_t data;
        int i,j;

        // Randomize sync header & append bits to data stream
        data.sync_hdr = $urandom_range(1, 2);
        data_stream.push_front(data.sync_hdr[0]);
        data_stream.push_front(data.sync_hdr[1]);

        // Randomize data words and push into data stream queue
        for(i = 0; i < 2; i++) begin
            data.data_word[i] = $urandom;
            for(j = 0; j < 32; j++)
                data_stream.push_front(data.data_word[i][j]);
        end

        // Append generated data to ref queue
        ref_model.push_front(data);

    endfunction : generate_66b_block


endpackage : block_sync_pkg