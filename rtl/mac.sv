module mac #(
    parameter DATA_WIDTH = 32,
    parameter CTRL_WIDTH = DATA_WIDTH/8
) (
    /* TX MAC Signals */
    input logic                         i_tx_clk,
    input logic                         i_tx_reset_n,

    input logic [DATA_WIDTH-1:0]        s_axis_tdata,
    input logic [CTRL_WIDTH-1:0]        s_axis_tkeep,
    input logic                         s_axis_tvalid,
    input logic                         s_axis_tlast,
    output logic                        s_axis_trdy,

    output logic [DATA_WIDTH-1:0]       o_xgmii_txd,
    output logic [CTRL_WIDTH-1:0]       o_xgmii_ctrl,
    output logic                        o_xgmii_valid,
    input logic                         i_xgmii_pause,

    /* RX MAC Signals */    
    input logic                         i_rx_clk,
    input logic                         i_rx_reset_n,

    input logic [DATA_WIDTH-1:0]        i_xgmii_data,
    input logic [CTRL_WIDTH-1:0]        i_xgmii_ctrl,
    input logic                         i_xgmii_valid,

    output logic [DATA_WIDTH-1:0]       o_data,
    output logic [CTRL_WIDTH-1:0]       o_data_keep,
    output logic                        o_data_valid,
    output logic                        o_data_err
);

/* TX Data Path */

tx_mac #(
    .XGMII_DATA_WIDTH(DATA_WIDTH),
    .XGMII_CTRL_WIDTH(CTRL_WIDTH)
) tx_mac_module (
    .i_clk(i_tx_clk),
    .i_reset_n(i_tx_reset_n),

    // XGMII Interface
    .o_xgmii_txd(o_xgmii_txd),
    .o_xgmii_ctrl(o_xgmii_ctrl),
    .o_xgmii_valid(o_xgmii_valid),
    .i_xgmii_pause(i_xgmii_pause),

    // AXI-Stream Interface
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_trdy(s_axis_trdy)
);

/* RX Data Path */

rx_mac #(
    .XGMII_DATA_WIDTH(DATA_WIDTH),
    .O_DATA_WIDTH(DATA_WIDTH)
) rx_mac_module (
    .i_clk(i_rx_clk),
    .i_reset_n(i_rx_reset_n),

    // XGMII INput Interface
    .i_xgmii_data(i_xgmii_data),
    .i_xgmii_ctrl(i_xgmii_ctrl),
    .i_xgmii_valid(i_xgmii_valid),

    .o_data(o_data),
    .o_data_keep(o_data_keep),
    .o_data_valid(o_data_valid),
    .o_data_err(o_data_err)
);

endmodule