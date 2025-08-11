
`include "xgmii_encoder_pkg.sv"
`include "xgmii_if.sv"
`include "../Common/scoreboard_base.sv"

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
    xgmii_frame_t tx_queue[$], rx_queue[$];

    scoreboard_base scb = new();

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
        // Scrambler-to-Encoder Interface
        .o_tx_data(xgmii.o_encoded_data),
        .o_tx_sync_hdr(xgmii.o_sync_hdr),
        .o_tx_data_valid(xgmii.o_encoded_data_valid),
        .o_tx_encoding_err(xgmii.o_encoding_err),
        .i_rx_trdy(xgmii.scrambler_rdy)
    );

    /* Clock Instantiation */

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    /* Stimulus/Test */
    initial begin
        xgmii.scrambler_rdy = 1'b1;

        // Initial Reset for design
        i_reset_n = 1'b0; #10;
        @(posedge clk)
        i_reset_n = 1'b1;

        /* Stimulus */

        sanity_test(tx_queue);

        fork 
            begin
                foreach(tx_queue[i]) begin
                    rx_queue.push_back(tx_queue[i]);
                    xgmii.drive_xgmii_data(tx_queue[i].data_word, tx_queue[i].ctrl_word);
                end
            end
            begin
                forever begin
                    logic [65:0] expected_data;
                    logic [65:0] actual_data;                    
                    xgmii_frame_t rx_data;
                    
                    rx_data = rx_queue.pop_front();
                    expected_data = encode_data(rx_data.data_word, rx_data.ctrl_word);

                    xgmii.sample_encoded_data(actual_data);  

                    assert(actual_data == expected_data) begin
                        $display("MATCH: Expected data matches actual data %0h == %0h", expected_data, actual_data);
                        scb.record_success();
                    end else begin
                        $display("MISMATCH: Assertion failed! Expected: %0h, Actual: %0h", expected_data, actual_data);
                        scb.record_failure();
                    end
                end
            end
        join_any  

        scb.print_summary();

        #100;
        $finish;

    end


endmodule : xgmii_encoder_top