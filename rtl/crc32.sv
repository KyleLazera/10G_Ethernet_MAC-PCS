`timescale 1ns / 1ps

module crc32#(
    parameter DATA_WIDTH = 32,
    parameter CRC_WIDTH = 32,

    parameter DATA_BYTES = DATA_WIDTH/8
)(
    input logic i_clk,

    input logic [DATA_WIDTH-1:0]    i_data,
    input logic [CRC_WIDTH-1:0]     i_crc_state,
    input logic [DATA_BYTES-1:0]    i_data_valid,

    output logic [DATA_WIDTH-1:0]   o_crc,
    output logic [CRC_WIDTH-1:0]    o_crc_state
);

/* -------------- Local Parameters -------------- */

localparam logic [DATA_WIDTH-1:0]   CRC_POLY = 32'h04C11DB7;
localparam int                      LUT_WIDTH = CRC_WIDTH;
localparam int                      LUT_DEPTH = 256;

/* -------------- Look Up Tables -------------- */

logic [LUT_WIDTH-1:0] lut_0 [LUT_DEPTH-1:0]; 
logic [LUT_WIDTH-1:0] lut_1 [LUT_DEPTH-1:0]; 
logic [LUT_WIDTH-1:0] lut_2 [LUT_DEPTH-1:0]; 
logic [LUT_WIDTH-1:0] lut_3 [LUT_DEPTH-1:0]; 


initial begin
    $readmemh("table0.txt", lut_0);
    $readmemh("table1.txt", lut_1);
    $readmemh("table2.txt", lut_2);
    $readmemh("table3.txt", lut_3);            
end

/* -------------- Isolate Input Bytes -------------- */

logic [7:0]     data_byte [3:0];

always_comb begin
    data_byte[0] = i_data[7:0];
    data_byte[1] = i_data[15:8];
    data_byte[2] = i_data[23:16];
    data_byte[3] = i_data[31:24]; 
end


/* -------------- LUT Indexing Logic -------------- */

logic [7:0]             table_index[3:0];

always_comb begin
    table_index[0] = (i_crc_state[7:0] ^ data_byte[0]);
    table_index[1] = (i_crc_state[15:8]  ^ data_byte[1]);
    table_index[2] = (i_crc_state[23:16] ^ data_byte[2]);
    table_index[3] = (i_crc_state[31:24] ^ data_byte[3]);
end

/* -------------- Parallelized CRC Calculation -------------- */

logic [CRC_WIDTH-1:0]       crc_calc [3:0];

always_comb begin
    // 1 Valid Byte in word
    crc_calc[0] = lut_0[table_index[0]];

    // 2 Valid Bytes (Slicing-by-2)
    crc_calc[1] = lut_0[table_index[1]] ^ lut_1[table_index[0]];

    // 3 Valid Bytes 
    crc_calc[2] = lut_0[table_index[2]] ^ lut_1[table_index[1]] ^ lut_2[table_index[0]];

    // 4 Valid Bytes
    crc_calc[3] = lut_0[table_index[3]] ^ lut_1[table_index[2]] ^ lut_2[table_index[1]] ^ lut_3[table_index[0]];
end

/* -------------- Selection CRC Logic -------------- */

logic [CRC_WIDTH-1:0]       crc_next;

always_comb begin
    case(i_data_valid)
        4'b1111: crc_next = crc_calc[3];
        4'b0111: crc_next = crc_calc[2] ^ (i_crc_state >> 24);
        4'b0011: crc_next = crc_calc[1] ^ (i_crc_state >> 16);
        4'b0001: crc_next = crc_calc[0] ^ (i_crc_state >> 8);
    endcase
end

/* -------------- Output Logic -------------- */

assign o_crc = ~crc_next;
assign o_crc_state = crc_next;

endmodule