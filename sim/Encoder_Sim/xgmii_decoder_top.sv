

`include "xgmii_encoder_pkg.sv"
`include "xgmii_if.sv"
`include "../Common/scoreboard_base.sv"

import xgmii_encoder_pkg::*;

/*
 * Decoder verification - utilizes the encoder and a simple loopback. This is based
 * on the principle that the decoder should be the inverse of the encoder, therefore,
 * if we loop back the encoder output, we should match the original input data.
 */

module xgmii_decoder_top;

    /* Parameters */
    localparam DATA_WIDTH = 32;
    localparam CTRL_WIDTH = 4;
    localparam HDR_WIDTH = 2;

    /* Signal Descriptions */
    logic clk;
    logic i_reset_n;

    logic [DATA_WIDTH-1:0]  scrambler_data;
    logic                   scrambler_data_valid;
    logic [HDR_WIDTH-1:0]   scrambler_hdr;
    logic                   scrambler_hdr_sync;

    logic [DATA_WIDTH-1:0]  descrambler_data;
    logic [CTRL_WIDTH-1:0]  descrambler_ctrl;
    logic                   descrambler_data_valid;

    /* Interface declaration */
    xgmii_if xgmii(clk, i_reset_n) ;
    xgmii_frame_t tx_queue[$], rx_queue[$];

    scoreboard_base scb = new();

    /* DUT Instantiation */
    xgmii_encoder#( 
        .DATA_WIDTH(DATA_WIDTH),
        .CTRL_WIDTH(CTRL_WIDTH),
        .HDR_WIDTH(HDR_WIDTH)
    )Encoder_DUT(
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
        .i_rx_trdy(xgmii.scrambler_rdy)
    );

    xgmii_decoder #(
        .DATA_WIDTH(DATA_WIDTH),
        .HDR_WIDTH(HDR_WIDTH),
        .CTRL_WIDTH(CTRL_WIDTH)
    ) decoder_DUT (
        .i_clk(clk),
        .i_reset_n(i_reset_n),

        .i_rx_data(scrambler_data),
        .i_rx_data_valid(scrambler_data_valid),
        .i_rx_hdr(scrambler_hdr),
        .i_rx_hdr_valid(scrambler_hdr_sync),  
        .i_block_lock(1'b1),

        .o_xgmii_txd(descrambler_data),
        .o_xgmii_txc(descrambler_ctrl),
        .o_xgmii_valid(descrambler_data_valid)
    );

    // Loop back logic
    assign scrambler_data = xgmii.o_encoded_data;
    assign scrambler_data_valid = xgmii.o_encoded_data_valid;
    assign scrambler_hdr = xgmii.o_sync_hdr;
    
    always_ff @(posedge clk)
        scrambler_hdr_sync <= ~scrambler_hdr_sync;

    /* Clock Instantiation */

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    /* Stimulus/Test */
    initial begin

        int data_sampled = 0;

        xgmii.scrambler_rdy = 1'b1;
        scrambler_hdr_sync = 1'b0;

        // Initial Reset for design
        i_reset_n = 1'b0; #10;
        @(posedge clk)
        i_reset_n = 1'b1;

        /* Stimulus */

        sanity_test(tx_queue);
        fuzz_test(tx_queue);

        fork 
            begin
                foreach(tx_queue[i]) begin
                    rx_queue.push_back(tx_queue[i]);
                    xgmii.drive_xgmii_data(tx_queue[i].data_word, tx_queue[i].ctrl_word);
                end
            end
            begin
                forever begin
                    logic [63:0] actual_data;
                    logic [7:0] actual_ctrl;                    
                    xgmii_frame_t rx_data;

                    repeat(2) begin
                        if (descrambler_data_valid) begin

                            ++data_sampled;

                            if (data_sampled == 1) begin
                                actual_data[DATA_WIDTH-1:0] = descrambler_data;
                                actual_ctrl[3:0] = descrambler_ctrl;
                            end else if (data_sampled == 2) begin

                                actual_data[63:32] = descrambler_data;
                                actual_ctrl[7:4] = descrambler_ctrl;

                                rx_data = rx_queue.pop_front();

                                assert(rx_data.data_word == actual_data) begin
                                    $display("MATCH: Expected data matches actual data %0h == %0h", actual_data, rx_data.data_word);
                                    scb.record_success();
                                end else begin
                                    $display("MISMATCH: Expected word word mismatch! Actual: %0h, Expected: %0h", actual_data, rx_data.data_word);
                                    scb.record_failure();
                                    $finish;
                                end

                                assert(rx_data.ctrl_word == actual_ctrl) begin
                                    $display("MATCH: Expected ctrl word matches actual data %0h == %0h", actual_ctrl, rx_data.ctrl_word);
                                    scb.record_success();
                                end else begin
                                    $display("MISMATCH: Expected ctrl word mismatch! Actual: %0h, Expected: %0h", actual_ctrl, rx_data.ctrl_word);
                                    scb.record_failure();
                                    $finish;
                                end

                                data_sampled = 0;
                            end
                        end
                    
                        @(posedge clk);
                    
                    end
                end
            end
        join_any  

        scb.print_summary();

        #100;
        $finish;

    end


endmodule : xgmii_decoder_top