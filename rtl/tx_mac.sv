`timescale 1ns / 1ps

/*
 * The TX MAC is responsible for receving data via AXI-stream, packaging the data
 * into an ethernet packet (preamble, SFD, Data, IFG), and outputting the ethernet
 * packet via XGMII to the PCS.
 */

module tx_mac #(
    parameter XGMII_DATA_WIDTH = 32,
    parameter XGMII_CTRL_WIDTH = 4,
    parameter SIMULATION = 0,
    
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
localparam [7:0] XGMII_IDLE = 8'h07;

// The min number of bytes an ethernet packet is required to have is 60
// data bytes. Each input word contains 4 bytes. Therefore, we need
// 60/4 = 15 words.
localparam MIN_NUM_WORDS = 15;          
localparam CNTR_WIDTH = $clog2(MIN_NUM_WORDS);

localparam CRC_WIDTH = 32;

typedef enum logic[2:0] {
    IDLE,
    DATA,
    PADDING,
    CRC,
    IFG
}state_t;

/* ---------------- Decoding Input Logic ---------------- */ 

logic [XGMII_DATA_WIDTH-1:0]        decoded_xgmii_data;
logic [XGMII_CTRL_WIDTH-1:0]        decoded_xgmii_ctrl;
logic [AXIS_KEEP_WIDTH-1:0]         decoded_axi_tkeep;
logic [CNTR_WIDTH-1:0]              data_cntr = '0;

always_comb begin
    // Any data bytes that are not intended to be kept (tkeep != 4'hF)
    // will be replaced with 8'h00 in the decoded words.
    decoded_xgmii_data = {XGMII_DATA_WIDTH{1'b0}};

    // If we have not yet recieved the minimum number of bytes, we have to
    // pad the packet with 8'h00; The tkeep for these packets should be all 
    // 1's. 
    // This is used for the CRC calculation
    if (data_cntr < (MIN_NUM_WORDS))
        decoded_axi_tkeep = 4'hF;
    else
        decoded_axi_tkeep = s_axis_tkeep;

    // XGMII control encodes tdata bytes from the AXI Stream with a 0
    // and idle (8'h07), xgmii start or terminate with a 1. tkeep will 
    // be high for every axi byte we want to transmit, therefore, this
    // should be a 0.
    decoded_xgmii_ctrl = ~decoded_axi_tkeep;        

    // Logic to decode the input word based on s_axis_tkeep
    for(int i = 0; i < AXIS_KEEP_WIDTH; i++) begin
        if (s_axis_tkeep[i]) 
            decoded_xgmii_data[(i*8) +: 8] = s_axis_tdata[(i*8) +: 8];
        
    end
end

/* ---------------- CRC32 Logic ---------------- */ 

logic                       sof = 1'b0;
logic [CRC_WIDTH-1:0]       crc_state = 32'hFFFFFFFF;
logic [XGMII_DATA_WIDTH-1:0]crc_data_out, crc_data_in = '0;
logic [CRC_WIDTH-1:0]       crc_state_next;
logic [AXIS_KEEP_WIDTH-1:0] crc_data_valid = 1'b0;

always_ff@(posedge i_clk) begin
    if (!i_reset_n | sof) begin
        crc_state <= 32'hFFFFFFFF;
    end else if (|decoded_axi_tkeep && xgmii_valid_pipe[1]) begin
        crc_state <= crc_state_next;
    end
end

crc32#(
    .DATA_WIDTH(XGMII_DATA_WIDTH),
    .CRC_WIDTH(32),
    .SIMULATION(SIMULATION)
) CRC_Slicing_by_4 (
    .i_clk(i_clk),
    .i_data(crc_data_in),
    .i_crc_state(crc_state),
    .i_data_valid(crc_data_valid),
    .o_crc(crc_data_out),
    .o_crc_state(crc_state_next)
);

/* ---------------- State Machine Logic ---------------- */ 
state_t                             state_reg = IDLE;
logic [4:0]                         ifg_cntr = '0;
logic [(2*XGMII_DATA_WIDTH)-1:0]    data_pipe = {8{8'h07}};
logic [(2*XGMII_CTRL_WIDTH)-1:0]    ctrl_pipe = 8'hFF;
logic [2:0]                         xgmii_valid_pipe = {3{1'b1}};
logic [3:0]                         valid_bytes = 4'b1111;
logic                               s_axis_trdy_reg = 1'b0;
logic                               term_set = 1'b0;

always_ff @(posedge i_clk) begin
    if (!i_reset_n) begin
        state_reg <= IDLE;

        sof <= 1'b0;
        term_set <= 1'b0;

        valid_bytes <= 3'b1111;

        // Init data to idle frames 
        data_pipe <= {8{8'h07}};
        ctrl_pipe <= 8'hFF;
        xgmii_valid_pipe <= {3{1'b1}};

        ifg_cntr <= '0;
        data_cntr <= '0;

    end else begin

        sof <= 1'b0;

        // CRC Data Input
        crc_data_in <= decoded_xgmii_data;
        crc_data_valid <= decoded_axi_tkeep;
 

        s_axis_trdy_reg <= 1'b0;

        xgmii_valid_pipe <= {!i_xgmii_pause, xgmii_valid_pipe[2:1]};

        
        case(state_reg)
            IDLE: begin  

                term_set <= 1'b0;     
                ifg_cntr <= '0;                 
                sof <= 1'b1;                

                // We can populate the data pipe with the preamble and SFD once the s_tx_valid
                // is high (master has data to send) and xgmii_valid pipe is high (we are
                // not in a paused state)
                if(s_axis_tvalid && xgmii_valid_pipe[2]) begin
                    data_pipe <= {ETH_SFD, {6{ETH_HDR}}, XGMII_START};
                    ctrl_pipe <= 8'h01;

                    s_axis_trdy_reg <= 1'b1;
                    state_reg <= DATA;
                end  
                    
            end
            DATA: begin
                s_axis_trdy_reg <= !i_xgmii_pause;

                if (xgmii_valid_pipe[2]) begin
                    data_pipe <= {decoded_xgmii_data, data_pipe[(2*XGMII_DATA_WIDTH)-1 -: 32]};
                    ctrl_pipe <= {4'h0, ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1 -: 4]};
                end

                if (s_axis_tlast & s_axis_trdy) begin
                    s_axis_trdy_reg <= 1'b0;
                    // Before transitioning to the next state, we want to latch how many bytes
                    // are valid in the last data word. This is used to determine where to insert
                    // the CRC & terminate or padding bytes.
                    valid_bytes <= decoded_axi_tkeep;
                    state_reg <= (data_cntr < (MIN_NUM_WORDS-1)) ? PADDING : CRC;
                end

                if (data_cntr <= (MIN_NUM_WORDS-1) && s_axis_trdy) 
                    data_cntr <= data_cntr + 1;
            end
            PADDING: begin
                data_pipe <= {decoded_xgmii_data, data_pipe[(2*XGMII_DATA_WIDTH)-1 -: 32]};
                ctrl_pipe <= {4'h0, ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1 -: 4]};

                if (data_cntr >= (MIN_NUM_WORDS-1))
                    state_reg <= CRC;
                else if (o_xgmii_valid)
                    data_cntr <= data_cntr + 1;
            end
            CRC: begin
                if (o_xgmii_valid) begin
                    if (valid_bytes == 4'b0001) begin
                        data_pipe <= {{2{XGMII_IDLE}}, XGMII_TERM, crc_data_out, data_pipe[39 -: 8]};
                        ctrl_pipe <= {3'b111, 1'b0, ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1 -: 4]};
                        term_set <= 1'b1;
                    end else if (valid_bytes == 4'b0011) begin
                        data_pipe <= {{1{XGMII_IDLE}}, XGMII_TERM, crc_data_out, data_pipe[47 -: 16]};
                        ctrl_pipe <= {2'b11, 2'b0, ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1 -: 4]};
                        term_set <= 1'b1;
                    end else if (valid_bytes == 4'b0111) begin
                        data_pipe <= {XGMII_TERM, crc_data_out, data_pipe[55 -: 24]};
                        ctrl_pipe <= {1'b1, 3'b0, ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1 -: 4]};
                        term_set <= 1'b1;
                    end else  begin
                        data_pipe <= {crc_data_out, data_pipe[(2*XGMII_DATA_WIDTH)-1 -: 32]};
                        ctrl_pipe <= {4'b0, ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1 -: 4]};
                    end

                    state_reg <= IFG;
                end

            end
            IFG: begin
                if (o_xgmii_valid) begin
                    if (!term_set) begin
                        data_pipe <= {{{3{XGMII_IDLE}}, XGMII_TERM}, data_pipe[(2*XGMII_DATA_WIDTH)-1 -: 32]};
                        ctrl_pipe <= {4'b1111, ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1 -: 4]};
                        term_set <= 1'b1;
                    end else begin
                        if (ifg_cntr < 2) begin
                            data_pipe <= {{4{XGMII_IDLE}}, data_pipe[(2*XGMII_DATA_WIDTH)-1 -: 32]};
                            ctrl_pipe <= {4'b1111, ctrl_pipe[(2*XGMII_CTRL_WIDTH)-1 -: 4]};
                            ifg_cntr <= ifg_cntr + 1;
                        end else
                            state_reg <= IDLE;

                    end
      
                data_cntr <= '0;    
                end     
            end
        endcase
    end
end

/* ---------------- Output Logic ---------------- */ 
assign o_xgmii_txd = data_pipe[31:0];
assign o_xgmii_ctrl = ctrl_pipe[3:0];
assign o_xgmii_valid = xgmii_valid_pipe[2];

assign s_axis_trdy = s_axis_trdy_reg;



endmodule