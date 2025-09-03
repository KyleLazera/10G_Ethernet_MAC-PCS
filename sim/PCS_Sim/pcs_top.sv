
`include "pcs_if.sv"
`include "pcs_testcases.sv"

import pcs_testcases::*;

module pcs_top;

    /* Parameters */
    localparam DUT_DATA_WIDTH = 32;

    /* Signals */
    logic clk;
    logic reset_n;

    logic loopback_signal;

    // XGMI Interafce
    pcs_if pcs(clk, reset_n);

    /* DUT */
    pcs #(.DATA_WIDTH(DUT_DATA_WIDTH)) DUT (
        .gty_tx_usr_clk(clk),      
        .gty_tx_usr_reset(reset_n),   

        // For Verif purposes - rx and tx use same clock domain
        .gty_rx_usr_clk(clk),
        .gty_rx_usr_reset(reset_n),    

        // MAC to PCS (XGMII) Interface
        .i_xgmii_txd(pcs.i_xgmii_txd),         
        .i_xgmii_txc(pcs.i_xgmii_txc),         
        .i_xgmii_valid(pcs.i_xgmii_valid),                       
        .o_xgmii_pause(pcs.o_xgmii_pause),   

        // MAC to PCS (XGMII) Interface - RX
        .o_xgmii_rxd(),
        .o_xgmii_rxc(),
        .o_xgmii_rvalid(),                   

        // PCS to GTY Transceiver Transmit Interface
        .pcs_tx_gearbox_data(pcs.pcs_tx_gearbox_data),
        .pcs_rx_gearbox_data(pcs.pcs_tx_gearbox_data)
    );

    assign loopback_signal = pcs.pcs_tx_gearbox_data;

    /* Clock Instantiation */

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    /* Stimulus/Test */
    initial begin

        // Initial Reset for design
        reset_n = 1'b0; #10;
        @(posedge clk)
        reset_n = 1'b1;

        tx_test_sanity(pcs);
        //tx_test_fuzz(pcs);

        #100;
        $finish;

    end

endmodule : pcs_top