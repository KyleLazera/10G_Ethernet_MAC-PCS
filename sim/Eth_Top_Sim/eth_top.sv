`include "../Common/axi_stream_if.sv"
`include "../MAC_Sim/mac_pkg.sv"
`include "../MAC_Sim/rx_mac_scb.sv"

module eth_top;

    import mac_pkg::*;

    /* Parameters */
    parameter DATA_WIDTH = 32;
    parameter CTRL_WIDTH = DATA_WIDTH/8;

    /* Signal Instantiation */
    logic clk;
    logic tx_reset_n, rx_reset_n;

    logic [DATA_WIDTH-1:0]   o_data;
    logic [CTRL_WIDTH-1:0]   o_data_keep;
    logic                    o_data_last;
    logic                    o_data_valid;
    logic                    o_data_err;

    logic [DATA_WIDTH-1:0] tx_rx_loopback;

    /* Interface Instantiation */
    axi_stream_if#(
        .DATA_WIDTH(DATA_WIDTH)
    ) axi_if (
        .clk(clk),
        .reset_n(reset_n)
    );

    axi_stream_t tx_data[$], rx_data[$];

    rx_mac_scb scb = new();

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
        .o_data(o_data),
        .o_data_keep(o_data_keep),
        .o_data_last(o_data_last),
        .o_data_valid(o_data_valid),
        .o_data_err(o_data_err),

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

    task sample_data(ref axi_stream_t rx_data[$]);

        axi_stream_t data;

        while(!o_data_last) begin
            if (o_data_keep != 4'h0 && o_data_valid) begin
                data.axis_tdata = o_data;
                data.axis_tvalid = o_data_valid;
                data.axis_tlast = o_data_last;
                data.axis_tkeep = o_data_keep;
                rx_data.push_front(data);
            end

            @(posedge clk);
        end

        data.axis_tdata = o_data;
        data.axis_tvalid = o_data_valid;
        data.axis_tlast = o_data_last;
        data.axis_tkeep = o_data_keep;
        rx_data.push_front(data);
        @(posedge clk);
        
    endtask : sample_data

    /* Drive Stimulus */

    initial begin
        axi_if.init_axi_stream();

        // Wait for Reset
        @(posedge tx_reset_n);

        /* -----------------------------------------------------------------------
        // Repeat positive clock edges for 150 cycles. During this time
        // the TX MAC will transmit only idle frames. These idle frames will
        // be looped back to the RX PCS and MAC. Sending multiple idle frames
        // allows the lock state module to be set first, ensuring the rx gearbox
        // is aligned.
        ------------------------------------------------------------------------- */
        repeat(150)
            @(posedge clk);

        repeat(20) begin

            generate_tx_data_stream(tx_data);

            $display("Size of TX DATA: %0d", tx_data.size());

            fork
                begin
                    axi_if.drive_data_axi_stream(tx_data);
                    $display("Completed data transmission");
                end
                begin
                    sample_data(rx_data);    
                    $display("Completed data Sampling"); 
                end
            join

            scb.verify_data(rx_data, tx_data);

        end

        #100;
        scb.print_summary();
        $finish;

    end


endmodule : eth_top