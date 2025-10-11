
module rx_mac#(
    parameter XGMII_DATA_WIDTH = 32,
    parameter O_DATA_WIDTH = 32,
    parameter SIMULATION = 0,

    /* DO NOT MODIFY */
    parameter XGMII_CTRL_WIDTH = XGMII_DATA_WIDTH/8,
    parameter O_DATA_KEEP_WIDTH = O_DATA_WIDTH/8
)(
    input logic   i_clk,
    input logic   i_reset_n,

    // XGMII Input Interface
    input logic [XGMII_DATA_WIDTH-1:0]      i_xgmii_data,
    input logic [XGMII_CTRL_WIDTH-1:0]      i_xgmii_ctrl,
    input logic                             i_xgmii_valid,

    // Output Stream Interface - NOT AXI STREAM
    output logic [O_DATA_WIDTH-1:0]         o_data,
    output logic [O_DATA_KEEP_WIDTH-1:0]    o_data_keep,
    output logic                            o_data_last,
    output logic                            o_data_valid,
    output logic                            o_data_err
);

localparam ETH_START = {8'hD5, {6{8'h55}}, 8'hFB};
localparam MIN_NUM_WORDS = 15;          
localparam CNTR_WIDTH = $clog2(MIN_NUM_WORDS);
localparam CRC_WIDTH = 32;

typedef enum logic [1:0] {
    IDLE,
    DATA,
    CRC
} state_t;

/* ---------------- Pipeline Input Data ---------------- */

logic [(3*XGMII_DATA_WIDTH)-1:0]     xgmii_data_pipe = '0;
logic [(3*XGMII_CTRL_WIDTH)-1:0]     xgmii_ctrl_pipe = '0;
logic [2:0]                          xgmii_valid_pipe = '0;

always_ff @(posedge i_clk) begin
    if (i_xgmii_valid) begin
        xgmii_data_pipe <= {i_xgmii_data, xgmii_data_pipe[(3*XGMII_DATA_WIDTH)-1 : XGMII_DATA_WIDTH]};
        xgmii_ctrl_pipe <= {i_xgmii_ctrl, xgmii_ctrl_pipe[(3*XGMII_CTRL_WIDTH)-1 : XGMII_CTRL_WIDTH]};
    end
    xgmii_valid_pipe <= {i_xgmii_valid, xgmii_valid_pipe[2:1]};
end

/* ---------------- Decoding Data Logic ---------------- */

logic                           start_condition;
logic                           stop_condition;
logic [3:0]                     terminate_pos;
logic [3:0]                     terminate_pos_reg;

always_comb begin
    for(int i = 0; i < 4; i++) 
        terminate_pos[i] = (i_xgmii_data[(i*8) +: 8] == 8'hFD) && i_xgmii_ctrl[i] && i_xgmii_valid;
end

// Terminate Flag Pipeline
always_ff @(posedge i_clk)
    for(int i = 0; i < 4; i++)
        terminate_pos_reg[i] <= terminate_pos[i];

// Combintational Decoding Flags
assign start_condition = (xgmii_data_pipe[(2*XGMII_DATA_WIDTH)-1:0] == ETH_START) && (xgmii_ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1:0] == 8'h1);
assign stop_condition = terminate_pos[0] | terminate_pos[1] | terminate_pos[2] | terminate_pos[3];

/* ---------------- State Machine Logic ---------------- */

state_t                         state_reg = IDLE;
logic [O_DATA_WIDTH-1:0]        o_data_reg = {O_DATA_WIDTH{1'b0}};
logic [O_DATA_KEEP_WIDTH-1:0]   o_data_keep_reg = {O_DATA_KEEP_WIDTH{1'b0}};
logic                           o_data_tlast_reg = 1'b0;
logic                           o_data_valid_reg = 1'b0;
logic                           o_data_err_reg = 1'b0;
logic [CNTR_WIDTH-1:0]          data_cntr = '0;


always_ff@(posedge i_clk) begin
    if (!i_reset_n) begin
        state_reg <= IDLE;
        data_cntr <= '0;
        o_data_valid_reg <= 1'b0;
        o_data_err_reg <= 1'b0;
        o_data_tlast_reg <= 1'b0;
        sof <= 1'b0;
    end else begin

        sof <= 1'b0;

        o_data_tlast_reg <= 1'b0;

        o_data_reg <= xgmii_data_pipe[(2*XGMII_DATA_WIDTH)-1 -: O_DATA_WIDTH];
        o_data_keep_reg <= {O_DATA_KEEP_WIDTH{1'b0}};
        o_data_valid_reg <= xgmii_valid_pipe[2];

        crc_data_valid <= '0;

        case(state_reg)
            IDLE: begin

                o_data_err_reg <= 1'b0;
                sof <= 1'b1;
                
                if (start_condition) begin
                    sof <= 1'b0;
                    crc_data_in <= xgmii_data_pipe[(3*XGMII_DATA_WIDTH)-1 -: XGMII_DATA_WIDTH];
                    crc_data_valid <= ~xgmii_ctrl_pipe[(3*XGMII_CTRL_WIDTH)-1 -: O_DATA_KEEP_WIDTH] & {8{i_xgmii_valid}};
                    state_reg <= DATA;
                end
            end
            DATA: begin
                o_data_keep_reg <= ~xgmii_ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1 -: O_DATA_KEEP_WIDTH];

                crc_data_in <= xgmii_data_pipe[(3*XGMII_DATA_WIDTH)-1 -: XGMII_DATA_WIDTH];
                crc_data_valid <= ~xgmii_ctrl_pipe[(3*XGMII_CTRL_WIDTH)-1 -: O_DATA_KEEP_WIDTH] & {8{i_xgmii_valid}};
                
                if (xgmii_valid_pipe[1] && (data_cntr < (MIN_NUM_WORDS - 1)))
                    data_cntr <= data_cntr + 1;
            
                if (terminate_pos[0]) begin
                    crc_data_valid <= {{(O_DATA_KEEP_WIDTH){1'b0}}};
                end

                if (terminate_pos[1]) begin
                    crc_data_valid <= {{(O_DATA_KEEP_WIDTH-1){1'b0}}, 1'b1};
                end

                if (terminate_pos[2]) begin
                    crc_data_valid <= {{(O_DATA_KEEP_WIDTH-2){1'b0}}, 2'b11};
                end

                if (terminate_pos[3]) begin
                    crc_data_valid <= {{(O_DATA_KEEP_WIDTH-3){1'b0}}, 3'b111};
                end

                if (stop_condition) begin
                    if (data_cntr < (MIN_NUM_WORDS - 1)) begin
                        o_data_err_reg <= 1'b1;
                        state_reg <= IDLE;
                    end else begin
                        state_reg <= CRC;
                        o_data_tlast_reg <= terminate_pos[0];
                    end

                end
            end
            CRC: begin
                if (terminate_pos_reg[0]) begin
                    o_data_err_reg <= (xgmii_data_pipe[(2*XGMII_DATA_WIDTH)-1 -: XGMII_DATA_WIDTH] != crc_data_out);
                end
                
                if (terminate_pos_reg[1]) begin
                    o_data_tlast_reg <= 1'b1;
                    o_data_keep_reg <= {{(O_DATA_KEEP_WIDTH-1){1'b0}}, 1'b1};
                    o_data_err_reg <= (xgmii_data_pipe[((2*XGMII_DATA_WIDTH) + 8)-1 -: XGMII_DATA_WIDTH] != crc_data_out);
                end

                if (terminate_pos_reg[2]) begin
                    o_data_tlast_reg <= 1'b1;
                    o_data_keep_reg <= {{(O_DATA_KEEP_WIDTH-2){1'b0}}, 2'b11};
                    o_data_err_reg <= (xgmii_data_pipe[((2*XGMII_DATA_WIDTH) + 16)-1 -: XGMII_DATA_WIDTH] != crc_data_out);
                end

                if (terminate_pos_reg[3]) begin
                    o_data_tlast_reg <= 1'b1;
                    o_data_keep_reg <= {{(O_DATA_KEEP_WIDTH-3){1'b0}}, 3'b111};
                    o_data_err_reg <= (xgmii_data_pipe[((2*XGMII_DATA_WIDTH) + 24)-1 -: XGMII_DATA_WIDTH] != crc_data_out);
                end

                state_reg <= IDLE;
            end
        endcase
    end
end

/* ---------------- CRC Logic ---------------- */

logic                           sof = 1'b0;
logic [CRC_WIDTH-1:0]           crc_state = 32'hFFFFFFFF;
logic [XGMII_DATA_WIDTH-1:0]    crc_data_out, crc_data_in = '0;
logic [CRC_WIDTH-1:0]           crc_state_next;
logic [O_DATA_KEEP_WIDTH-1:0]   crc_data_valid = '0;

always_ff@(posedge i_clk) begin
    if (!i_reset_n | sof) begin
        crc_state <= 32'hFFFFFFFF;
    end else if (|crc_data_valid) begin
        crc_state <= crc_state_next;
    end
end

crc32#(
    .DATA_WIDTH(XGMII_DATA_WIDTH),
    .CRC_WIDTH(CRC_WIDTH),
    .SIMULATION(SIMULATION)
) CRC_Slicing_by_4 (
    .i_clk(i_clk),
    .i_data(crc_data_in),
    .i_crc_state(crc_state),
    .i_data_valid(crc_data_valid),
    .o_crc(crc_data_out),
    .o_crc_state(crc_state_next)
);

/* ---------------- Output Logic ---------------- */

assign o_data = o_data_reg;
assign o_data_keep = o_data_keep_reg;
assign o_data_valid = o_data_valid_reg;
assign o_data_err = o_data_err_reg;
assign o_data_last = (terminate_pos[0] & !xgmii_valid_pipe[2]) ? 1'b1 : o_data_tlast_reg;

endmodule