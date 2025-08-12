
`include "pcs_if.sv"
`include "pcs_testcases.sv"

import pcs_testcases::*;

module pcs_top;

    /* Parameters */
    localparam DUT_DATA_WIDTH = 32;

    /* Signals */
    logic clk;
    logic reset_n;
    // XGMI Interafce
    pcs_if pcs(clk, reset_n);

    /* DUT */
    pcs #(.DATA_WIDTH(DUT_DATA_WIDTH)) DUT (
        .gty_tx_usr_clk(clk),      
        .gty_tx_usr_reset(reset_n),    

        // MAC to PCS (XGMII) Interface
        .i_xgmii_txd(pcs.i_xgmii_txd),         
        .i_xgmii_txc(pcs.i_xgmii_txc),         
        .i_xgmii_valid(pcs.i_xgmii_valid),                       
        .o_xgmii_pause(pcs.o_xgmii_pause),                      

        // PCS to GTY Transceiver Transmit Interface
        .pcs_tx_gearbox_data(pcs.pcs_tx_gearbox_data)
    );

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

        //test_sanity(pcs);
        test_fuzz(pcs);

        #100;
        $finish;

    end

endmodule : pcs_top