
// --------------------------------------------------------------------------------------------
// OVERVIEW:
// This module receives serial data from the transceiver in 32-bit parallel chunks (`i_rx_data`).
// Our goal is to reassemble these into complete 66-bit blocks for further processing, while 
// ensuring we are outputting the data chunks in 32-bit words. The problem is that 
// 66 is not divisible by 32, so consecutive 32-bit words will not align perfectly
// with 66-bit block boundaries. This means we can't just shift data in and output every
// 32 bit word. Instead, we must intentionally position bits in a circular buffer so that every block
// is correctly aligned. The reason it must be circular, is because we need to wrap
// some of the data around as explained below.
//
// --------------------------------------------------------------------------------------------
// 66B BLOCK FORMAT:
// Each 66-bit block is made up of:
//   [ 64 bits of payload data | 2-bit sync header ]
//
// If we label the 2-bit header as `Hdr` and the 64 bits as `Data[63:0]`, the block looks like:
//
//   | Data[63:34] ... Data[1:0] | Hdr |
//   |___________________________|____|
//              64 bits            2 bits
//
// Because the transceiver delivers 32 bits at a time, blocks will span across multiple
// 32-bit words in a repeating misalignment pattern.
//
// EXAMPLE OF MISALIGNMENT:
//
// Step 1: Receive first 32-bit word (i_data_0):
//   This block will contain {Data[29:0], Hdr}.
//
// Step 2: Receive second 32-bit word (i_data_1):
//   This block will contain {Data[61:30]}, but we are still missing the last 2 bits for a complete block.
//
// Step 3: Receive third 32-bit word (i_data_2):
//   The first 2 bits of i_data_2 contain Data[63:62] from the first 66-bit block.
//   The remaining 30 bits of i_data_2 will contain {Data[27:0], Hdr} of the NEXT 66-bit block.
//
// So the first complete block is assembled as:
//   { i_data_2[1:0], i_data_1, i_data_0 }
//
// The next complete block will be made from:
//   { i_data_4[3:0], i_data_3, i_data_2[31:2] }
//
// Next block after that:
//   { i_data_6[5:0], i_data_5, i_data_4[31:4] }
//
// Each time we process a block, the first word we use loses 2 bits of its width,
// because those bits belong to the previous block. After 31 such steps, the offset
// cycles back to zero alignment.
//
// PATTERN REPEATS EVERY 33 CYCLES:
//
// Example at step 31:
//   { i_data_33, i_data_32, i_data_31[31:30] }
//
// At this point, we have consumed all bits of i_data_33 in one block,
// so the next block starts with a clean word alignment again:
//
//   { i_data_36[1:0], i_data_35, i_data_34 }
//
// This is identical to the very first pattern, so we know the sequence repeats every 32 steps.
// This also makes sense based on the gearbox calculation that shows every 33 cycles we will have
// 1 idle cycle (see README).
//
// INDEX CALCULATION:
//
// If we treat our sliding buffer as a fixed array where index 0 is the first word
// of each block, we can calculate where the second and third words go.
//
// Let:
//   cycle = number of 32-bit blocks received 
//
// Then:
//   - Second word index = (32 - cycle) + 1
//   - Third word index  = (second word index) + 32
//
// These indices ensure that:
//   - The bits are always placed in the right position in the buffer
//   - The sync header lands in the correct place for every block
//
// --------------------------------------------------------------------------------------------

module block_sync
#(
    parameter DATA_WIDTH = 32,
    parameter HDR_WIDTH = 2
)
(
    input logic i_clk,
    input logic i_reset_n,

    // Gearbox-to-Scrambler Interface
    output logic [DATA_WIDTH-1:0]   o_tx_data,
    output logic [HDR_WIDTH-1:0]    o_tx_sync_hdr,
    output logic                    o_tx_sync_hdr_valid,
    output logic                    o_tx_data_valid,
    input logic                     i_slip,

    // Gearbox Data Input
    input logic [DATA_WIDTH-1:0]    i_rx_data
);

localparam BUF_SIZE = (DATA_WIDTH*2) + HDR_WIDTH;
localparam CNTR_WIDTH = $clog2(32) + 1;

// --------------------- Index LUT Logic --------------------- // 

logic [6:0]             index_lut[DATA_WIDTH:0];

initial begin
    index_lut[0] = 7'd0;
    index_lut[1] = 7'd32;
    index_lut[2] = 7'd64;
    index_lut[3] = 7'd30;
    index_lut[4] = 7'd62;
    index_lut[5] = 7'd28;
    index_lut[6] = 7'd60;
    index_lut[7] = 7'd26;
    index_lut[8] = 7'd58;
    index_lut[9] = 7'd24;
    index_lut[10] = 7'd56;
    index_lut[11] = 7'd22;
    index_lut[12] = 7'd54;
    index_lut[13] = 7'd20;
    index_lut[14] = 7'd52;
    index_lut[15] = 7'd18;
    index_lut[16] = 7'd50;
    index_lut[17] = 7'd16;
    index_lut[18] = 7'd48;
    index_lut[19] = 7'd14;
    index_lut[20] = 7'd46;
    index_lut[21] = 7'd12;
    index_lut[22] = 7'd44;
    index_lut[23] = 7'd10;
    index_lut[24] = 7'd42;
    index_lut[25] = 7'd8;
    index_lut[26] = 7'd40;
    index_lut[27] = 7'd6;
    index_lut[28] = 7'd38;
    index_lut[29] = 7'd4;
    index_lut[30] = 7'd36;
    index_lut[31] = 7'd2;
    index_lut[32] = 7'd34; 
end


// --------------------- Cycle/Slip Counter Logic --------------------- // 

logic [CNTR_WIDTH-1:0]  seq_cntr = '0;
logic                   slip_reg = 1'b0;
logic [6:0]             ptr = 7'b0;

always_ff @(posedge i_clk) begin
    if(!i_reset_n) begin 
        seq_cntr <= '0;
        slip_reg <= 1'b0;
        ptr <= 7'b0;
    end else begin

        // Keep track of whether we have an odd/even number of slips
        if (i_slip)
            slip_reg <= ~slip_reg;
        else begin
            seq_cntr <= (seq_cntr == 6'd32) ? '0 : seq_cntr + 1;
        end
    end
end

// --------------------- Circular Buffer Logic --------------------- // 

logic                   even; 
logic [BUF_SIZE-1:0]    rx_data_buff = '0;
logic [BUF_SIZE-1:0]    rx_comb_buff;
logic [6:0]             buffer_ptr;

assign even = (slip_reg) ? (!seq_cntr[0] & (seq_cntr != 6'd32)) : (!seq_cntr[0]);
assign buffer_ptr = index_lut[seq_cntr];

generate
    always_comb begin

        rx_comb_buff= rx_data_buff;

        for(int i = 0; i < DATA_WIDTH; i++) begin
                // Wrap around logic
                if((i + buffer_ptr >= BUF_SIZE))
                    rx_comb_buff[(buffer_ptr + i) - BUF_SIZE] = i_rx_data[i];
                // Non-wrap around logic 
                else
                    rx_comb_buff[buffer_ptr + i] = i_rx_data[i];
        end
    end
endgenerate

// Latch the buffer data //
always_ff @(posedge i_clk) begin
    if (!i_reset_n)
        rx_data_buff <= '0;
    else
        rx_data_buff <= rx_comb_buff[BUF_SIZE-1:0];
end

// --------------------- Output Logic --------------------- //

assign o_tx_data = (slip_reg) ? ((even) ? {rx_comb_buff[0], rx_comb_buff[65:35]} : rx_comb_buff[34:3]) :
                                    ((even) ? rx_comb_buff[65:34] : rx_comb_buff[33:2]);
assign o_tx_sync_hdr = (slip_reg) ? rx_comb_buff[2:1] : rx_comb_buff[1:0];
assign o_tx_sync_hdr_valid = !even & o_tx_data_valid;
assign o_tx_data_valid = (slip_reg) ? (seq_cntr != 6'd32) : (seq_cntr != '0);

endmodule