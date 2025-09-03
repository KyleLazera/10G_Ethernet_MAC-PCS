module rx_gearbox #(
    parameter DATA_WIDTH = 32,
    parameter HDR_WIDTH = 2
) (
    input logic i_clk,
    input logic i_reset_n,

    // Interface with De-Scrambler
    output logic [DATA_WIDTH-1:0]   o_tx_data,
    output logic                    o_tx_data_valid,

    //Interface with Decoder
    output logic [HDR_WIDTH-1:0]    o_tx_sync_hdr,
    output logic                    o_tx_sync_hdr_valid,
    output logic                    o_block_lock,

    //Interface with Transceiver
    input logic [DATA_WIDTH-1:0]    i_rx_data
);
// --------------- Signals --------------- //
logic   lock_state_slip;

// --------------- Block Sync Instantiation --------------- //
block_sync #(
    .DATA_WIDTH(DATA_WIDTH),
    .HDR_WIDTH(HDR_WIDTH)
) block_sync_inst (
    .i_clk(i_clk),
    .i_reset_n(i_reset_n),

    // Gearbox-to-Scrambler Interface
    .o_tx_data(o_tx_data),
    .o_tx_sync_hdr(o_tx_sync_hdr),
    .o_tx_sync_hdr_valid(o_tx_sync_hdr_valid),
    .o_tx_data_valid(o_tx_data_valid),
    .i_slip(lock_state_slip), 

    // Gearbox Data Input
    .i_rx_data(i_rx_data)
);

// --------------- Lock State Instantation --------------- //
lock_state #(
    .HDR_WIDTH(HDR_WIDTH)
) lock_state_inst (
    .i_clk(i_clk),
    .i_reset_n(i_reset_n),

    // Interface with rx block sync
    .i_hdr(o_tx_sync_hdr),
    .i_hdr_valid(o_tx_sync_hdr_valid),
    .o_slip(lock_state_slip), 

    // Interface with decoder
    .o_block_lock(o_block_lock)
);

endmodule