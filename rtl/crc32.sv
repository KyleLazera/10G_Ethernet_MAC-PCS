
module crc32#(
    parameter DATA_WIDTH = 32,
    parameter CRC_WIDTH = 32
)(
    input logic i_clk,
    input logic i_reset_n,

    input logic [DATA_WIDTH-1:0]    i_data,
    input logic [CRC_WIDTH-1:0]     i_crc_state,
    input logic                     i_crc_en,

    output logic [DATA_WIDTH-1:0]   o_crc,
    output logic [CRC_WIDTH-1:0]    o_crc_state
);

/* -------------- Local Parameters -------------- */

localparam logic [DATA_WIDTH-1:0]   CRC_POLY = 32'h04C11DB7;
localparam                          LUT_WIDTH = CRC_WIDTH;
localparam                          LUT_DEPTH = (2**DATA_WIDTH);

/* -------------- Look Up Tables -------------- */

logic [LUT_WIDTH-1:0] lut_0 [LUT_DEPTH-1:0]; 
logic [LUT_WIDTH-1:0] lut_1 [LUT_DEPTH-1:0]; 
logic [LUT_WIDTH-1:0] lut_2 [LUT_DEPTH-1:0]; 
logic [LUT_WIDTH-1:0] lut_3 [LUT_DEPTH-1:0]; 


initial begin
    $readmemh("../software/table0.txt", lut_0);
    $readmemh("../software/table1.txt", lut_1);
    $readmemh("../software/table2.txt", lut_2);
    $readmemh("../software/table3.txt", lut_3);            
end

/* -------------- CRC Logic -------------- */

logic [DATA_WIDTH-1:0]  temp_crc;
logic [7:0]             table_index[3:0];

always_comb begin

    if(i_crc_en) begin
        temp_crc = {i_data[7:0], i_data[15:8], i_data[23:16], i_data[31:24]} ^ i_crc_state;

        table_index[0] = temp_crc & 8'hFF;
        table_index[1] = (temp_crc >> 8) & 8'hFF;
        table_index[2] = (temp_crc >> 16) & 8'hFF;
        table_index[3] = (temp_crc >> 24) & 8'hFF;
    end

end

/* -------------- Output Logic -------------- */

assign o_crc = lut_3[table_index[3]] ^ lut_2[table_index[2]] ^ lut_1[table_index[1]] ^ lut_0[table_index[0]];
assign o_crc_state = temp_crc;

endmodule