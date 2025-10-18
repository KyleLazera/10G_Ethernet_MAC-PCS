
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
    
    xgmii_valid_pipe <= {i_xgmii_valid, xgmii_valid_pipe[2:1]};
    
    if (i_xgmii_valid) begin
        xgmii_data_pipe <= {i_xgmii_data, xgmii_data_pipe[(3*XGMII_DATA_WIDTH)-1 : XGMII_DATA_WIDTH]};
        xgmii_ctrl_pipe <= {i_xgmii_ctrl, xgmii_ctrl_pipe[(3*XGMII_CTRL_WIDTH)-1 : XGMII_CTRL_WIDTH]};
    end
end

/* ---------------- Decoding Data Logic ---------------- */

logic                           start_condition;
logic                           stop_condition;
logic [3:0]                     terminate_pos;
logic [3:0]                     terminate_pos_reg[1:0];

always_comb begin
    for(int i = 0; i < 4; i++) 
        terminate_pos[i] = (i_xgmii_data[(i*8) +: 8] == 8'hFD) && i_xgmii_ctrl[i] && i_xgmii_valid;
end

// Terminate Flag Pipeline
always_ff @(posedge i_clk) begin
    terminate_pos_reg[0] <= terminate_pos;
    terminate_pos_reg[1] <= terminate_pos_reg[0];
end

// Combintational Decoding Flags
assign start_condition = (xgmii_data_pipe[(2*XGMII_DATA_WIDTH)-1:0] == ETH_START) && (xgmii_ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1:0] == 8'h1);
assign stop_condition = terminate_pos[0] | terminate_pos[1] | terminate_pos[2] | terminate_pos[3];

/* ---------------- State Machine Logic ---------------- */

state_t                         state_reg = IDLE;
logic [O_DATA_WIDTH-1:0]        o_data_reg = {O_DATA_WIDTH{1'b0}};
logic [O_DATA_KEEP_WIDTH-1:0]   o_data_keep_reg = {O_DATA_KEEP_WIDTH{1'b0}};
logic [CNTR_WIDTH-1:0]          data_cntr = '0;
logic                           o_data_tlast_reg = 1'b0;
logic                           o_data_valid_reg = 1'b0;
logic                           packet_length_err = 1'b0;
logic                           crc_enable = 1'b0;
logic                           sof = 1'b0;


always_ff@(posedge i_clk) begin
    if (!i_reset_n) begin
        state_reg <= IDLE;
        data_cntr <= '0;
        packet_length_err <= 1'b0;
        o_data_tlast_reg <= 1'b0;
        sof <= 1'b1;
        crc_enable <= 1'b0;
    end else begin

        sof <= 1'b0;

        // Output Data Pipeline
        o_data_reg <= xgmii_data_pipe[(2*XGMII_DATA_WIDTH)-1 -: O_DATA_WIDTH];
        o_data_keep_reg <= {O_DATA_KEEP_WIDTH{1'b0}};

        packet_length_err <= 1'b0;

        case(state_reg)
            IDLE: begin
                sof <= 1'b1;
                o_data_tlast_reg <= 1'b0;
                
                if (start_condition) begin
                    sof <= 1'b0;
                    crc_enable <= 1'b1;
                    state_reg <= DATA;
                end
            end
            DATA: begin
                o_data_keep_reg <= ~xgmii_ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1 -: O_DATA_KEEP_WIDTH];                
                crc_enable <= !(|terminate_pos);

                if (xgmii_valid_pipe[1] && (data_cntr < (MIN_NUM_WORDS - 1)))
                    data_cntr <= data_cntr + 1;

                if (stop_condition) begin
                    if (data_cntr < (MIN_NUM_WORDS - 1)) begin
                        o_data_tlast_reg <= 1'b1;
                        packet_length_err <= 1'b1;
                        state_reg <= IDLE;
                    end else begin
                        o_data_tlast_reg <= terminate_pos[0];
                        state_reg <= CRC;
                    end
                end
            end
            CRC: begin

                case(terminate_pos_reg[0])
                    4'b0001: begin
                        o_data_keep_reg <= {O_DATA_KEEP_WIDTH{1'b0}};
                        o_data_tlast_reg <= 1'b0;                        
                    end
                    4'b0010: begin
                        o_data_keep_reg <= {{(O_DATA_KEEP_WIDTH-1){1'b0}}, 1'b1};
                        o_data_tlast_reg <= 1'b1;
                    end
                    4'b0100: begin
                        o_data_keep_reg <= {{(O_DATA_KEEP_WIDTH-2){1'b0}}, 2'b11};
                        o_data_tlast_reg <= 1'b1;
                    end
                    4'b1000: begin
                        o_data_keep_reg <= {{(O_DATA_KEEP_WIDTH-3){1'b0}}, 3'b111};
                        o_data_tlast_reg <= 1'b1;
                    end
                    default: begin
                        o_data_keep_reg <= {O_DATA_KEEP_WIDTH{1'b0}};
                        o_data_tlast_reg <= 1'b0;
                    end
                endcase

                state_reg <= IDLE;
            end
        endcase
    end
end

/* ---------------- CRC Logic ---------------- */

logic [CRC_WIDTH-1:0]           crc_state = 32'hFFFFFFFF;
logic [XGMII_DATA_WIDTH-1:0]    crc_data_out, crc_data_in = '0;
logic [CRC_WIDTH-1:0]           crc_data_out_reg = {CRC_WIDTH{1'b0}};
logic [CRC_WIDTH-1:0]           crc_state_next;
logic [O_DATA_KEEP_WIDTH-1:0]   crc_data_valid = '0;

// Logic used to update the CRC state 
always_ff@(posedge i_clk) begin
    if (sof) begin
        crc_state <= 32'hFFFFFFFF;
    end else if (|crc_data_valid & crc_enable) begin
        crc_state <= crc_state_next;
    end
end

//-----------------------------------------------------------------
// The final byte recieved by by the rx mac will contain an 8'FB
// at some point within the word and the bit associated with
// that byte should be set to 1'b1 in the xgmii_ctrl signal. This last
// word is teh CRC for the input packet, therefore, we should not be
// passing this to teh CRC module neither should we output it. Instead,
// we want to validate the value of the CRC to ensure no errors are present.
// The trick with this is we need to ensure we only pass the valid final
// bytes which could be a segment of an input word. As an example:
// 
// XGMII Data:              [   B3    ][   B2   ][   B1   ][   B0   ]
// XGMII Control:           [   b3    ][   b2   ][   b1   ][   b0   ]
//
// Assume the terminate character is present on B2 and b2 is set. Therefore,
// B1 and B0 of this word make up the 2 most significant bytes of the CRC and
// the most signifciant 2 bytes of the previous packet make up the lower bytes 
// of the CRC. Therefore, depending on the location of the terminate seuqence,
// we can determine which bytes to pass into the CRC32 module.
//-----------------------------------------------------------------

always_ff@(posedge i_clk) begin
    
    crc_data_in <= xgmii_data_pipe[(3*XGMII_DATA_WIDTH)-1 -: XGMII_DATA_WIDTH];

    crc_data_out_reg <= crc_data_out;

    case(terminate_pos)
        4'b0001: crc_data_valid <= {{(O_DATA_KEEP_WIDTH){1'b0}}};
        4'b0010: crc_data_valid <= {{(O_DATA_KEEP_WIDTH-1){1'b0}}, 1'b1};
        4'b0100: crc_data_valid <= {{(O_DATA_KEEP_WIDTH-2){1'b0}}, 2'b11};
        4'b1000: crc_data_valid <= {{(O_DATA_KEEP_WIDTH-3){1'b0}}, 3'b111};
        default: crc_data_valid <= ~xgmii_ctrl_pipe[(3*XGMII_CTRL_WIDTH)-1 -: O_DATA_KEEP_WIDTH] & {8{i_xgmii_valid}};
    endcase

end

// CRC32 Module Instantiation
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

logic o_data_crc_err[1:0];

// Perform CCRC check in parallel to register the CRC output
assign o_data_crc_err[0] = (terminate_pos_reg[1] == 4'b0001) ? (crc_data_out_reg != 32'hFFFFFFFF) :
                       (terminate_pos_reg[1] == 4'b0010) ? (crc_data_out_reg != xgmii_data_pipe[((XGMII_DATA_WIDTH) + 8)-1 -: XGMII_DATA_WIDTH]) :
                       (terminate_pos_reg[1] == 4'b0100) ? (crc_data_out_reg != xgmii_data_pipe[((XGMII_DATA_WIDTH) + 16)-1 -: XGMII_DATA_WIDTH]) :
                       (terminate_pos_reg[1] == 4'b1000) ? (crc_data_out_reg != xgmii_data_pipe[((XGMII_DATA_WIDTH) + 24)-1 -: XGMII_DATA_WIDTH]) :
                       1'b0;

assign o_data_crc_err[1] = (terminate_pos_reg[1] == 4'b0001) ? (crc_data_out_reg != 32'hFFFFFFFF) :
                       (terminate_pos_reg[1] == 4'b0010) ? (crc_data_out_reg != xgmii_data_pipe[((2*XGMII_DATA_WIDTH) + 8)-1 -: XGMII_DATA_WIDTH]) :
                       (terminate_pos_reg[1] == 4'b0100) ? (crc_data_out_reg != xgmii_data_pipe[((2*XGMII_DATA_WIDTH) + 16)-1 -: XGMII_DATA_WIDTH]) :
                       (terminate_pos_reg[1] == 4'b1000) ? (crc_data_out_reg != xgmii_data_pipe[((2*XGMII_DATA_WIDTH) + 24)-1 -: XGMII_DATA_WIDTH]) :
                       1'b0;

assign o_data = o_data_reg;
assign o_data_keep = o_data_keep_reg;
assign o_data_valid = xgmii_valid_pipe[1];
assign o_data_last = (terminate_pos[0] & !xgmii_valid_pipe[2]) ? 1'b1 : o_data_tlast_reg;
assign o_data_err = o_data_crc_err[!xgmii_valid_pipe[2]] | packet_length_err;

endmodule