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

    task drive_crc32_data();
        int i, j;
        logic [CRC_WIDTH-1:0] ref_crc, ref_slicing_crc;
        crc_word_t data;
        crc_word_t word_stream[$];
        
        // Generate a stream of bytes used for teh CRC32 reference model
        generate_word_stream(4, word_stream);

        // Pass the generated data through the reference model
        ref_crc = crc32_sarwate_ref_model(word_stream, lut[0]);

        ref_slicing_crc = crc32_slicing_by_4(word_stream, lut);

        if (ref_crc == ref_slicing_crc)
            $display("%0h == %0h", ref_crc, ref_slicing_crc);
        else
            $display("Ref CRC: %0h != Slicing CRC: %0h", ref_crc, ref_slicing_crc);

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

        test_slicing_model(lut);

        drive_crc32_data();

        #100;
        $finish;

    end


endmodule : crc_top