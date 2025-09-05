
module xgmii_decoder #(
    parameter DATA_WIDTH = 32,
    parameter HDR_WIDTH = 2,
    parameter CTRL_WIDTH = 4
)(
    input logic i_clk,
    input logic i_reset_n,

    // Interface with De-Scrambler
    input logic [DATA_WIDTH-1:0]    i_rx_data,
    input logic                     i_rx_data_valid,
    input logic [HDR_WIDTH-1:0]     i_rx_hdr,
    input logic                     i_rx_hdr_valid,  
    input logic                     i_block_lock,

    // XGMII Interface with MAC
    output logic [DATA_WIDTH-1:0]   o_xgmii_txd,
    output logic [CTRL_WIDTH-1:0]   o_xgmii_txc,
    output logic                    o_xgmii_valid
);

/* XGMII Coded Signals */
localparam XGMII_START  = 8'hFB,
           XGMII_TERM   = 8'hFD;

/* 64b/66b Block Type Fields */
localparam BLOCK_CTRL = 8'h1E,      // C0 C1 C2 C3 C4 C5 C6 C7
           BLOCK_START_4 = 8'h33,   // C0 C1 C2 C3 S4 D5 D6 D7
           BLOCK_START_0 = 8'h78,   // S0 D1 D2 D3 D4 D5 D6 D7  
           BLOCK_TERM_0 = 8'h87,    // T0 C1 C2 C3 C4 C5 C6 C7
           BLOCK_TERM_1 = 8'h99,    // D0 T1 C2 C3 C4 C5 C6 C7
           BLOCK_TERM_2 = 8'hAA,    // D0 D1 T2 C3 C4 C5 C6 C7
           BLOCK_TERM_3 = 8'hB4,    // D0 D1 D2 T3 C4 C5 C6 C7
           BLOCK_TERM_4 = 8'hCC,    // D0 D1 D2 D3 T4 C5 C6 C7
           BLOCK_TERM_5 = 8'hD2,    // D0 D1 D2 D3 D4 T5 C6 C7
           BLOCK_TERM_6 = 8'hE1,    // D0 D1 D2 D3 D4 D5 T6 C7
           BLOCK_TERM_7 = 8'hFF;    // D0 D1 D2 D3 D4 D5 D6 77   

logic                       even = '0;
logic                       rx_data_valid_reg = 1'b0;
logic [DATA_WIDTH-1:0]      rx_data_reg = '0;

// Pipeline for data
always_ff @(posedge i_clk) begin

    if (!i_reset_n) begin
        even <= 1'b0;
    end else begin
    
        if(i_rx_data_valid)
            even <= ~even;

        rx_data_reg <= i_rx_data;
        rx_data_valid_reg <= i_rx_data_valid;
    end
end

logic data_frame_comb;
logic idle_frame_comb;
logic start_0_frame_comb;
logic start_4_frame_comb;
logic stop_0_frame_comb;
logic stop_1_frame_comb;
logic stop_2_frame_comb;
logic stop_3_frame_comb;
logic stop_4_frame_comb;
logic stop_5_frame_comb;
logic stop_6_frame_comb;
logic stop_7_frame_comb;

// Comibationally decode the incoming frame type
always_comb begin
    data_frame_comb = (i_rx_hdr == 2'b01);
    idle_frame_comb = (i_rx_hdr == 2'b10) & (i_rx_data[7:0] == BLOCK_CTRL) & i_rx_data_valid;
    start_0_frame_comb = (i_rx_hdr == 2'b10) & (i_rx_data[7:0] == BLOCK_START_0) & i_rx_data_valid;
    start_4_frame_comb = (i_rx_hdr == 2'b10) & (i_rx_data[7:0] == BLOCK_START_4) & i_rx_data_valid;
    stop_0_frame_comb = (i_rx_hdr == 2'b10) & (i_rx_data[7:0] == BLOCK_TERM_0) & i_rx_data_valid;
    stop_1_frame_comb = (i_rx_hdr == 2'b10) & (i_rx_data[7:0] == BLOCK_TERM_1) & i_rx_data_valid;
    stop_2_frame_comb = (i_rx_hdr == 2'b10) & (i_rx_data[7:0] == BLOCK_TERM_2) & i_rx_data_valid;
    stop_3_frame_comb = (i_rx_hdr == 2'b10) & (i_rx_data[7:0] == BLOCK_TERM_3) & i_rx_data_valid;
    stop_4_frame_comb = (i_rx_hdr == 2'b10) & (i_rx_data[7:0] == BLOCK_TERM_4) & i_rx_data_valid;
    stop_5_frame_comb = (i_rx_hdr == 2'b10) & (i_rx_data[7:0] == BLOCK_TERM_5) & i_rx_data_valid;
    stop_6_frame_comb = (i_rx_hdr == 2'b10) & (i_rx_data[7:0] == BLOCK_TERM_6) & i_rx_data_valid;
    stop_7_frame_comb = (i_rx_hdr == 2'b10) & (i_rx_data[7:0] == BLOCK_TERM_7) & i_rx_data_valid;
end

logic data_frame_reg = '0;
logic idle_frame_reg = '0;
logic start_0_frame_reg = '0;
logic start_4_frame_reg = '0;
logic stop_0_frame_reg = '0;
logic stop_1_frame_reg = '0;
logic stop_2_frame_reg = '0;
logic stop_3_frame_reg = '0;
logic stop_4_frame_reg = '0;
logic stop_5_frame_reg = '0;
logic stop_6_frame_reg = '0;
logic stop_7_frame_reg = '0;

always_ff @(posedge i_clk) begin
    if (!even) begin
        data_frame_reg <= data_frame_comb;
        idle_frame_reg <= idle_frame_comb;
        start_0_frame_reg <= start_0_frame_comb;
        start_4_frame_reg <= start_4_frame_comb;
        stop_0_frame_reg <= stop_0_frame_comb;      
        stop_1_frame_reg <= stop_1_frame_comb;      
        stop_2_frame_reg <= stop_2_frame_comb;      
        stop_3_frame_reg <= stop_3_frame_comb;      
        stop_4_frame_reg <= stop_4_frame_comb;      
        stop_5_frame_reg <= stop_5_frame_comb;      
        stop_6_frame_reg <= stop_6_frame_comb;      
        stop_7_frame_reg <= stop_7_frame_comb;
    end
end

logic [DATA_WIDTH-1:0]      decoded_word[1:0];
logic [CTRL_WIDTH-1:0]      decoded_ctrl[1:0];

always_comb begin
    
    decoded_word[0] =   (idle_frame_reg) ? 32'h07070707 :
                        (data_frame_reg) ? rx_data_reg :
                        (start_0_frame_reg) ? {rx_data_reg[31:8], XGMII_START} :
                        (start_4_frame_reg) ? 32'h07070707 :
                        (stop_0_frame_reg) ? {24'h070707, XGMII_TERM} :
                        (stop_1_frame_reg) ? {16'h0707, XGMII_TERM, rx_data_reg[15:8]} :
                        (stop_2_frame_reg) ? {8'h07, XGMII_TERM, rx_data_reg[23:8]} :
                        (stop_3_frame_reg) ? {XGMII_TERM, rx_data_reg[31:8]} :
                        {i_rx_data[7:0], rx_data_reg[31:8]};

    decoded_word[1] =   (start_4_frame_reg) ? {rx_data_reg[31:8], XGMII_START} :
                        (start_0_frame_reg) ? rx_data_reg :
                        (data_frame_reg) ? rx_data_reg :
                        (stop_4_frame_reg) ? {24'h070707, XGMII_TERM} :
                        (stop_5_frame_reg) ? {16'h0707, XGMII_TERM, rx_data_reg[15:8]} :
                        (stop_6_frame_reg) ? {8'h07, XGMII_TERM, rx_data_reg[23:8]} :
                        (stop_7_frame_reg) ? {XGMII_TERM, rx_data_reg[31:8]} :
                        32'h07070707;

    decoded_ctrl[0] =   (idle_frame_reg) ? 4'b1111 :
                        (start_4_frame_reg) ? 4'b1111 :
                        (start_0_frame_reg) ? 4'b0001 :
                        (stop_0_frame_reg) ? 4'b1111 :
                        (stop_1_frame_reg) ? 4'b1110 :
                        (stop_2_frame_reg) ? 4'b1100 :
                        (stop_3_frame_reg) ? 4'b1000 :
                        4'b0000;

    decoded_ctrl[1] =   (data_frame_reg) ? 4'b0000 :
                        (start_0_frame_reg) ? 4'b0000 :
                        (start_4_frame_reg) ? 4'b0001 :
                        (stop_5_frame_reg) ? 4'b1110 :
                        (stop_6_frame_reg) ? 4'b1100 :
                        (stop_7_frame_reg) ? 4'b1000 :
                        4'b1111;                     
end

assign o_xgmii_txd = decoded_word[!even];
assign o_xgmii_txc = decoded_ctrl[!even];
assign o_xgmii_valid = rx_data_valid_reg & i_block_lock;


endmodule