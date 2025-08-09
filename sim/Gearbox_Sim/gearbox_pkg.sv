
package gearbox_pkg;

    /* Parameters */
    parameter DATA_WIDTH = 32;
    parameter HDR_WIDTH = 2;

    /* Queue Declarations */
    logic ref_model[$];

    /* Synchronization Events */
    event data_transmitted;

    /* Variables/Structs */
    typedef struct{
        logic [HDR_WIDTH-1:0] sync_hdr;
        logic [DATA_WIDTH-1:0] data_word [1:0];
    } encoded_data_t;

    /*
     * This function is used to simulate data that comes directly from
     * the 64b/66b encoder. It generates data in the following format:
     *
     *  {Header[1:0], Data[63:0]}
     *
     * The function randomly generates the contents of these individual 
     * components and then stores the individual bits in the ref_model queue. 
     * They are stored as bits and not as words so that when we compare our actual 
     * data with the expected data, we can always extract the last 32 bits
     * without having to perform further processing.
     *
     * The bits are formatted in the ref_model queue like so:
     *
     *  {Data[63:0], Header[1:0]}
     *
     * The function also returns the encapsulated 66 bit block so that we can 
     * transmit each component to the DUT.
    */
    function encoded_data_t generate_data();

        encoded_data_t encoded_data;

        // Randomize the Header & Add this to the end of the queue
        encoded_data.sync_hdr = $urandom_range(1, 2);
        ref_model.push_front(encoded_data.sync_hdr[0]);
        ref_model.push_front(encoded_data.sync_hdr[1]);

        foreach(encoded_data.data_word[i]) begin
            encoded_data.data_word[i] = $urandom();
            for(int j = 0; j < 32; j++)
                ref_model.push_front(encoded_data.data_word[i][j]);
            end

        // Return the 66 bit data to be passed to the DUT
        return encoded_data;

    endfunction : generate_data


endpackage : gearbox_pkg
