module pcs#(
    parameter DATA_WIDTH = 32,
    parameter CTRL_WIDTH = 4,
    parameter HDR_WIDTH = 2
) (
    // Clock & Reset (from GTY Transceiver)
    input  wire                  gty_tx_usr_clk,      // GTY TX user clock (txusrclk2_out)
    input  wire                  gty_tx_usr_reset,    // GTY TX user reset 

    // MAC to PCS (XGMII) Interface
    input logic [DATA_WIDTH-1:0] i_xgmii_txd,         // XGMII Data in 
    input logic [CTRL_WIDTH-1:0] i_xgmii_txc,         // XGMII Control Signal
    input logic i_xgmii_valid,                        // XGMII Data Valid
    output logic o_xgmii_pause,                       // Pauses MAC (needed for gearbox)

    // PCS to GTY Transceiver Transmit Interface
    output wire [DATA_WIDTH-1:0] pcs_tx_gearbox_data  // TX data output to GTY transceiver 
);

/* -------------------- TX Data Path -------------------- */


/* 64b/66b Encoder */

logic [DATA_WIDTH-1:0]  encoder_data;
logic                   encoder_valid;
logic [HDR_WIDTH-1:0]   encoder_hdr;
logic                   scrambler_trdy;

xgmii_encoder #(
    .DATA_WIDTH(DATA_WIDTH),
    .HDR_WIDTH(HDR_WIDTH)
) encoder_64b_66b (
    .i_clk(gty_tx_usr_clk),
    .i_reset_n(gty_tx_usr_reset),

    // MAC to PCS (XGMII) Interface
    .i_xgmii_txd(i_xgmii_txd),
    .i_xgmii_txc(i_xgmii_txc),
    .i_xgmii_valid(i_xgmii_valid),
    .o_xgmii_pause(o_xgmii_pause),

    // 64b/66b Encoder to Scrambler Interface
    .o_tx_data_valid(encoder_valid),
    .o_tx_data(encoder_data),
    .o_tx_sync_hdr(encoder_hdr),
    .o_tx_encoding_err(),
    // Back Pressure from GearBox
    .i_rx_trdy(scrambler_trdy)    
);

/* Scrambler */

logic [DATA_WIDTH-1:0]  scrambler_data;
logic                   scrambler_valid;
logic [HDR_WIDTH-1:0]   sync_hdr_pipe;
logic                   gerabox_trdy;

always_ff @(posedge gty_tx_usr_clk)
    sync_hdr_pipe <= encoder_hdr;

scrambler #(
    .DATA_WIDTH(DATA_WIDTH)
) scrmbler (
    .i_clk(gty_tx_usr_clk),
    .i_reset_n(gty_tx_usr_reset),

    // Encoder to Scrambler
    .i_rx_data_valid(encoder_valid),
    .i_rx_data(encoder_data),
    .o_tx_trdy(scrambler_trdy),

    // Output to Gearbox
    .o_tx_data_valid(scrambler_valid),
    .o_tx_data(scrambler_data),
    .i_rx_trdy(gerabox_trdy)
);

/* Custom Synchronous Gearbox */

gearbox #(
    .DATA_WIDTH(DATA_WIDTH)
) sync_gearbox (

    .i_clk(gty_tx_usr_clk),
    .i_reset_n(gty_tx_usr_reset),

    // Encoded Data & Header input
    .i_rx_data(scrambler_data),
    .i_rx_data_valid(scrambler_valid),
    .i_rx_sync_hdr(sync_hdr_pipe),
    .o_tx_trdy(gerabox_trdy),

    // Gearbox Data Output
    .o_tx_data(pcs_tx_gearbox_data)
);

/* -------------------- RX Data Path -------------------- */

endmodule