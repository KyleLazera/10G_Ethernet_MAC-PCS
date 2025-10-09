`include "../Common/axi_stream_if.sv"
`include "../MAC_Sim/mac_pkg.sv"

module eth_top;

    import mac_pkg::*;

    /* Parameters */
    parameter DATA_WIDTH = 32;
    parameter CTRL_WIDTH = DATA_WIDTH/8;

    /* Signal Instantiation */
    logic clk;
    logic tx_reset_n, rx_reset_n;

    logic [DATA_WIDTH-1:0] tx_rx_loopback;

    /* Interface Instantiation */
    axi_stream_if#(
        .DATA_WIDTH(DATA_WIDTH)
    ) axi_if (
        .clk(clk),
        .reset_n(reset_n)
    );

    axi_stream_t tx_data[$], rx_data[$];
    axi_stream_t idle_block[$];

    /* DUT Instantiation */
    eth_10g_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .CTRL_WIDTH(CTRL_WIDTH),
        .SIMULATION(1)
    ) DUT (
        .i_tx_clk(clk),
        .i_tx_reset_n(tx_reset_n),

        /* TX MAC Interface */
        .s_axis_tdata(axi_if.m_axis_tdata),
        .s_axis_tkeep(axi_if.m_axis_tkeep),
        .s_axis_tvalid(axi_if.m_axis_tvalid),
        .s_axis_tlast(axi_if.m_axis_tlast),
        .s_axis_trdy(axi_if.m_axis_trdy),

        /* TX Transceiever Interface */
        .pcs_tx_gearbox_data(tx_rx_loopback),

        .i_rx_clk(clk),
        .i_rx_reset_n(rx_reset_n),

        /* RX MAC Interface */
        .o_data(axi_if.s_axis_tdata),
        .o_data_keep(axi_if.s_axis_tkeep),
        .o_data_last(axi_if.s_axis_tlast),
        .o_data_valid(axi_if.s_axis_tvalid),
        .o_data_err(),

        /* RX Transceiever Interface */
        .pcs_rx_gearbox_data(tx_rx_loopback)
    );

    /* Init Clock and Reset */

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
        tx_reset_n = 1'b0;
        rx_reset_n = 1'b0;
        repeat(3)
            @(posedge clk);
        tx_reset_n <= 1'b1;
        repeat(3)
            @(posedge clk);
        rx_reset_n <= 1'b1;
        @(posedge clk);
    end

    /* Drive Stimulus */

    initial begin
        axi_if.init_axi_stream();

        // Wait for Reset
        @(posedge tx_reset_n);

        repeat(100)
            @(posedge clk);

        for(int i = 0; i < 200; i++) begin
            generate_tx_data_stream(tx_data);
            $display("Iteration: %0d Size of Data Queue: %0d", i, tx_data.size());
            axi_if.drive_data_axi_stream(tx_data);
        end

        #100;
        $finish;

    end


endmodule : eth_top