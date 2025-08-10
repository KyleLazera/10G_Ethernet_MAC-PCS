`timescale 1ns / 1ps

/*
 * This module holds the logic for 64b/66b encoding of XGMII data according
 * to the IEEE Std 802.3-2012 Clause 49. This module recieves 32 bit XGMII
 * inputs and outputs 32 bit encoded words along with the synchronous header
 * in parallel.
 */

 // TODO: Add support for reamining codes

module xgmii_encoder
#(
    
    parameter DATA_WIDTH    = 32,
    parameter HDR_WIDTH     = 2,
    parameter CTRL_WIDTH    = (DATA_WIDTH/8)
)
(
    input logic i_clk,
    input logic i_reset_n,

    // MAC to PCS (XGMII) Interface
    input logic [DATA_WIDTH-1:0] i_xgmii_txd,
    input logic [CTRL_WIDTH-1:0] i_xgmii_txc,
    input logic i_xgmii_valid,
    output logic o_xgmii_pause,

    // 64b/66b Encoder to Scrambler Interface
    output logic o_encoded_data_valid,
    output logic [DATA_WIDTH-1:0] o_encoded_data,
    output logic [HDR_WIDTH-1:0] o_sync_hdr,
    output logic o_encoding_err,

    // Back Pressure from GearBox
    input logic i_gearbox_pause
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
           

/* Data Path Registers */
logic [DATA_WIDTH-1:0] xgmii_txd_payload [1:0]; 
logic [CTRL_WIDTH-1:0] xgmii_ctrl_payload;
logic [DATA_WIDTH-1:0] encoded_word [1:0];
logic [1:0] sync_hdr_reg = 2'b0;
logic encoded_word_select [1:0];
logic data_valid = 1'b0;
logic gearbox_pause;

/* Control Registers */
logic cycle_cntr = 1'b0;

// ----------------------------------------------------------------------
// Used to keep track of whether we are on an even (cycle_cntr = 0)
// or odd (cycle_cntr = 1) cycle. This is important because the 
// encoder operates on 64 bit blocks of data, however, the input
// XGMII bus is 32 bits wide. This counter keeps track of when 2 cycles
// worth of data have been recieved.
// ----------------------------------------------------------------------
always_ff@(posedge i_clk) begin
    if(!i_reset_n)
        cycle_cntr <= 1'b0;
    else if (i_xgmii_valid)
        cycle_cntr <= ~cycle_cntr;
end

// Shift Register logic 
always_ff@(posedge i_clk) begin
    xgmii_ctrl_payload <= i_xgmii_txc;

    xgmii_txd_payload[0] <= i_xgmii_txd;
    xgmii_txd_payload[1] <= xgmii_txd_payload[0];
end

// Determine the header based on the control input:
//  1) Data frame: Head = 2'b01
//  2) Control Frame = 2'b10
always_ff @(posedge i_clk)
    if (cycle_cntr)
        sync_hdr_reg <= (|{xgmii_ctrl_payload, i_xgmii_txc}) ? 2'b10 : 2'b01;

always_ff @(posedge i_clk)
    gearbox_pause <= i_gearbox_pause;

/******************* Initial Word Encoding Logic *******************/

logic idle_frame_comb;
logic start_frame_comb;
logic data_frame_comb;
logic stop_0_frame_comb;
logic stop_1_frame_comb;
logic stop_2_frame_comb;
logic stop_3_frame_comb;

logic idle_frame_reg = 1'b0;
logic start_frame_reg = 1'b0;
logic data_frame_reg = 1'b0;
logic stop_0_frame_reg = 1'b0;
logic stop_1_frame_reg = 1'b0;
logic stop_2_frame_reg = 1'b0;
logic stop_3_frame_reg = 1'b0;

// -----------------------------------------------------------------------------
// To achieve lower-latency in the design, each 32 bit word is encoded as
// soon as it becomes available on the input line via combinational logic.
// This means that as each 32-bit word arrives, we can determine whether it 
// holds data or control info such as a start condition, idle frame or 
// a stop condition.
// -----------------------------------------------------------------------------

assign idle_frame_comb = i_xgmii_valid & (i_xgmii_txc == 4'b1111) & (i_xgmii_txd == 32'h07070707);
assign start_frame_comb = i_xgmii_valid & (i_xgmii_txc == 4'b0001) & (i_xgmii_txd[7:0] == XGMII_START);
assign data_frame_comb = i_xgmii_valid & (i_xgmii_txc == 4'b0000);
assign stop_0_frame_comb = i_xgmii_valid & (i_xgmii_txc == 4'b1111) & (i_xgmii_txd == 32'h070707FD);
assign stop_1_frame_comb = i_xgmii_valid & (i_xgmii_txc == 4'b1110) & (i_xgmii_txd[31:8] == 24'h0707FD);
assign stop_2_frame_comb = i_xgmii_valid & (i_xgmii_txc == 4'b1100) & (i_xgmii_txd[31:16] == 16'h07FD);
assign stop_3_frame_comb = i_xgmii_valid & (i_xgmii_txc == 4'b1000) & (i_xgmii_txd[31:24] == XGMII_TERM);

// -----------------------------------------------------------------------------
// Because we need to operate on 2, 32-bit words, once we have encoded an 
// input word, we need still need to encode the most signficiant word of the 
// 64 bit input. Therefore, we latch the encoded status of the first 32 bit 
// word (This acts similar to a shift register).
// -----------------------------------------------------------------------------
always_ff@(posedge i_clk)  begin
    idle_frame_reg <= idle_frame_comb;  
    start_frame_reg <= start_frame_comb; 
    data_frame_reg <= data_frame_comb;
    stop_0_frame_reg <= stop_0_frame_comb;
    stop_1_frame_reg <= stop_1_frame_comb; 
    stop_2_frame_reg <= stop_2_frame_comb;
    stop_3_frame_reg <= stop_3_frame_comb; 
end

/******************* Block Field Encoding Logic *******************/

logic encoded_data_valid;
logic send_idle_frame;
logic send_start_lane_0;
logic send_start_lane_4;
logic send_term_lane_0;
logic send_term_lane_1;
logic send_term_lane_2;
logic send_term_lane_3;
logic send_term_lane_4;
logic send_term_lane_5;
logic send_term_lane_6;
logic send_term_lane_7;

logic encoded_data_valid_reg = 1'b0;
logic send_idle_frame_reg = 1'b0;
logic send_start_lane_0_reg = 1'b0;
logic send_start_lane_4_reg = 1'b0;
logic send_term_lane_0_reg = 1'b0;
logic send_term_lane_1_reg = 1'b0;
logic send_term_lane_2_reg = 1'b0;
logic send_term_lane_3_reg = 1'b0;
logic send_term_lane_4_reg = 1'b0;
logic send_term_lane_5_reg = 1'b0;
logic send_term_lane_6_reg = 1'b0;
logic send_term_lane_7_reg = 1'b0;

// -----------------------------------------------------------------------------
// When cycle_cntr == 1, this indicates we are currently receiving our
// 2nd 32-bit word (most significant word). This means, we can know use the 
// contents of our latched encoded state from the previous word and the
// combinational value for the current input word. To determine this,
// the following assign statements can be read as such:
//
// type_of_data = most_significant_word_encoding & least_significant_word_encoding
//
// As an example, we know if the least significant word was encoded to have a 
// start condition and the current word being encoded contains data, this 
// indicates a start condition at lane 0 (Start conditions can only occur in
// lane 0 or 4).
// -----------------------------------------------------------------------------
assign encoded_data_valid = cycle_cntr & i_xgmii_valid;
assign send_idle_frame = cycle_cntr & idle_frame_comb & idle_frame_reg;
assign send_start_lane_0 = cycle_cntr & data_frame_comb & start_frame_reg;
assign send_start_lane_4 = cycle_cntr & start_frame_comb & idle_frame_reg;
assign send_term_lane_0 = cycle_cntr & idle_frame_comb & stop_0_frame_reg;
assign send_term_lane_1 = cycle_cntr & idle_frame_comb & stop_1_frame_reg;
assign send_term_lane_2 = cycle_cntr & idle_frame_comb & stop_2_frame_reg;
assign send_term_lane_3 = cycle_cntr & idle_frame_comb & stop_3_frame_reg;
assign send_term_lane_4 = cycle_cntr & stop_0_frame_comb & data_frame_reg;
assign send_term_lane_5 = cycle_cntr & stop_1_frame_comb & data_frame_reg;
assign send_term_lane_6 = cycle_cntr & stop_2_frame_comb & data_frame_reg;
assign send_term_lane_7 = cycle_cntr & stop_3_frame_comb & data_frame_reg;

// -----------------------------------------------------------------------------
// Along wth recieveing data in 32 bit words, we also output 32 bit words, 
// meaning we need to be able to see the encoded value for 2 clock cycles.
// Therefore, we latch the data from above, this allows us to know whether
// we are sending the first word in the output (combinational signal is high)
// or we are sending the second word in the output (latched signal is high).
// -----------------------------------------------------------------------------
always_ff@(posedge i_clk) begin
    encoded_data_valid_reg <= encoded_data_valid;
    send_idle_frame_reg <= send_idle_frame;
    send_start_lane_0_reg <= send_start_lane_0;
    send_start_lane_4_reg <= send_start_lane_4;
    send_term_lane_0_reg <= send_term_lane_0;
    send_term_lane_1_reg <= send_term_lane_1;
    send_term_lane_2_reg <= send_term_lane_2;
    send_term_lane_3_reg <= send_term_lane_3;
    send_term_lane_4_reg <= send_term_lane_4;
    send_term_lane_5_reg <= send_term_lane_5;
    send_term_lane_6_reg <= send_term_lane_6;
    send_term_lane_7_reg <= send_term_lane_7;
end

/******************* Output Logic *******************/

always_ff@(posedge i_clk) begin

    data_valid <= encoded_data_valid_reg | encoded_data_valid;

    // Break the encoded word into 2 separate block to avoid a very high fan-in                     
    encoded_word[0] <=  (send_start_lane_0) ? {xgmii_txd_payload[0][31:8], BLOCK_START_0} :
                        (send_start_lane_0_reg) ? xgmii_txd_payload[0] :                      
                        (send_start_lane_4) ? {24'h0, BLOCK_START_4} :
                        (send_start_lane_4_reg) ? {xgmii_txd_payload[0][31:8], 8'h0} :
                        (send_term_lane_0) ? {24'h0, BLOCK_TERM_0} :
                        (send_term_lane_1) ? {16'h0, xgmii_txd_payload[0][7:0], BLOCK_TERM_1} :
                        (send_term_lane_2) ? {8'h0, xgmii_txd_payload[0][15:0], BLOCK_TERM_2} :
                        (send_term_lane_3) ? {xgmii_txd_payload[0][23:0], BLOCK_TERM_3} :
                        (data_frame_reg) ? xgmii_txd_payload[0] :                                       
                        32'h0;

    encoded_word[1] <=  (send_term_lane_4) ? {xgmii_txd_payload[0][23:0], BLOCK_TERM_4} :
                        (send_term_lane_4_reg) ? {24'h0, xgmii_txd_payload[1][31:24]} :
                        (send_term_lane_5) ? {xgmii_txd_payload[0][23:0], BLOCK_TERM_5} :
                        (send_term_lane_5_reg) ? {16'h0, xgmii_txd_payload[0][7:0], xgmii_txd_payload[1][31:24]} :
                        (send_term_lane_6) ? {xgmii_txd_payload[0][23:0], BLOCK_TERM_6} :
                        (send_term_lane_6_reg) ? {8'h0, xgmii_txd_payload[0][15:0], xgmii_txd_payload[1][31:24]} :
                        (send_term_lane_7) ? {xgmii_txd_payload[0][23:0], BLOCK_TERM_7} :
                        (send_term_lane_7_reg) ? {xgmii_txd_payload[0][23:0], xgmii_txd_payload[1][31:24]}:
                        (send_idle_frame) ? {24'h0, BLOCK_CTRL} :
                        32'h0;


    // Select signals for which register value to output
    encoded_word_select[0] <= send_start_lane_0 | send_start_lane_0_reg | send_start_lane_4 | send_start_lane_4_reg |
                            send_term_lane_0 | send_term_lane_1 | send_term_lane_2 | send_term_lane_3 | data_frame_reg;

    encoded_word_select[1] <= send_term_lane_4 | send_term_lane_4_reg | send_term_lane_5 | send_term_lane_5_reg | 
                                send_term_lane_6 | send_term_lane_6_reg | send_term_lane_7 | send_term_lane_7_reg | send_idle_frame;                             


end

assign o_encoded_data = encoded_word_select[1] ? encoded_word[1] : encoded_word[0];
assign o_sync_hdr = sync_hdr_reg;
assign o_encoded_data_valid = data_valid;
assign o_xgmii_pause = gearbox_pause;

endmodule