`timescale 1ns / 1ps

module xgmii_encoder
#(
    
    parameter DATA_WIDTH    = 32,
    parameter CTRL_WIDTH    = (DATA_WIDTH/8),
    parameter HDR_WIDTH     = 2
)
(
    input logic i_clk,
    input logic i_reset_n,

    // MAC to PCS (XGMII) Interface
    input logic [DATA_WIDTH-1:0] i_xgmii_txd,
    input logic [CTRL_WIDTH-1:0] i_xgmii_txc,
    output logic o_xgmii_pause,

    // 64b/66b Encoder to Scrambler Interface
    output logic [DATA_WIDTH-1:0] o_encoded_data,
    output logic [HDR_WIDTH-1:0] o_sync_hdr,
    output logic o_encoding_err
);

/* XGMII Coded Signals */
localparam XGMII_IDLE   = 8'h07,
           XGMII_LPI    = 8'h06,
           XGMII_START  = 8'hFB,
           XGMII_TERM   = 8'hFD,
           XGMII_ERROR  = 8'hFE,
           XGMII_SEQ_OS = 8'h9C,
           XGMII_RES_0  = 8'h1C,
           XGMII_RES_1  = 8'h3C,
           XGMII_RES_2  = 8'h7C,
           XGMII_RES_3  = 8'hBC,
           XGMII_RES_4  = 8'hDC,
           XGMII_RES_5  = 8'hF7,
           XGMII_SIG_OS = 8'h5C;

/* 10G-BASER Control COdes */
localparam CTRL_IDLE  = 7'h00,
           CTRL_LPI   = 7'h06,
           CTRL_ERROR = 7'h1E,
           CTRL_RES_0 = 7'h2D,
           CTRL_RES_1 = 7'h33,
           CTRL_RES_2 = 7'h4B,
           CTRL_RES_3 = 7'h55,
           CTRL_RES_4 = 7'h66,
           CTRL_RES_5 = 7'h78;

/* 64b/66b Block Type Fields */
localparam BLOCK_CTRL = 8'h1E,      // C0 C1 C2 C3 C4 C5 C6 C7
           BLOCK_OS_4 = 8'h2D,      // C0 C1 C2 C3 04 D5 D6 D7
           BLOCK_START_4 = 8'h33,   // C0 C1 C2 C3 S4 D5 D6 D7
           BLOCK_START_4_OS = 8'h66, // O0 D1 D2 D3 S4 D5 D6 D7
           BLOCK_OS_0_4 = 8'h55,     // O0 D1 D2 D3 04 D5 D6 D7
           BLOCK_START_0 = 8'h78,   // S0 D1 D2 D3 D4 D5 D6 D7
           BLOCK_OS_0 = 8'h4B,      // O0 D1 D2 D3 C4 C5 C6 C7   
           BLOCK_TERM_0 = 8'h87,    // T0 C1 C2 C3 C4 C5 C6 C7
           BLOCK_TERM_1 = 8'h99,    // D0 T1 C2 C3 C4 C5 C6 C7
           BLOCK_TERM_2 = 8'hAA,    // D0 D1 T2 C3 C4 C5 C6 C7
           BLOCK_TERM_3 = 8'hB4,    // D0 D1 D2 T3 C4 C5 C6 C7
           BLOCK_TERM_4 = 8'hCC,    // D0 D1 D2 D3 T4 C5 C6 C7
           BLOCK_TERM_5 = 8'hD2,    // D0 D1 D2 D3 D4 T5 C6 C7
           BLOCK_TERM_6 = 8'hE1,    // D0 D1 D2 D3 D4 D5 T6 C7
           BLOCK_TERM_7 = 8'hFF;    // D0 D1 D2 D3 D4 D5 D6 77   
           

/* DataPath Registers */
logic [DATA_WIDTH-1:0] xgmii_txd_payload = 'b0; 
logic [CTRL_WIDTH-1:0] xgmii_ctrl_payload = 'b0;
logic [DATA_WIDTH-1:0] encoded_data_reg [1:0];
logic xgmii_pause_reg = 1'b0;

/* Control Registers */
logic cycle_cntr = 1'b0;

///////////////////////////////////////////////////////////////////
// Used to keep track of whether we are on an even (cycle_cntr = 0)
// or odd (cycle_cntr = 1) cycle. This is important because the 
// encoder operates on 64 bit blocks of data, however, the input
// XGMII bus is 32 bits wide. This counter keeps track of when 2 cycles
// worth of data have been recieved.
///////////////////////////////////////////////////////////////////
always_ff@(posedge i_clk) begin
    if(!i_reset_n)
        cycle_cntr <= 1'b0;
    else
        cycle_cntr <= ~cycle_cntr;
end

// Shift Register logic 
always_ff@(posedge i_clk) begin
    xgmii_txd_payload <= i_xgmii_txd;
    xgmii_ctrl_payload <= i_xgmii_txc;
end

logic [DATA_WIDTH*7/8-1:0] encoded_ctrl_byte [1:0];
logic idle_frame_comb;
logic start_frame_comb;
logic data_frame_comb;
logic stop_0_frame_comb;
logic stop_1_frame_comb;
logic stop_2_frame_comb;
logic stop_3_frame_comb;


always_comb begin
    idle_frame_comb = (i_xgmii_txc == 4'b1111) & (i_xgmii_txd == 32'h07070707);
    start_frame_comb = (i_xgmii_txc == 4'b0001) & (i_xgmii_txd[7:0] == XGMII_START);
    data_frame_comb = (i_xgmii_txc == 4'b0000);
    stop_0_frame_comb = (i_xgmii_txc == 4'b1111) & (i_xgmii_txd == 32'h070707FD);
    stop_1_frame_comb = (i_xgmii_txc == 4'b1110) & (i_xgmii_txd[31:8] == 24'h070707FD);
    stop_2_frame_comb = (i_xgmii_txc == 4'b1100) & (i_xgmii_txd[31:16] == 16'h0707FD);
    stop_3_frame_comb = (i_xgmii_txc == 4'b1000) & (i_xgmii_txd[31:24] == XGMII_TERM);
end

logic idle_frame_reg = 1'b0;
logic start_frame_reg = 1'b0;
logic data_frame_reg = 1'b0;
logic stop_0_frame_reg = 1'b0;
logic stop_1_frame_reg = 1'b0;
logic stop_2_frame_reg = 1'b0;
logic stop_3_frame_reg = 1'b0;


always_ff@(posedge i_clk)  begin
    idle_frame_reg <= idle_frame_comb;  
    start_frame_reg <= start_frame_comb; 
    data_frame_reg <= data_frame_comb;
    stop_0_frame_reg <= stop_0_frame_comb;
    stop_1_frame_reg <= stop_1_frame_comb; 
    stop_2_frame_reg <= stop_2_frame_comb;
    stop_3_frame_reg <= stop_3_frame_comb; 
end

logic send_start_lane_0;
logic send_start_lane_4;

assign send_start_lane_0 = cycle_cntr & data_frame_comb & start_frame_reg;
assign send_start_lane_4 = cycle_cntr & start_frame_comb & idle_frame_reg;

logic send_start_lane_0_reg;
logic send_start_lane_4_reg;


always_ff@(posedge i_clk) begin
    send_start_lane_0_reg <= send_start_lane_0;
    send_start_lane_4_reg <= send_start_lane_4;
end

integer i;

always_ff@(posedge i_clk) begin

    for(i = 0; i < CTRL_WIDTH; i++) begin
        if (i_xgmii_txc[i]) begin
            case(i_xgmii_txd[8*i +: 8])
                XGMII_IDLE:  encoded_ctrl_byte[~cycle_cntr][7*i +: 7] <= CTRL_IDLE;
                XGMII_LPI:   encoded_ctrl_byte[~cycle_cntr][7*i +: 7] <= CTRL_LPI;
                XGMII_ERROR: encoded_ctrl_byte[~cycle_cntr][7*i +: 7] <= CTRL_ERROR;
                XGMII_RES_0: encoded_ctrl_byte[~cycle_cntr][7*i +: 7] <= CTRL_RES_0;
                XGMII_RES_1: encoded_ctrl_byte[~cycle_cntr][7*i +: 7] <= CTRL_RES_1;
                XGMII_RES_2: encoded_ctrl_byte[~cycle_cntr][7*i +: 7] <= CTRL_RES_2;
                XGMII_RES_3: encoded_ctrl_byte[~cycle_cntr][7*i +: 7] <= CTRL_RES_3;
                XGMII_RES_4: encoded_ctrl_byte[~cycle_cntr][7*i +: 7] <= CTRL_RES_4;
                XGMII_RES_5: encoded_ctrl_byte[~cycle_cntr][7*i +: 7] <= CTRL_RES_5;
                default: encoded_ctrl_byte[~cycle_cntr][7*i +: 7] <= CTRL_ERROR;
            endcase
        end
    end
end

logic [DATA_WIDTH-1:0] encoded_word [1:0];

always_ff@(posedge i_clk) begin

    encoded_word[0] <=  (send_start_lane_0) ? {i_xgmii_txd[31:8], BLOCK_START_0} :
                        (send_start_lane_0_reg) ? {i_xgmii_txd} :
                        (send_start_lane_4) ? {24'h0, BLOCK_START_4} :
                        (send_start_lane_4_reg) ? {i_xgmii_txd[31:8], 8'h0} :
                        32'h0;


end

endmodule