`include "rx_mac_scb.sv"

module rx_mac_top;

    import mac_pkg::*;

    /* Parameters */

    parameter XGMII_DATA_WIDTH = 32;
    parameter XGMII_CTRL_WIDTH = XGMII_DATA_WIDTH/8;
    parameter O_DATA_WIDTH = 32;
    parameter O_DATA_KEEP_WIDTH = O_DATA_WIDTH/8;

    /* Signals */

    logic                           i_clk;
    logic                           i_reset_n;
    logic [O_DATA_WIDTH-1:0]        o_data;
    logic [O_DATA_KEEP_WIDTH-1:0]   o_data_keep;
    logic                           o_data_valid;
    logic                           o_data_err;

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

    rx_mac_scb scb = new();
    axi_stream_t ref_data[$], output_data[$];

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

    task sample_rx_data(ref axi_stream_t output_data_q [$]);

        axi_stream_t rx_data;

        // Wait for the tkeep signal to indicate we have data to keep
        while (o_data_keep == 4'h0)
            @(posedge i_clk);

        // Sample all words that have at least 1 byte of data to keep
        while (o_data_keep != 4'h0) begin
            if (o_data_valid) begin
                rx_data.axis_tdata = o_data;
                rx_data.axis_tkeep = o_data_keep;
                rx_data.axis_tvalid = o_data_valid;
                output_data_q.push_front(rx_data);
            end
            @(posedge i_clk);
        end

    endtask : sample_rx_data


    /* Driving Sitmulus */

    initial begin
        xgmii_if_inst.init_xgmii();

        // Wait for reset to be asserted again
        @(posedge i_reset_n);

        repeat(2) begin
            generate_tx_data_stream(tx_mac_data_queue);

            foreach(tx_mac_data_queue[i])
                ref_data.push_back(tx_mac_data_queue[i]);

            fork
                begin
                    axi_if.drive_data_axi_stream(tx_mac_data_queue);
                end
                begin
                    sample_rx_data(output_data);
                end
            join

            scb.verify_data(output_data, ref_data);
        end

        #1000;
        scb.print_summary();
        $finish;
    end

endmodule : rx_mac_top