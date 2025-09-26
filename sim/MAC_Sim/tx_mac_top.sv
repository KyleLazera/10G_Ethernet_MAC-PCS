
`include "axi_stream_if.sv"
`include "mac_pkg.sv"
`include "xgmii_if.sv"
`include "tx_mac_scb.sv"

module tx_mac_top;

    import mac_pkg::*;

    /* Signals */
    logic clk;
    logic reset_n;

    logic xgmii_pause;
    logic [31:0] lut [3:0][255:0];

    /* Interface Declarations */
    axi_stream_if #(
        .DATA_WIDTH(DATA_WIDTH)
    ) axi_if(
        .clk(clk),
        .reset_n(reset_n)
    );

    xgmii_if #(
        .XGMII_DATA_WIDTH(DATA_WIDTH),
        .XGMII_CTRL_WIDTH(CTRL_WIDTH)
    ) xgmii_if (
        .clk(clk),
        .i_reset_n(reset_n)
    );

    /* Scoreboard */
    tx_mac_scb scb = new();

    /* Queues */
    xgmii_stream_t xgmii_ref_data [$], xgmii_actual_data[$];

    /* DUT */
    tx_mac #(
        .XGMII_DATA_WIDTH(DATA_WIDTH),
        .XGMII_CTRL_WIDTH(CTRL_WIDTH)
    ) DUT (
        .i_clk(clk),
        .i_reset_n(reset_n),

        // XGMII Interface
        .o_xgmii_txd(xgmii_if.o_xgmii_txd),
        .o_xgmii_ctrl(xgmii_if.o_xgmii_ctrl),
        .o_xgmii_valid(xgmii_if.o_xgmii_valid),
        .i_xgmii_pause(xgmii_if.i_xgmii_pause),

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

    //Init CRC LUT
    initial begin
        $readmemh("table0.txt", lut[0]);
        $readmemh("table1.txt", lut[1]);
        $readmemh("table2.txt", lut[2]);
        $readmemh("table3.txt", lut[3]);            
    end    

    /* Stimulus/Test */
    initial begin

        xgmii_if.init_xgmii();
        axi_if.init_axi_stream();

        // Assert both resets initially
        reset_n = 1'b0;

        // Hold reset for 10 ns
        #10;
        reset_n <= 1'b1;
        @(posedge clk);

        generate_tx_data_stream(tx_mac_data_queue);

        tx_mac_golden_model(tx_mac_data_queue, lut, xgmii_ref_data);

        fork
            begin
                axi_if.drive_data_axi_stream(tx_mac_data_queue);
            end
            begin
                xgmii_if.sample_xgmii_data(xgmii_actual_data);
            end
        join

        scb.verify_data(xgmii_ref_data, xgmii_actual_data);

        #1000;        
        scb.print_summary();
        $finish;

    end

endmodule : tx_mac_top