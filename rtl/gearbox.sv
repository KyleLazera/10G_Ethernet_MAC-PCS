module gearbox
#(
    parameter DATA_WIDTH = 32
)
(
    input logic i_clk,
    input logic i_reset_n,

    // Encoded Data & Header input
    input logic [DATA_WIDTH-1:0] i_data,
    input logic i_data_valid,
    input logic [1:0] i_hdr,

    // Gearbox Data Output
    output logic [DATA_WIDTH-1:0] o_data,

    // Control signal bback to encoder
    output logic o_gearbox_pause
);

logic [DATA_WIDTH-1:0] data_latch = '0;
logic [5:0] cntr = 6'b0;

// --------------------------------------------------------------------
// To ensure we do not overrun the gearbox, we need to keep track 
// of how many 32-bit words of data have been receieved. Every 31 
// words, we want to assert back-pressure to pause the down-stream
// modules (Decoder & MAC). To see the math behind why 31 transmissions
// are needed, see teh README.
// --------------------------------------------------------------------

always_ff @(posedge i_clk) begin
    if(~i_reset_n | ~i_data_valid)
        cntr <= 6'b0;
    else
        cntr <= cntr + 1;
end

always_ff @(posedge i_clk) begin
    data_latch <= i_data;
    o_gearbox_pause <= (cntr == 6'd30);
end

// ----------------------------------------------------------------------------
// Synchronous Gearbox Output Alignment Logic
//
// This gearbox converts 66-bit encoded Ethernet blocks (64 data + 2 header bits)
// into a continuous stream of 32-bit words without crossing clock domains. The
// case statement uses the cycle counter (`cntr`) to align and merge incoming
// 32-bit chunks (`i_data`) and the 2-bit sync header (`i_hdr`) with previously
// latched data (`data_latch`), ensuring correct word boundaries on the output.
//
// Because input throughput is slightly higher than output throughput
// (33 bits/cycle in vs. 32 bits/cycle out), the counter advances through 32
// alignment states. Each state shifts the output boundary by 2 bits, inserting
// the header at the correct location. After 32 cycles, the accumulated extra
// 32 bits are output in full, and backpressure is applied to prevent overrun.
//
// This logic ensures bit-accurate ordering of all incoming data and avoids
// drift between input and output streams.
// ----------------------------------------------------------------------------

always_comb begin
    case(cntr) 
        6'd0: o_data = {i_data[29:0], i_hdr};
        6'd1: o_data = {i_data[29:0], data_latch[31:30]};
        6'd2: o_data = {i_data[27:0], i_hdr, data_latch[31:30]};
        6'd3: o_data = {i_data[27:0], data_latch[31:28]};
        6'd4: o_data = {i_data[25:0], i_hdr, data_latch[31:28]};
        6'd5: o_data = {i_data[25:0], data_latch[31:26]};
        6'd6: o_data = {i_data[23:0], i_hdr, data_latch[31:26]};
        6'd7: o_data = {i_data[23:0], data_latch[31:24]};
        6'd8: o_data = {i_data[21:0], i_hdr, data_latch[31:24]};
        6'd9:  o_data = {i_data[21:0], data_latch[31:22]};
        6'd10: o_data = {i_data[19:0], i_hdr, data_latch[31:22]};
        6'd11: o_data = {i_data[19:0], data_latch[31:20]};
        6'd12: o_data = {i_data[17:0], i_hdr, data_latch[31:20]};
        6'd13: o_data = {i_data[17:0], data_latch[31:18]};
        6'd14: o_data = {i_data[15:0], i_hdr, data_latch[31:18]};
        6'd15: o_data = {i_data[15:0], data_latch[31:16]};
        6'd16: o_data = {i_data[13:0], i_hdr, data_latch[31:16]};
        6'd17: o_data = {i_data[13:0], data_latch[31:14]};
        6'd18: o_data = {i_data[11:0], i_hdr, data_latch[31:14]};
        6'd19: o_data = {i_data[11:0], data_latch[31:12]};
        6'd20: o_data = {i_data[9:0], i_hdr, data_latch[31:12]};
        6'd21: o_data = {i_data[9:0], data_latch[31:10]};
        6'd22: o_data = {i_data[7:0], i_hdr, data_latch[31:10]};
        6'd23: o_data = {i_data[7:0], data_latch[31:8]};
        6'd24: o_data = {i_data[5:0], i_hdr, data_latch[31:8]};
        6'd25: o_data = {i_data[5:0], data_latch[31:6]};
        6'd26: o_data = {i_data[3:0], i_hdr, data_latch[31:6]};
        6'd27: o_data = {i_data[3:0], data_latch[31:4]};
        6'd28: o_data = {i_data[1:0], i_hdr, data_latch[31:4]};
        6'd29: o_data = {i_data[1:0], data_latch[31:2]};
        6'd30: o_data = {i_hdr, data_latch[31:2]};
        6'd31: o_data = data_latch;
        default: o_data = data_latch;
    endcase
end

endmodule