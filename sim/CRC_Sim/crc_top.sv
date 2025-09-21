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
    logic [CRC_WIDTH-1:0]       o_crc_state; 

    /* Independent Signals */
    logic sof;
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

        .o_crc(crc_out),
        .o_crc_state(o_crc_state)
    );

    /* Clock Instantiation */

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    task crc32_test();
        logic [CRC_WIDTH-1:0] ref_slicing_crc;
        crc_word_t data;
        crc_word_t word_stream[$];
        int num_bytes;

        num_bytes = $urandom_range(4, 1500);
        $display("Num Bytes: %0d", num_bytes);
        
        // Generate a stream of bytes used for teh CRC32 reference model
        generate_word_stream(num_bytes, word_stream);

        ref_slicing_crc = crc32_slicing_by_4(word_stream, lut);

        sof <= 1'b1;
        @(posedge clk);
        sof <= 1'b0;

        repeat(word_stream.size()) begin
            data = word_stream.pop_back();

            data_word <= data.data_word;
            data_valid <= data.data_valid;

            @(posedge clk);
        end

        assert(crc_out == ref_slicing_crc) begin
            scb.record_success();
        end else begin
            $display("MISMATCH: Actual: %0h != Expected: %0h", crc_out, ref_slicing_crc);
            scb.record_failure();
        end

    endtask : crc32_test

    /*** Logic to drive signals to the DUT ***/

    /* Always block to manage crc_state */
    always @(posedge clk) begin
        if (!i_reset_n | sof) 
            i_crc_state <= 32'hFFFFFFFF;  
        else 
            i_crc_state <= o_crc_state;
         
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

        int iter = 50;

        sof = 1'b0;
        i_reset_n = 1'b0;
        #50;
        i_reset_n <= 1'b1;
        @(posedge clk);

        //test_slicing_model(lut);

        repeat(iter)
            crc32_test();

        #100;
        scb.print_summary();
        $finish;

    end


endmodule : crc_top