`timescale 1ns / 1ps

/*
 * The TX MAC is responsible for receving data via AXI-stream, packaging the data
 * into an ethernet packet (preamble, SFD, Data, IFG), and outputting the ethernet
 * packet via XGMII to the PCS.
 */

module tx_mac #(
    parameter XGMII_DATA_WIDTH = 32,
    parameter XGMII_CTRL_WIDTH = 4,
    
    parameter AXIS_KEEP_WIDTH = XGMII_DATA_WIDTH/8
)(
    input logic   i_clk,
    input logic   i_reset_n,

    // XGMII Interface
    output logic [XGMII_DATA_WIDTH-1:0]     o_xgmii_txd,
    output logic [XGMII_CTRL_WIDTH-1:0]     o_xgmii_ctrl,
    output logic                            o_xgmii_valid,
    input logic                             i_xgmii_pause,

    // AXI-Stream Interface
    input logic [XGMII_DATA_WIDTH-1:0]      s_axis_tdata,
    input logic [AXIS_KEEP_WIDTH-1:0]       s_axis_tkeep,
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

localparam CRC_WIDTH = 32;

typedef enum logic[2:0] {
    IDLE,
    DATA,
    PADDING,
    CRC,
    IFG
}state_t;

/* ---------------- Counter Logic ---------------- */ 
logic [CNTR_WIDTH-1:0]          data_cntr = '0;

//TODO: Needs to reset to 0 only when we get a tlast
always_ff @(posedge i_clk) begin
    if (!i_reset_n) begin
        data_cntr <= '0;
    end else if (s_axis_tvalid & s_axis_trdy) begin
        data_cntr <= (data_cntr == MIN_PACKETS) ? '0 : data_cntr + 1;
    end else
        data_cntr <= data_cntr;
end

/* ---------------- CRC32 Logic ---------------- */ 

logic                       sof = 1'b0;
logic [CRC_WIDTH-1:0]       crc_state = 32'hFFFFFFFF;
logic [XGMII_DATA_WIDTH-1:0]crc_data_out, crc_data_in;
logic [CRC_WIDTH-1:0]       crc_state_next;
logic [AXIS_KEEP_WIDTH-1:0] crc_data_valid = 1'b0;

always_ff@(posedge i_clk) begin
    if (!i_reset_n) begin
        crc_state <= 32'hFFFFFFFF;
    end else begin
        crc_state <= crc_state_next;
    end
end

crc32#(
    .DATA_WIDTH(XGMII_DATA_WIDTH),
    .CRC_WIDTH(32)
) CRC_Slicing_by_4 (
    .i_clk(i_clk),
    .i_reset_n(sof | i_reset_n),
    .i_data(crc_data_in),
    .i_crc_state(crc_state),
    .i_data_valid(crc_data_valid),
    .o_crc(crc_data_out),
    .o_crc_state(crc_state_next)
);

/* ---------------- State Machine Logic ---------------- */ 
state_t                             state_reg = IDLE;
logic [(2*XGMII_DATA_WIDTH)-1:0]    data_pipe;
logic [(2*XGMII_CTRL_WIDTH)-1:0]    ctrl_pipe;
logic                               s_axis_trdy_reg = 1'b0;
logic                               xgmii_valid_reg = 1'b0;

always_ff @(posedge i_clk) begin
    if (!i_reset_n) begin
        state_reg <= IDLE;
        sof <= 1'b0;

        // Init data to idle frames 
        data_pipe <= {8{8'h07}};
        ctrl_pipe <= 8'hFF;
        xgmii_valid_reg <= 1'b1;
    end else begin

        sof <= 1'b0;
        xgmii_valid_reg <= 1'b1;

        // CRC Data Input
        crc_data_in <= s_axis_tdata;
        crc_data_valid <= s_axis_tkeep;

        s_axis_trdy_reg <= 1'b0;

        case(state_reg)
            IDLE: begin
                if(s_axis_tvalid) begin
                    data_pipe <= {ETH_SFD, {6{ETH_HDR}}, XGMII_START};
                    ctrl_pipe <= 8'h01;
                    sof <= 1'b1;
                    state_reg <= DATA;
                end
            end
            DATA: begin
                s_axis_trdy_reg <= !i_xgmii_pause;
                data_pipe <= {s_axis_tdata, data_pipe[(2*XGMII_DATA_WIDTH)-1 -: 32]};
                ctrl_pipe <= {4'h0, ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1 -: 4]};

                if (s_axis_tlast) begin
                    s_axis_trdy_reg <= 1'b0;
                    state_reg <= (data_cntr < MIN_PACKETS) ? PADDING : CRC;
                end
            end
            PADDING: begin

            end
            CRC: begin
                data_pipe <= {crc_data_out, data_pipe[(2*XGMII_DATA_WIDTH)-1 -: 32]};
                ctrl_pipe <= {4'h0, ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1 -: 4]};
                state_reg <= IFG;
            end
            IFG: begin

            end
        endcase
    end
end

/* ---------------- Output Logic ---------------- */ 
assign o_xgmii_txd = data_pipe[31:0];
assign o_xgmii_ctrl = ctrl_pipe[3:0];
assign s_axis_trdy = s_axis_trdy_reg;



endmodule