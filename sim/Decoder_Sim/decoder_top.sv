`include "../Common/scoreboard_base.sv"

module decoder_top;

    /* Parameters */
    localparam DATA_WIDTH = 32;
    localparam CTRL_WIDTH = 4;
    localparam HDR_WIDTH = 2;

    /* Signal Descriptions */
    logic clk;
    logic i_reset_n;

    logic [DATA_WIDTH-1:0]      rx_data;
    logic                       rx_data_valid;
    logic [HDR_WIDTH-1:0]       rx_hdr;
    logic                       rx_hdr_valid;
    logic                       block_lock;

    logic [DATA_WIDTH-1:0]      xgmii_txd;
    logic [CTRL_WIDTH-1:0]      xgmii_txc;
    logic                       xgmii_valid;

    scoreboard_base scb = new();

    /* DUT Instantiation */
    xgmii_decoder#( 
        .DATA_WIDTH(DATA_WIDTH),
        .CTRL_WIDTH(CTRL_WIDTH),
        .HDR_WIDTH(HDR_WIDTH)
    )DUT(
        .i_clk(clk),
        .i_reset_n(i_reset_n),
        // De-Scrambler Interface
        .i_rx_data(rx_data),
        .i_rx_data_valid(rx_data_valid),
        .i_rx_hdr(rx_hdr),
        .i_rx_hdr_valid(rx_hdr_valid),
        .i_block_lock(block_lock),
        // XGMII Interface w/ MAC
        .o_xgmii_txd(xgmii_txd),
        .o_xgmii_txc(xgmii_txc),
        .o_xgmii_valid(xgmii_valid)
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


        #100;
        $finish;

    end


endmodule : xgmii_encoder_top