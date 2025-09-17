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

    logic [CRC_WIDTH-1:0] lut_0 [255:0];

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
                i_byte_rev[j] = i_byte_stream[i][7-j];

            /* XOR this value with the MSB of teh current CRC State */
            table_index = i_byte_rev ^ crc_state[31:24];

            /* Index into the LUT and XOR the output with the shifted CRC */
            crc_state = {crc_state[24:0], 8'h0} ^ lut_0[table_index];

        end

        /* Reverse & Invert the final CRC State after all bytes have been iterated through */
        crc_state_rev = 32'h0;
        for(int k = 0; k < 32; k++) 
            crc_state_rev[k] = crc_state[(CRC_WIDTH-1)-k];

        crc32_reference_model = ~crc_state_rev;

    endfunction : crc32_reference_model

    task drive_crc32_data();
        int i;
        logic [CRC_WIDTH-1:0] ref_crc;
        crc_word_t data;
        
        // Generate a stream of bytes used for teh CRC32 reference model
        generate_byte_stream();

        foreach(byte_stream[i])
            $display("0x%02h", byte_stream[i]);

        // Pass the generated data through the reference model
        ref_crc = crc32_reference_model(byte_stream);

        $display("Ref Model CRC: %0h", ref_crc);

        // Generate 32-bit word values to transmit to the DUT
        convert_byte_to_32_bits();

        repeat(word_stream.size()) begin
            $display("Number of streams: %0d", word_stream.size());
            data = word_stream.pop_front();

            $display("Printing Converted word stream!");
            $display("Data: %08h", data.data_word);
            $display("Valid: %04b", data.data_valid);

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
        $readmemh("table0.txt", lut_0);
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