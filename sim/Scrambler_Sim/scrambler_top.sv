
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
        .DATA_WIDTH(DATA_WIDTH),
        .SCRAMBLER_BYPASS(0) 
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
            data_out[i] = data_in[i] ^ lfsr[57] ^ lfsr[38];

            // Shift LFSR and insert new feedback bit
            lfsr = {lfsr[56:0], data_out[i]};
        end

        return data_out;

    endfunction    

    /* Stimulus/Test */
    initial begin
        logic [31:0] data_in, expected_out;
        logic [57:0] lfsr_golden;

        i_data_valid = 1'b0;
        i_data = 32'h0;

        // Initial Reset for design
        i_reset_n = 1'b0; #10;
        @(posedge clk)
        i_reset_n = 1'b1;
        lfsr_golden = {58{1'b1}};

        fork
            begin
                for(int i = 0; i < 10; i++) begin                    
                    data_in = $urandom;
                    i_data_valid <= 1'b1;
                    i_data <= data_in; 
                    @(posedge clk);                   
                end
                i_data_valid <= 1'b0;
                @(posedge clk);
            end
                while(1) begin
                    expected_out = scramble_golden_model(data_in, lfsr_golden);
                    @(posedge clk);
                    if (o_data !== expected_out) begin
                        $display("FAILED: Input = 0x%08h, Output = 0x%08h, Expected: %0h", data_in, o_data, expected_out);
                    end else begin
                        $display("PASS: Input = 0x%08h, Output = 0x%08h", data_in, o_data);
                    end
                end
            begin

            end
        join_any

        #100;
        $finish;

    end


endmodule : xgmii_encoder_top