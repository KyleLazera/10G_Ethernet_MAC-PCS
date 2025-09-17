
module crc32#(
    parameter DATA_WIDTH = 32,
    parameter CRC_WIDTH = 32,

    parameter DATA_BYTES = DATA_WIDTH/8
)(
    input logic i_clk,
    input logic i_reset_n,

    input logic [DATA_WIDTH-1:0]    i_data,
    input logic [CRC_WIDTH-1:0]     i_crc_state,
    input logic [DATA_BYTES-1:0]    i_data_valid,

    output logic [DATA_WIDTH-1:0]   o_crc
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

/* -------------- LUT Indexing Logic -------------- */

logic [7:0]             table_index[3:0];

always_comb begin
    table_index[0] = (i_crc_state[31:24] ^ i_data[31:24]);
    table_index[1] = (i_crc_state[23:16]  ^ i_data[23:16]);
    table_index[2] = (i_crc_state[15:8] ^ i_data[15:8]);
    table_index[3] = (i_crc_state[7:0] ^ i_data[7:0]);
end

/* -------------- Output Logic -------------- */

always_comb begin
    case (i_data_valid)
        4'b1111: o_crc =  lut_3[table_index[3]] ^
                          lut_2[table_index[2]] ^
                          lut_1[table_index[1]] ^
                          lut_0[table_index[0]];

        4'b0111: o_crc = lut_2[table_index[2]] ^
                          lut_1[table_index[1]] ^
                          lut_0[table_index[0]];

        4'b0011: o_crc = lut_1[table_index[1]] ^
                          lut_0[table_index[0]];

        4'b0001: o_crc = lut_0[table_index[0]];

        default: o_crc = i_crc_state; 
    endcase
end

endmodule