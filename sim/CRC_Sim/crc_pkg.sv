
package crc_pkg;

    /* Parameters */
    localparam DATA_WIDTH = 32;
    localparam CRC_WIDTH = 32;
    localparam TABLE_DEPTH = (2**DATA_WIDTH);
    localparam POLY = 32'h04C11DB7;

    localparam BYTE = 8;
    localparam DATA_BYTES = DATA_WIDTH/BYTE;

    typedef struct{
        logic [DATA_WIDTH-1:0] data_word;
        logic [DATA_BYTES-1:0] data_valid;
    } crc_word_t;

    logic [BYTE-1:0]    byte_stream[$];
    crc_word_t          word_stream[$];

    logic [CRC_WIDTH-1:0] crc_lut [TABLE_DEPTH-1:0];

    function void generate_byte_stream();
        int num_bytes;
        int i;

        /* First randomize the size of the packet ensuring it is between 64 and 1500 bytes */
        num_bytes = 5; //TODO: change to (64, 1500)

        /* Randomize the values inside the packet */
        repeat(num_bytes)
            byte_stream.push_back($urandom_range(0, 255));
    
    endfunction : generate_byte_stream

    function void convert_byte_to_32_bits();
        int num_bytes, num_words, remainder_bytes;
        crc_word_t crc_data;

        num_bytes = byte_stream.size();
        num_words = num_bytes/DATA_WIDTH;
        remainder_bytes = num_bytes % DATA_WIDTH;

        repeat(num_words) begin
            crc_data.data_word = {crc_data.data_word[23:0], byte_stream.pop_front()};
            crc_data.data_valid = 4'b1111;
            word_stream.push_back(crc_data);
        end

        if (remainder_bytes != 0) begin

            crc_data.data_word = '0;
            crc_data.data_valid = '0;

            repeat(4 - remainder_bytes) begin
                crc_data.data_word = {byte_stream.pop_front(), crc_data.data_word[31:8]};
                crc_data.data_valid = {1'b1, crc_data.data_valid[3:1]};
            end
            word_stream.push_back(crc_data);
        end

    endfunction : convert_byte_to_32_bits

    function automatic [31:0] crc32_reference_model(logic [BYTE-1:0] i_byte_stream[$]);

        /* Intermediary Signals */
        reg [31:0] crc_state = 32'hFFFFFFFF;
        reg [31:0] crc_state_rev;
        reg [7:0] i_byte_rev, table_index;
        integer i;

        //Iterate through each byte in the stream
        foreach(i_byte_stream[i]) begin
             /* Reverse the bit order of the byte in question */
             i_byte_rev = 0;
             for(int j = 0; j < 8; j++)
                i_byte_rev[j] = i_byte_stream[i][(DATA_WIDTH-1)-j];

             /* XOR this value with the MSB of teh current CRC State */
             table_index = i_byte_rev ^ crc_state[31:24];

             /* Index into the LUT and XOR the output with the shifted CRC */
             crc_state = {crc_state[24:0], 8'h0} ^ crc_lut[table_index];
        end

        /* Reverse & Invert the final CRC State after all bytes have been iterated through */
        crc_state_rev = 32'h0;
        for(int k = 0; k < 32; k++) 
            crc_state_rev[k] = crc_state[(CRC_WIDTH-1)-k];

        crc32_reference_model = ~crc_state_rev;

    endfunction : crc32_reference_model
    

endpackage : crc_pkg