
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

    function automatic [7:0] reverse_byte(logic [7:0] i_byte);
        return {i_byte[0], i_byte[1], i_byte[2], i_byte[3],  i_byte[4], i_byte[5], i_byte[6], i_byte[7]};
    endfunction : reverse_byte

    function void generate_word_stream(int num_bytes, ref crc_word_t word_stream[$]);
        crc_word_t data;
        int num_words, remainder_bytes;
        int i;
        
        num_words = num_bytes/(DATA_WIDTH/BYTE);
        remainder_bytes = num_bytes % (DATA_WIDTH/BYTE);

        repeat(num_words) begin
            data.data_word = $random;
            data.data_valid = 4'hF;
            word_stream.push_front(data);
        end

        if (remainder_bytes != 0) begin
            data.data_word = $random;
            data.data_valid = 0;

            repeat(remainder_bytes)
                data.data_valid = {data.data_valid[2:0], 1'b1};

            word_stream.push_front(data);
        end
    
    endfunction : generate_word_stream

    // --------------------------------------------------------------
    // This is a CRc32 reference model based on Sarwates algorithm.
    // This algorithm operates byte-by-byte and utilizes a singular
    // LUT to calculate the CRc32 for a byte-stream. This is a simpler
    // algorithm to implement and test when compared to the slicing-by-N
    // algorithm so I initialy created this as a reference.
    // --------------------------------------------------------------
    function automatic [31:0] crc32_sarwate_ref_model(
        crc_word_t i_word_stream[$], 
        logic [CRC_WIDTH-1:0] lut [255:0]
    );
        logic [31:0] crc_state = 32'hFFFFFFFF;
        logic [7:0]  table_index;
        logic [7:0]  curr_byte;
        crc_word_t crc_data;
        integer i, b;

        repeat(i_word_stream.size()) begin

            crc_data = i_word_stream.pop_back();

            // Process each 32-bit word byte-by-byte, starting with LSB (Byte0 on wire)
            for (b = 0; b < 4; b++) begin
                if (crc_data.data_valid[b]) begin
                    curr_byte = crc_data.data_word[8*b +: 8];

                    // Standard Sarwate update, LSB-first, LUT contains reflected values
                    table_index = curr_byte ^ crc_state[7:0];
                    crc_state   = (crc_state >> 8) ^ lut[table_index];
                end
            end
        end

        // Invert at the end (no final reflection since LUT is already reflected)
        crc32_sarwate_ref_model = ~crc_state;
    endfunction : crc32_sarwate_ref_model

    // --------------------------------------------------------------
    // This function is intended to serve as a software model for the 
    // Slicing-by-4 algorithm. This was used to test the algorithm and 
    // compare the outputs to the sarwate algorithm to ensure it
    // can correctly compute all values.
    // --------------------------------------------------------------
    function automatic logic [31:0] crc32_slicing_by_4(
        crc_word_t word_stream[$],
        logic [CRC_WIDTH-1:0] lut [3:0][255:0]
    );
        logic [31:0] crc_state, crc_calc;
        logic [7:0] b0, b1, b2, b3;
        crc_word_t crc_data;
        
        int valid_data = 0;

        // Initialize CRC to all 1s
        crc_state = 32'hFFFF_FFFF;

        repeat(word_stream.size()) begin
            logic [31:0] data_word;
            logic [3:0] data_valid;            
            valid_data = 0;

            crc_data = word_stream.pop_back();

            data_word = crc_data.data_word;
            data_valid = crc_data.data_valid;

            // Split the word into 4 bytes, LSB first
            b0 = data_word[7:0];
            b1 = data_word[15:8];
            b2 = data_word[23:16];
            b3 = data_word[31:24];

            // Count how many valid bytes are in the input word
            for(int i =0 ; i < 4; i++)
                if (data_valid[i])
                    valid_data++;

            // ------------------------------------------------------------------
            // The slicing algorithm works as follows:
            //  1) Isolate individual bytes within the 32-bit word
            //  2) Perfom XOR operation between each byte and the 
            //      corresponding byte within the crc state. 
            //      Ex: data_word[7:0] ^ crc_state[7:0]
            //          data_word[15:8] ^ crc_state[15:8]
            //          etc...
            //  3) The outputs of step 2 are the indeces used for each
            //      of the look up tables previously generated.
            //  4) Starting with the most significant valid byte of the 
            //      data word, start by indexing into LUT0 using the output.
            //      Then use teh next most sig valid byte into LUT1 then the 
            //      next into lut 2 and so on.
            //  5) Each LUT output then needs to be XORed with themeslves
            //      like so: 
            //      crc_calc = lut[3][b0] ^ lut[2][b1] ^ lut[1][b2] ^ lut[0][b3];
            //  6) Lastly, the FULL CRC state must be updated (all 32 bits) after
            //      every calculation. If valid bytes < 4, we need to XOR current
            //      CR state with a bit-shifted version of itself.
            //      Number of shift shifts can be determined using: 8*valid_bytes
            //  7) Invert the final output (equivelent to XORing with 0xFFFFFFF)
            // ------------------------------------------------------------------
            crc_calc = 0;
            if (valid_data == 4) begin
                b0 = b0 ^ (crc_state       & 8'hFF);
                b1 = b1 ^ ((crc_state>>8)  & 8'hFF);
                b2 = b2 ^ ((crc_state>>16) & 8'hFF);
                b3 = b3 ^ ((crc_state>>24) & 8'hFF);

                crc_calc = lut[3][b0] ^ lut[2][b1] ^ lut[1][b2] ^ lut[0][b3];
            end else if (valid_data == 3) begin
                b0 = b0 ^ (crc_state       & 8'hFF);
                b1 = b1 ^ ((crc_state>>8)  & 8'hFF);
                b2 = b2 ^ ((crc_state>>16) & 8'hFF);

                crc_calc = lut[2][b0] ^ lut[1][b1] ^ lut[0][b2];

                crc_calc = crc_calc ^ (crc_state >> 24);            
            end else if (valid_data == 2) begin
                b0 = b0 ^ (crc_state       & 8'hFF);
                b1 = b1 ^ ((crc_state>>8)  & 8'hFF);

                crc_calc = lut[1][b0] ^ lut[0][b1];

                crc_calc = crc_calc ^ (crc_state >> 16);
            end else begin
                b0 = b0 ^ (crc_state       & 8'hFF);

                crc_calc = lut[0][b0];

                crc_calc = crc_calc ^ (crc_state >> 8);
            end 

            crc_state = crc_calc;
        end

        // Invert the CRC at the end
        return ~crc_calc;
    endfunction : crc32_slicing_by_4

    // --------------------------------------------------------------
    // This function was used to test the slicing software model by
    // comparing the outputs to the known correct sarwate model. This was
    // used extensivley during prototyping and development of the model.
    // --------------------------------------------------------------
    function test_slicing_model(logic [CRC_WIDTH-1:0] lut [3:0][255:0]);
        int failed_tests = 0;

        for(int i = 4; i < 1500; i++) begin
            crc_word_t word_stream[$];
            logic [DATA_WIDTH-1:0] sarwate, slicing;

            generate_word_stream(i, word_stream);

            sarwate = crc32_sarwate_ref_model(word_stream, lut[0]);
            slicing = crc32_slicing_by_4(word_stream, lut);

            assert(slicing == sarwate) else begin
                $display("Slicing algorithm %0h != Sarwate algorithm %0h for num of bytes", slicing, sarwate);
                failed_tests++;
            end

            word_stream.delete();
        end

        $display("Num Failed Tests for Slicing Model: %0d", failed_tests);
    endfunction : test_slicing_model
    

endpackage : crc_pkg