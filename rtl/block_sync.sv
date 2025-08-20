
// --------------------------------------------------------------------------------------------
// OVERVIEW:
// This module receives serial data from the transceiver in 32-bit parallel chunks (`i_rx_data`).
// Our goal is to reassemble these into complete 66-bit blocks for further processing, while 
// ensuring we are outputting the data chunks in 32-bit words. The problem is that 
// 66 is not divisible by 32, so consecutive 32-bit words will not align perfectly
// with 66-bit block boundaries. This means we can't just shift data in and output every
// 32 bit word. Instead, we must intentionally position bits in a circular buffer so that every block
// is correctly aligned. The reason it must be circular, is because we need to be able to
// wrap some of the data around as explained below.
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
//   This is NOT a full 66-bit block — it's just the first part.
//
// Step 2: Receive second 32-bit word (i_data_1):
//   Now we have 64 bits in total, but still missing the last 2 bits for a complete block.
//
// Step 3: Receive third 32-bit word (i_data_2):
//   The first 2 bits of i_data_2 belong to the END of the first 66-bit block.
//   The remaining 30 bits of i_data_2 will be the start of the NEXT 66-bit block.
//
// So the first complete block is assembled as:
//   { i_data_2[1:0], i_data_1, i_data_0 }
//
// The next complete block will be made from:
//   { i_data_4[3:0], i_data_3, i_data_2[31:2] }
//
// Why?
// - First 2 bits of i_data_2 already went to the previous block
// - The remaining bits of i_data_2 and the next words get shifted accordingly
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
    output logic                    o_tx_data_valid,
    input logic                     i_slip,

    // Gearbox Data Input
    input logic [DATA_WIDTH-1:0]    i_rx_data
);

localparam BUF_SIZE = (DATA_WIDTH*2) + HDR_WIDTH;
localparam CNTR_WIDTH = $clog2(32) + 1;

/* --------------------- Index LUT Logic --------------------- */ 

logic [6:0]             index_lut[32:0];

initial begin
    // Initialize first 3 index positions
    index_lut[0] = 7'd0;
    index_lut[1] = 7'd32;
    index_lut[2] = 7'd64;

    // Use equation derived to compute the remaining values
    for(int i = 3; i < 33; i++)
        index_lut[i] = index_lut[i-2] - 2;

end

/* --------------------- Cycle Counter Logic --------------------- */ 

logic [CNTR_WIDTH-1:0]  seq_cntr = '0;

always_ff @(posedge i_clk) begin
    if(!i_reset_n) 
        seq_cntr <= '0;
    else begin
        //TODO: We do not want to shift the seq counter if i_slip is high
        seq_cntr <= (seq_cntr == 6'd32) ? '0 : seq_cntr + 1;
    end
end

/* --------------------- Circular Buffer Logic --------------------- */ 

logic                   even; 
logic [BUF_SIZE-1:0]    rx_data_buff = '0;
logic [BUF_SIZE-1:0]    rx_comb_buff;
logic [6:0]             buffer_ptr;

genvar i;

assign even = !seq_cntr[0];
assign buffer_ptr = index_lut[seq_cntr];

generate
    for(i = 0; i < DATA_WIDTH; i++) begin
        always_comb begin

            // Even seq counter indicates we are either adding the first or third word
            // to the buffer, so we need to be able to handle overflow
            if (even) begin
                // Overflow Condition 
                if ((i+buffer_ptr >= BUF_SIZE) & (seq_cntr != '0))
                    rx_comb_buff[buffer_ptr-BUF_SIZE+i] = i_rx_data[i];
                // No overflow Condition
                else
                    rx_comb_buff[buffer_ptr + i] = i_rx_data[i];
            // On odd seq counter values, we are always adding the second word, so we do not
            // run the risk of overflow
            end else begin
                rx_comb_buff[buffer_ptr + i] = i_rx_data[i];
            end
        end
    end

endgenerate

/* Latch the buffer data */
always_ff @(posedge i_clk) begin
    rx_data_buff <= rx_comb_buff;
end

/* --------------------- Output Logic --------------------- */

assign o_tx_data = (even) ? rx_comb_buff[65:34] : rx_comb_buff[33:2];
assign o_tx_sync_hdr = rx_comb_buff[1:0];
assign o_tx_data_valid = (seq_cntr != '0);

endmodule