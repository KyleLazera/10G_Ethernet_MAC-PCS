
`include "axi_stream_if.sv"
`include "mac_pkg.sv"

module tx_mac_top;

    import mac_pkg::*;

    /* Signals */
    logic clk;
    logic reset_n;

    logic xgmii_pause;

    /* Interface Declarations */
    axi_stream_if #(
        .DATA_WIDTH(DATA_WIDTH)
    ) axi_if(
        .clk(clk),
        .reset_n(reset_n)
    );

    /* DUT */
    tx_mac #(
        .XGMII_DATA_WIDTH(DATA_WIDTH),
        .XGMII_CTRL_WIDTH(CTRL_WIDTH)
    ) DUT (
        .i_clk(clk),
        .i_reset_n(reset_n),

        // XGMII Interface
        .o_xgmii_txd(),
        .o_xgmii_ctrl(),
        .o_xgmii_valid(),
        .i_xgmii_pause(xgmii_pause),

        // AXI-Stream Interface
        .s_axis_tdata(axi_if.s_axis_tdata),
        .s_axis_tkeep(axi_if.s_axis_tkeep),
        .s_axis_tvalid(axi_if.s_axis_tvalid),
        .s_axis_tlast(axi_if.s_axis_tlast),
        .s_axis_trdy(axi_if.s_axis_trdy)
    );

    /* Clock Instantiation */
    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    /* Stimulus/Test */
    initial begin
        // TODO: Make this dynamic
        xgmii_pause = 1'b0;

        axi_if.init_axi_stream();

        // Assert both resets initially
        reset_n = 1'b0;

        // Hold reset for 10 ns
        #10;
        reset_n <= 1'b1;
        @(posedge clk);

        generate_tx_data_stream(tx_mac_data_queue);

        axi_if.drive_data_axi_stream(tx_mac_data_queue);

        #100;        

        $finish;

    end

endmodule : tx_mac_top