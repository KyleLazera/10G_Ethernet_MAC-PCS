`include "mac_pkg.sv"


interface xgmii_if #(
    parameter XGMII_DATA_WIDTH,
    parameter XGMII_CTRL_WIDTH
)(
    input logic clk,
    input logic i_reset_n
);

import mac_pkg::*;

// XGMII Output Signals
logic [XGMII_DATA_WIDTH-1:0]     o_xgmii_txd;
logic [XGMII_CTRL_WIDTH-1:0]     o_xgmii_ctrl;
logic                            o_xgmii_valid;
logic                            i_xgmii_pause;

function void init_xgmii();
    i_xgmii_pause = 1'b0;
endfunction : init_xgmii

task sample_xgmii_data(output xgmii_stream_t sampled_data[$]);

    xgmii_stream_t xgmii;

    // TODO: Make dynamic 
    i_xgmii_pause = 1'b0;

    // Clear sampled_data queue if already contains data
    sampled_data.delete();

    // Wait for the IDLE cycles to pass
    while(o_xgmii_ctrl == 4'hF)
        @(posedge clk);

    while (o_xgmii_ctrl != 4'hF) begin
        xgmii.xgmii_data = o_xgmii_txd;
        xgmii.xgmii_ctrl = o_xgmii_ctrl;
        xgmii.xgmii_valid = o_xgmii_valid;
        sampled_data.push_back(xgmii);
        @(posedge clk);
    end

    // Sample the final output word
    xgmii.xgmii_data = o_xgmii_txd;
    xgmii.xgmii_ctrl = o_xgmii_ctrl;
    xgmii.xgmii_valid = o_xgmii_valid;
    sampled_data.push_back(xgmii);

    @(posedge clk);

endtask : sample_xgmii_data


endinterface : xgmii_if