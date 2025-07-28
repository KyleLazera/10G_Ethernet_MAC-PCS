
module xgmii_encoder_top;

    /* Parameters */
    localparam DATA_WIDTH = 32;
    localparam SCRAMBLER_BYPASS = 0;

    /* Signal Descriptions */
    logic clk;
    logic i_reset_n;
    logic i_data_valid;
    logic [DATA_WIDTH-1:0] i_data;
    logic o_data_valid;
    logic [DATA_WIDTH-1:0] o_data;

    /* DUT Instantiation */
    scrambler #(
        parameter DATA_WIDTH = 32,
        parameter SCRAMBLER_BYPASS = 0 
    ) DUT (
        .i_clk(clk),
        .i_reset_n(i_reset_n),
    
        // Encoder to Scrambler
        .i_data_valid(i_data_valid),
        .i_data(i_data),
    
        // Output to Gearbox
        .o_data_valid(o_data_valid),
        .o_data(o_data)
    );

    /* Clock Instantiation */

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    /* Golden Model */
    function automatic [31:0] scramble_golden_model (
        input  logic [31:0] data_in,
        inout  logic [57:0] lfsr
    );
        logic [31:0] data_out;
        logic feedback;
        int i;

        for (i = 0; i < 32; i++) begin
            // Scramble input bit using MSB of LFSR
            data_out[i] = data_in[i] ^ lfsr[57];

            // Compute new feedback bit from taps 57 and 38
            feedback = lfsr[57] ^ lfsr[38];

            // Shift LFSR and insert new feedback bit
            lfsr = {lfsr[56:0], feedback};
        end

        return data_out;

    endfunction    

    /* Stimulus/Test */
    initial begin

        // Initial Reset for design
        i_reset_n = 1'b0; #10;
        @(posedge clk)
        i_reset_n = 1'b1;


        // Feed 10 random 32-bit blocks
        for (i = 0; i < 10; i++) begin
            @(posedge clk);
            data_in = $urandom;
            i_data_valid = 1'b1;
            i_data = data_in;

            // Wait for DUT to process
            @(posedge clk);
            i_data_valid = 1'b0;

            // Golden model processing
            expected_out = scramble_golden_model(data_in, lfsr_golden);

            // Wait for output to be valid
            wait (o_data_valid == 1);

            // Check output
            if (o_data !== expected_out) begin
                $display("ERROR at cycle %0d: Mismatch!", i);
                $display("Input Data     = 0x%08h", data_in);
                $display("Expected Output= 0x%08h", expected_out);
                $display("DUT Output     = 0x%08h", o_data);
            end else begin
                $display("PASS at cycle %0d: Input = 0x%08h, Output = 0x%08h", i, data_in, o_data);
            end
        end

        #100;
        $finish;

    end


endmodule : xgmii_encoder_top