
module lock_state #(
    parameter HDR_WIDTH
) (
    input logic                 i_clk,
    input logic                 i_reset_n,

    // Interface with rx block sync
    input logic [HDR_WIDTH-1:0] i_hdr,
    input logic                 i_hdr_valid,
    output logic                o_slip,

    // Interface with decoder
    output logic                o_block_lock
);

localparam MAX_SH_CNTR = 64;
localparam MAX_SH_INVALID = 16;

localparam SH_CNTR_WIDTH = $clog2(64) + 1;
localparam SH_INVALID_WIDTH = $clog2(16) + 1;

logic [SH_CNTR_WIDTH-1:0]       sh_counter = '0;
logic [SH_INVALID_WIDTH-1:0]    sh_invalid_cntr = '0;
logic                           block_lock = 1'b0;
logic                           slip = 1'b0;
logic                           sh_valid;

// Synchronous header is valid only if it is on of the following values:
//  - 2'b01
//  - 2'b10
assign sh_valid = ^i_hdr;

always_ff @(posedge i_clk) begin
    if (!i_reset_n) begin
        sh_counter <= '0;
        sh_invalid_cntr <= '0;
        block_lock <= 1'b0;
        slip <= 1'b0;
    end else begin

        slip <= 1'b0;

        if (i_hdr_valid) begin
            sh_counter <= sh_counter + 1;
            
            if(!sh_valid) begin
                sh_invalid_cntr <= sh_invalid_cntr + 1;
                
                if (sh_invalid_cntr == MAX_SH_INVALID | (!block_lock)) begin
                    sh_counter <= '0;
                    sh_invalid_cntr <= '0;
                    slip <= 1'b1;
                    block_lock <= 1'b0;
                end
            end
        end

        if (sh_counter == MAX_SH_CNTR) begin

            sh_counter <= '0;
            sh_invalid_cntr <= '0;

            if (sh_invalid_cntr == 0) begin
                block_lock <= 1'b1;
            end
        end

    end
end

assign o_slip = slip;
assign o_block_lock = block_lock;

endmodule : lock_state