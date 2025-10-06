//`include "mac_pkg.sv"
//`include "axi_stream_if.sv"
//`include "xgmii_if.sv"

module rx_mac_top;

    import mac_pkg::*;

    /* Parameters */

    parameter XGMII_DATA_WIDTH = 32;
    parameter XGMII_CTRL_WIDTH = XGMII_DATA_WIDTH/8;
    parameter O_DATA_WIDTH = 32;
    parameter O_DATA_KEEP_WIDTH = O_DATA_WIDTH/8;

    /* Signals */

    logic i_clk;
    logic i_reset_n;
    logic o_data;
    logic o_data_keep;
    logic o_data_valid;
    logic o_data_err;

    /* Interface Declarations */

    xgmii_if #(
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .XGMII_CTRL_WIDTH(XGMII_CTRL_WIDTH)
    ) xgmii_if_inst (
        .clk(i_clk),
        .i_reset_n(i_reset_n)
    );

    axi_stream_if #(
        .DATA_WIDTH(DATA_WIDTH)
    ) axi_if(
        .clk(i_clk),
        .reset_n(i_reset_n)
    );

    xgmii_obj xgmii_rand_obj = new();

    /* DUT Loop back ans instantiation*/
    rx_mac #(
        .XGMII_DATA_WIDTH(XGMII_DATA_WIDTH),
        .O_DATA_WIDTH(O_DATA_WIDTH)
    ) RX_DUT (
        .i_clk(i_clk),
        .i_reset_n(i_reset_n),
        .i_xgmii_data(xgmii_if_inst.i_xgmii_data),
        .i_xgmii_ctrl(xgmii_if_inst.i_xgmii_ctrl),
        .i_xgmii_valid(xgmii_if_inst.i_xgmii_valid),
        .o_data(o_data),
        .o_data_keep(o_data_keep),
        .o_data_valid(o_data_valid),
        .o_data_err(o_data_err)    
    );

    tx_mac #(
        .XGMII_DATA_WIDTH(DATA_WIDTH),
        .XGMII_CTRL_WIDTH(CTRL_WIDTH)
    ) TX_DUT (
        .i_clk(i_clk),
        .i_reset_n(i_reset_n),

        // XGMII Interface
        .o_xgmii_txd(xgmii_if_inst.o_xgmii_txd),
        .o_xgmii_ctrl(xgmii_if_inst.o_xgmii_ctrl),
        .o_xgmii_valid(xgmii_if_inst.o_xgmii_valid),
        .i_xgmii_pause(xgmii_if_inst.i_xgmii_pause),

        // AXI-Stream Interface
        .s_axis_tdata(axi_if.s_axis_tdata),
        .s_axis_tkeep(axi_if.s_axis_tkeep),
        .s_axis_tvalid(axi_if.s_axis_tvalid),
        .s_axis_tlast(axi_if.s_axis_tlast),
        .s_axis_trdy(axi_if.s_axis_trdy)
    );

    // Loopback XGMII signals
    assign xgmii_if_inst.i_xgmii_data = xgmii_if_inst.o_xgmii_txd;
    assign xgmii_if_inst.i_xgmii_ctrl = xgmii_if_inst.o_xgmii_ctrl;
    assign xgmii_if_inst.i_xgmii_valid = xgmii_if_inst.o_xgmii_valid;

    /* Instantate Clock & Reset */
    initial begin
        i_clk = 1'b0;
        i_reset_n = 1'b0;
        repeat(3)
            @(posedge i_clk);
        i_reset_n <= 1'b1;
        @(posedge i_clk);
    end

    always #10 i_clk = ~i_clk;

    /* Driving Sitmulus */

    initial begin
        //xgmii_if_inst.xgmii_obj_t = xgmii_rand_obj;

        xgmii_if_inst.init_xgmii();

        // Wait for reset to be asserted again
        @(posedge i_reset_n);

        generate_tx_data_stream(tx_mac_data_queue);
        axi_if.drive_data_axi_stream(tx_mac_data_queue);

        #1000;
        $finish;
    end

endmodule : rx_mac_top