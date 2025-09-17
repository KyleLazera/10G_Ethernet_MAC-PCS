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

    task drive_crc32_data();

        crc_word_t data;
        
        // Generate a stream of bytes used for teh CRC32 reference model
        generate_byte_stream();

        // Pass the generated data through the reference model
        crc32_reference_model(byte_stream);

        // Generate 32-bit word values to transmit to the DUT
        convert_byte_to_32_bits();

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
        if (i_reset_n) 
            i_crc_state <= 32'hFFFFFFFF;  
         
    end

    //Init CRC LUT
    initial begin
        $readmemh("table0.txt", crc_lut);
    end

    //Testbench Logic
    initial begin

        clk = 1'b0;
        i_reset_n = 1'b0;
        #50;
        i_reset_n = 1'b1;

        drive_crc32_data();

        #100;
        $finish;

    end


endmodule : crc_top