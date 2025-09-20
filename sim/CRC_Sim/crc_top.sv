`include "../Common/scoreboard_base.sv"
`include "crc_pkg.sv"


module crc_top;

    import crc_pkg::*;

    /* Signal Descriptions */
    logic clk;
    logic i_reset_n;

    logic [DATA_WIDTH-1:0]      data_word;
    logic [CRC_WIDTH-1:0]       i_crc_state;
    logic [(DATA_WIDTH/8)-1:0]  data_valid;
    logic [DATA_WIDTH-1:0]      crc_out;  

    logic [CRC_WIDTH-1:0] lut [3:0][255:0];

    /* Scoreboard Declaration */
    scoreboard_base scb = new();

    /* DUT Instantiation */
    crc32 #(
        .DATA_WIDTH(DATA_WIDTH),
        .CRC_WIDTH(CRC_WIDTH)
    ) DUT (
        .i_clk(clk),
        .i_reset_n(i_reset_n),

        .i_data(data_word),
        .i_crc_state(i_crc_state),
        .i_data_valid(data_valid),

        .o_crc(crc_out)
    );

    /* Clock Instantiation */

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

function automatic [31:0] crc32_reference_model(crc_word_t i_word_stream[$]);
    logic [31:0] crc_state = 32'hFFFFFFFF;
    logic [7:0]  table_index;
    logic [7:0]  curr_byte;
    crc_word_t crc_data;
    integer i, b;

    repeat(i_word_stream.size()) begin

        crc_data = i_word_stream.pop_back();

        // Process each 32-bit word byte-by-byte, starting with LSB (Byte0 on wire)
        for (b = 0; b < 4; b++) begin
            curr_byte = crc_data.data_word[8*b +: 8];

            $display("0x%02h", curr_byte);

            // Standard Sarwate update, LSB-first, LUT contains reflected values
            table_index = curr_byte ^ crc_state[7:0];
            crc_state   = (crc_state >> 8) ^ lut[0][table_index];
        end
    end

    // Invert at the end (no final reflection since LUT is already reflected)
    crc32_reference_model = ~crc_state;
endfunction


function automatic logic [31:0] crc32_slicing_by_4_words(crc_word_t word_stream[$]);
    logic [31:0] crc = 32'hFFFFFFFF;
    crc_word_t crc_word;
    logic [7:0] bytes [4], idx;

    repeat(word_stream.size()) begin
        crc_word = word_stream.pop_back();

        $display("Word: %04h", crc_word.data_word);

        //Isolate Each individual byte
        for(int i = 0; i < 4; i++) begin
            bytes[i] = crc_word.data_word[8*i +: 8];
            idx = (crc[7:0] ^ bytes[i]) & 8'hFF;
            crc  = (crc >> 8) ^ lut[0][idx]; 
        end
    end

    return ~crc; 
endfunction

    task drive_crc32_data();
        int i;
        logic [CRC_WIDTH-1:0] ref_crc, ref_slicing_crc;
        crc_word_t data;
        
        // Generate a stream of bytes used for teh CRC32 reference model
        generate_word_stream();

        foreach(word_stream[i]) begin
            $display("Data Word[%0d] 0x%08h", i, word_stream[i].data_word);     
            $display("Data Valid: %04b", word_stream[i].data_valid);
        end   

        // Pass the generated data through the reference model
        ref_crc = crc32_reference_model(word_stream);

        $display("Ref Model CRC: %0h", ref_crc);

        // Generate 32-bit word values to transmit to the DUT
        //convert_byte_to_32_bits();

        ref_slicing_crc = crc32_slicing_by_4_words(word_stream);

        $display("Slicing Reference: %0h", ref_slicing_crc);

        repeat(word_stream.size()) begin
            data = word_stream.pop_front();

            data_word <= data.data_word;
            data_valid <= data.data_valid;

            if (|data.data_valid)
                i_crc_state <= crc_out;

            @(posedge clk);
        end

    endtask : drive_crc32_data

    /*** Logic to drive signals to the DUT ***/

    /* Always block to manage crc_state */
    always @(posedge clk) begin
        if (!i_reset_n) 
            i_crc_state <= 32'hFFFFFFFF;  
         
    end

    //Init CRC LUT
    initial begin
        $readmemh("table0.txt", lut[0]);
        $readmemh("table1.txt", lut[1]);
        $readmemh("table2.txt", lut[2]);
        $readmemh("table3.txt", lut[3]);            
    end
    
    //Testbench Logic
    initial begin
        i_reset_n = 1'b0;
        #50;
        i_reset_n <= 1'b1;
        @(posedge clk);

        drive_crc32_data();

        #100;
        $finish;

    end


endmodule : crc_top