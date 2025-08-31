
/*
 * This module contains the logic for the scrambler as specified by the IEEE 802.3-2012
 * clause 49.2. It implements the polynomial as specified by the document:
 *  G(x) = 1 + x^39 + x^58
 *
 * Incurred Latency: 1 clock cycle per byte 
 */

module scrambler #(
    parameter DATA_WIDTH = 32,
    parameter DESCRAMBLE = 0  // Set to 1 for descrambling operation (RX data path)
)(
    input logic i_clk,
    input logic i_reset_n,

    // Encoder-to-Scrambler Interface
    input logic [DATA_WIDTH-1:0]    i_rx_data,
    input logic                     i_rx_data_valid,
    output logic                    o_tx_trdy,

    // Scrambler-to-Gearbox Interface
    output logic [DATA_WIDTH-1:0]   o_tx_data,
    output logic                    o_tx_data_valid,
    input logic                     i_rx_trdy
);

/*********** Signal Descriptions ***********/

// Polynomial Signals
logic [57:0] lfsr = 58'b0;
logic [57:0] poly;

// Data Path Signals
logic [DATA_WIDTH-1:0] o_data_comb;
logic [DATA_WIDTH-1:0] o_data_reg = 'h0;
logic data_valid = 1'b0;
logic scrambler_trdy = 1'b1;

/*********** Logic Implementation ***********/

// Init lfsr & latch combinational outputs
always_ff@(posedge i_clk) begin
    if(!i_reset_n)
        lfsr <= {58{1'b1}};
    else begin
        scrambler_trdy <= i_rx_trdy;
        data_valid <= i_rx_data_valid;
        if(i_rx_data_valid) begin          
            lfsr <= poly;
            o_data_reg <= o_data_comb;
        end
    end
end

integer i;

// --------------------------------------------------------------------
// According to IEEE 802.3-2012, Clause 49.2, the scrambler uses
// the polynomial: G(x) = 1 + x^39 + x^58. This corresponds to a 
// 58-bit Linear Feedback Shift Register (LFSR), where the feedback 
// bit is computed by XORing bit 38 and bit 57 of the LFSR.
//
// This feedback bit is:
//   1) Shifted into the LFSR to update its state, and
//   2) Bitwise XORed with each input data bit to produce scrambled output.
// --------------------------------------------------------------------
generate
    if (DESCRAMBLE) begin : desrambler_block 
        always_comb begin

            poly = lfsr;

            for(i = 0; i < DATA_WIDTH; i++) begin
                poly = {poly[56:0], i_rx_data[i]};
                o_data_comb[i] = i_rx_data[i] ^ poly[38] ^ poly[57];
            end

        end    
    end else begin : scrambler_block
        always_comb begin

            poly = lfsr;

            for(i = 0; i < DATA_WIDTH; i++) begin
                o_data_comb[i] = i_rx_data[i] ^ poly[38] ^ poly[57];
                poly = {poly[56:0], o_data_comb[i]};
            end

        end
    end
endgenerate

assign o_tx_data = o_data_reg;
assign o_tx_data_valid = data_valid;
assign o_tx_trdy = scrambler_trdy;

endmodule