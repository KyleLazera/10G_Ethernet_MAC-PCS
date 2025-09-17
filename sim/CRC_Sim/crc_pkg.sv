
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

    function void generate_byte_stream();
        int num_bytes;
        int i;

        /* First randomize the size of the packet ensuring it is between 64 and 1500 bytes */
        num_bytes = 8; //TODO: change to (64, 1500)

        /* Randomize the values inside the packet */
        repeat(num_bytes)
            byte_stream.push_back($urandom_range(0, 255));
    
    endfunction : generate_byte_stream

    function void convert_byte_to_32_bits();
        int num_bytes, num_words, remainder_bytes;
        crc_word_t crc_data;

        num_bytes = byte_stream.size();
        num_words = num_bytes/(DATA_WIDTH/BYTE);
        remainder_bytes = num_bytes % (DATA_WIDTH/BYTE);

        $display("Total Number of words: %0d, number of bytes: %0d, reaminder bytes: %0d", num_words, num_bytes, remainder_bytes);

        repeat(num_words) begin
            repeat(DATA_WIDTH/BYTE) begin
                crc_data.data_word = {crc_data.data_word[23:0], byte_stream.pop_front()};
                crc_data.data_valid = 4'b1111;
            end
            word_stream.push_back(crc_data);
        end

        if (remainder_bytes != 0) begin

            crc_data.data_word = '0;
            crc_data.data_valid = '0;

            repeat(remainder_bytes) begin
                crc_data.data_word = {crc_data.data_word[23:0], byte_stream.pop_front()};
                crc_data.data_valid = {crc_data.data_valid[3:1], 1'b1};
            end
            word_stream.push_back(crc_data);
        end

    endfunction : convert_byte_to_32_bits


    

endpackage : crc_pkg