
`include "xgmii_encoder_pkg.sv"
`include "xgmii_if.sv"

import xgmii_encoder_pkg::*;

module xgmii_encoder_top;

    /* Parameters */
    localparam DATA_WIDTH = 32;
    localparam CTRL_WIDTH = 4;
    localparam HDR_WIDTH = 2;

    /* Signal Descriptions */
    logic clk;
    logic i_reset_n;

    /* Interface declaration */
    xgmii_if xgmii(clk, i_reset_n) ;
    xgmii_frame_t test_queue[$];

    initial begin
        test_queue.push_back('{64'h030201FB07070707, 8'b00011111}); // Test 1
        test_queue.push_back('{64'h0C0B0AFB20100E0D, 8'b00000001}); // Test 2
        test_queue.push_back('{64'h0403020108070605, 8'b00000000}); // Test 3
        test_queue.push_back('{64'h0707FDAA07070707, 8'b11111110}); // Test 4
        test_queue.push_back('{64'h0C0B0AFB20100E0D, 8'b00000001}); // Test 5
        test_queue.push_back('{64'h0403020108070605, 8'b00000000}); // Test 6
        test_queue.push_back('{64'hDDCCBBAA070707FD, 8'b00001111}); // Test 7
    end

    /* DUT Instantiation */
    xgmii_encoder#( 
        .DATA_WIDTH(DATA_WIDTH),
        .CTRL_WIDTH(CTRL_WIDTH),
        .HDR_WIDTH(HDR_WIDTH)
    )DUT(
        .i_clk(clk),
        .i_reset_n(i_reset_n),
        // XGMII Interface
        .i_xgmii_txd(xgmii.i_xgmii_txd),
        .i_xgmii_txc(xgmii.i_xgmii_txc),
        .i_xgmii_valid(xgmii.i_xgmii_valid),
        .o_xgmii_pause(xgmii.o_xgmii_pause),
        // Scrambler Interface/Encoder Output
        .i_scrambler_trdy(xgmii.i_scrambler_trdy),
        .o_encoded_data_valid(xgmii.o_encoded_data_valid),
        .o_encoded_data(xgmii.o_encoded_data),
        .o_sync_hdr(xgmii.o_sync_hdr),
        .o_encoding_err(xgmii.o_encoding_err)
    );

    /* Clock Instantiation */

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    /* Stimulus/Test */
    initial begin

        logic [63:0] data_word;
        logic [7:0] ctrl_word;
        logic [65:0] expected_data;
        logic [65:0] actual_data;

        // Initial Reset for design
        i_reset_n = 1'b0; #10;
        @(posedge clk)
        i_reset_n = 1'b1;

        /* Stimulus */

        fork 
            begin
                foreach(test_queue[i]) begin
                    expected_data = encode_data(test_queue[i].data_word, test_queue[i].ctrl_word);
                    $display("Expected Data: %0h", expected_data);
                    xgmii.drive_xgmii_data(test_queue[i].data_word, test_queue[i].ctrl_word);
                end
            end
            begin
                forever begin
                    xgmii.sample_encoded_data(actual_data);

                    assert (actual_data == expected_data)
                        else begin
                            $display("Assertion failed! Expected: %0d, Actual: %0d", expected_data, actual_data);
                    end
                end
            end
        join_any  

        #100;
        $finish;

    end


endmodule : xgmii_encoder_top