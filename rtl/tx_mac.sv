`timescale 1ns / 1ps

/*
 * The TX MAC is responsible for receving data via AXI-stream, packaging the data
 * into an ethernet packet (preamble, SFD, Data, IFG), and outputting the ethernet
 * packet via XGMII to the PCS.
 */

module tx_mac #(
    parameter XGMII_DATA_WIDTH = 32,
    parameter XGMII_CTRL_WIDTH = 4
)(
    input logic   i_clk,
    input logic   i_resent_n,

    // XGMII Interface
    output logic [XGMII_DATA_WIDTH-1:0]     o_xgmii_txd,
    output logic [XGMII_CTRL_WIDTH-1:0]     o_xgmii_ctrl,
    output logic                            o_xgmii_valid,
    input logic                             i_xgmii_pause,

    // AXI-Stream Interface
    input logic [XGMII_DATA_WIDTH-1:0]      s_axis_tdata,
    input logic                             s_axis_tvalid,
    input logic                             s_axis_tlast,
    output logic                            s_axis_trdy
);

/* Parameters */

localparam [7:0] ETH_HDR = 8'h55;               
localparam [7:0] ETH_SFD = 8'hD5;  
localparam [7:0] ETH_PAD = 8'h00;   

localparam [7:0] XGMII_START = 8'hFB;
localparam [7:0] XGMII_TERM = 8'hFD;

localparam MIN_PACKETS = 15;
localparam CNTR_WIDTH = $clog2(MIN_PACKETS) + 1;

/* ---------------- Counter Logic ---------------- */ 
logic [CNTR_WIDTH-1:0]          data_cntr = '0;

always_ff @(posedge i_clk) begin
    if (!i_resent_n) begin
        data_cntr <= '0;
    end else if (s_axis_tvalid & s_axis_trdy) begin
        data_cntr <= (data_cntr == MIN_PACKETS) ? '0 : data_cntr + 1;
    end else
        data_cntr <= data_cntr;
end

/* ---------------- State Machine Logic ---------------- */ 
logic                               s_axis_trdy_reg = 1'b0;
logic                               pad_packet = 1'b0;
logic [(2*XGMII_DATA_WIDTH)-1:0]    data_pipe = '0;
logic [(2*XGMII_CTRL_WIDTH)-1:0]    ctrl_pipe = '0;

always_ff @(posedge i_clk) begin
    if (!i_resent_n) begin
        data_pipe <= 64'h0707070707070707;
        ctrl_pipe <= 8'hFF;
        pad_packet <= 1'b0;
    end else begin

        if (s_axis_tvalid & !s_axis_trdy) begin
            data_pipe <= {ETH_SFD, ETH_HDR, ETH_HDR, ETH_HDR, ETH_HDR, ETH_HDR, ETH_HDR, XGMII_START};
            ctrl_pipe <= 8'h1;
            s_axis_trdy_reg <= 1'b1;
        end else if (s_axis_tvalid & s_axis_trdy) begin
            data_pipe <= {s_axis_tdata, data_pipe[(2*XGMII_DATA_WIDTH)-1 -: 32]};
            ctrl_pipe <= {4'h0, ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1 -: 4]};
            s_axis_trdy_reg <= 1'b1;

            if (s_axis_tlast) begin
                if ((data_cntr > MIN_PACKETS)) begin
                    //TODO: Append CRC followed by stop bit
                    s_axis_trdy_reg <= 1'b0;
                end else begin
                    //TODO: Add padding
                    pad_packet <= 1'b1;
                end
            end 

        end

    end
end

/* ---------------- Output Logic ---------------- */ 
assign o_xgmii_txd = data_pipe[XGMII_DATA_WIDTH-1:0];
assign o_xgmii_ctrl = ctrl_pipe[XGMII_CTRL_WIDTH-1:0];
assign s_axis_trdy = s_axis_trdy_reg;



endmodule