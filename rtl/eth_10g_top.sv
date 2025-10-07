
module eth_10g_top #(
    parameter DATA_WIDTH = 32,
    parameter CTRL_WIDTH = DATA_WIDTH/8
)(
    input logic                     i_tx_clk,
    input logic                     i_tx_reset_n,

    /* TX MAC Interface */
    input logic [DATA_WIDTH-1:0]    s_axis_tdata,
    input logic [CTRL_WIDTH-1:0]    s_axis_tkeep,
    input logic                     s_axis_tvalid,
    input logic                     s_axis_tlast,
    output logic                    s_axis_trdy,

    /* TX Transceiever Interface */
    output logic [DATA_WIDTH-1:0]   pcs_tx_gearbox_data,

    input logic                     i_rx_clk,
    input logic                     i_rx_reset_n,

    /* RX MAC Interface */
    output logic [DATA_WIDTH-1:0]   o_data,
    output logic [CTRL_WIDTH-1:0]   o_data_keep,
    output logic                    o_data_valid,
    output logic                    o_data_err,

    /* RX Transceiever Interface */
    input logic [DATA_WIDTH-1:0]    pcs_rx_gearbox_data
);

/* Signal Declarations */

logic [DATA_WIDTH-1:0]  tx_mac_xgmii_txd;
logic [CTRL_WIDTH-1:0]  tx_mac_xgmii_ctrl;
logic                   tx_mac_xgmii_valid;
logic                   xgmii_pause;

logic [DATA_WIDTH-1:0]  rx_mac_xgmii_rxd;
logic [CTRL_WIDTH-1:0]  rx_mac_xgmii_ctrl;
logic                   rx_mac_xgmii_valid;

/* MAC Instantiation */

mac #(
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH)
) eth_mac (
    /* TX MAC Signals */
    .i_tx_clk(i_tx_clk),
    .i_tx_reset_n(i_tx_reset_n),

    .s_axis_tdata(s_axis_tdata),
    .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_trdy(s_axis_trdy),

    .o_xgmii_txd(tx_mac_xgmii_txd),
    .o_xgmii_ctrl(tx_mac_xgmii_ctrl),
    .o_xgmii_valid(tx_mac_xgmii_valid),
    .i_xgmii_pause(xgmii_pause),

    /* RX MAC Signals */    
    .i_rx_clk(i_rx_clk),
    .i_rx_reset_n(i_rx_reset_n),

    .i_xgmii_data(rx_mac_xgmii_rxd),
    .i_xgmii_ctrl(rx_mac_xgmii_ctrl),
    .i_xgmii_valid(rx_mac_xgmii_valid),

    .o_data(o_data),
    .o_data_keep(o_data_keep),
    .o_data_valid(o_data_valid),
    .o_data_err(o_data_err)
);

/* PCS Instantiation */

pcs #(
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH),
    .HDR_WIDTH(2)
) eth_pcs (
    // TX Data Path Clock
    .gty_tx_usr_clk(i_tx_clk),      
    .gty_tx_usr_reset(i_tx_reset_n), 

    // RX Data Path Clock
    .gty_rx_usr_clk(i_rx_clk),      
    .gty_rx_usr_reset(i_rx_reset_n),    

    // MAC to PCS (XGMII) Interface - TX
    .i_xgmii_txd(tx_mac_xgmii_txd),         
    .i_xgmii_txc(tx_mac_xgmii_ctrl),         
    .i_xgmii_valid(tx_mac_xgmii_valid),                        
    .o_xgmii_pause(xgmii_pause),                     

    // MAC to PCS (XGMII) Interface - RX
    .o_xgmii_rxd(rx_mac_xgmii_rxd),
    .o_xgmii_rxc(rx_mac_xgmii_ctrl),
    .o_xgmii_rvalid(rx_mac_xgmii_valid),

    // PCS to GTY Transceiver Transmit Interface
    .pcs_tx_gearbox_data(pcs_tx_gearbox_data),  
    .pcs_rx_gearbox_data(pcs_rx_gearbox_data)   
);

endmodule