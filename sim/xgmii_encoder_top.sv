
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
    xgmii_frame_t tx_queue[$], rx_queue[$];

    initial begin
        /* Frame 1: Idle followed by start condition in lane 4 */
        tx_queue.push_back('{64'h030201FB07070707, 8'b00011111}); 
        /* Frame 2: Data Frame */
        tx_queue.push_back('{64'h0807060504030201, 8'b00000000}); 
        /* Frame 3: Terminate in Lane 0 followed by idle */
        tx_queue.push_back('{64'h07070707070707FD, 8'b11111111}); 
        /* Frame 4: Start condition in lane 1 & data */
        tx_queue.push_back('{64'h20100E0D0C0B0AFB, 8'b00000001}); 
        /* Frame 5: Data Frame */
        tx_queue.push_back('{64'h0807060504030201, 8'b00000000}); 
        /* Frame 6: Terminate in Lane 7 */
        tx_queue.push_back('{64'hFD2211EEDDCCBBAA, 8'b10000000}); 
        /* Frame 7: Idle */
        tx_queue.push_back('{64'h0707070707070707, 8'b11111111}); 
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

        // Initial Reset for design
        i_reset_n = 1'b0; #10;
        @(posedge clk)
        i_reset_n = 1'b1;

        /* Stimulus */

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

                    if (actual_data == expected_data) begin
                        $display("MATCH: Expected data matches actual data %0h == %0h", expected_data, actual_data);
                    end else begin
                        $display("MISMATCH: Assertion failed! Expected: %0h, Actual: %0h", expected_data, actual_data);
                    end
                end
            end
        join_any  

        #100;
        $finish;

    end


endmodule : xgmii_encoder_top