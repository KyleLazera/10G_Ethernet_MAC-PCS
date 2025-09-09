
`include "pcs_if.sv"
`include "pcs_testcases.sv"

import pcs_testcases::*;

module pcs_top;

    /* Parameters */
    localparam DUT_DATA_WIDTH = 32;

    /* Signals */
    logic clk;
    logic tx_reset_n;
    logic rx_reset_n;

    logic loopback_signal;

    // XGMI Interafce
    pcs_if pcs(clk, tx_reset_n);

    pcs_scb scoreboard = new();

    /* DUT */
    pcs #(.DATA_WIDTH(DUT_DATA_WIDTH)) DUT (
        .gty_tx_usr_clk(clk),      
        .gty_tx_usr_reset(tx_reset_n),   

        // For Verif purposes - rx and tx use same clock domain
        .gty_rx_usr_clk(clk),
        .gty_rx_usr_reset(rx_reset_n),    

        // MAC to PCS (XGMII) Interface
        .i_xgmii_txd(pcs.i_xgmii_txd),         
        .i_xgmii_txc(pcs.i_xgmii_txc),         
        .i_xgmii_valid(pcs.i_xgmii_valid),                       
        .o_xgmii_pause(pcs.o_xgmii_pause),   

        // MAC to PCS (XGMII) Interface - RX
        .o_xgmii_rxd(pcs.o_xgmii_rxd),
        .o_xgmii_rxc(pcs.o_xgmii_rxc),
        .o_xgmii_rvalid(pcs.o_xgmii_rvalid),                   

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

    property p_xgmii_rxd;
      @(posedge clk)
        disable iff (!rx_reset_n)
        pcs.o_xgmii_rvalid |-> (pcs.o_xgmii_rxd == $past(pcs.i_xgmii_txd, 6, clk));
    endproperty

    property p_xgmii_ctrl;
      @(posedge clk)
        disable iff (!rx_reset_n)
        pcs.o_xgmii_rvalid |-> (pcs.o_xgmii_rxc == $past(pcs.i_xgmii_txc, 6, clk));
    endproperty

    assert property (p_xgmii_rxd) 
    begin
        scoreboard.record_success();
    end else begin
        $fatal("MISMATCH of xgmii_txd");
        scoreboard.record_failure();
    end

    assert property (p_xgmii_ctrl)
    begin
        scoreboard.record_success();
    end else begin
        $fatal("MISMATCH of xgmii_ctrl");
        scoreboard.record_failure();
    end

    /* Stimulus/Test */
    initial begin

        // Assert both resets initially
        tx_reset_n = 1'b0;
        rx_reset_n = 1'b0;

        // Hold TX reset for 10 ns
        #10;
        @(posedge clk);
        tx_reset_n = 1'b1;

        // Start TX sanity test right away
        fork
            begin
                test_sanity(pcs);
            end
            begin
                // Hold RX reset for 3 more clock cycles after TX reset deassertion
                repeat (3) @(posedge clk);
                rx_reset_n <= 1'b1;
                @(posedge clk);
            end
        join


        #100;
        disable fork;
        scoreboard.print_summary();
        $finish;

    end

endmodule : pcs_top