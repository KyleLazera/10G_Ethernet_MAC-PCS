`include "mac_pkg.sv"

class xgmii_obj;
    rand bit xgmii_pause;
    constraint c_xgmii_pause {xgmii_pause dist {1 := 1, 0:= 99};}

    function new();
    endfunction
endclass : xgmii_obj


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

xgmii_obj xgmii_obj_t;;

function void init_xgmii();
    i_xgmii_pause = 1'b0;
endfunction : init_xgmii

task automatic sample_xgmii_data(output xgmii_stream_t sampled_data[$]);

    xgmii_stream_t xgmii;

    int cntr = 0;

    // TODO: Make dynamic 
    i_xgmii_pause = 1'b0;

    // Wait for the IDLE cycles to pass
    while(o_xgmii_ctrl == 4'hF)
        @(posedge clk);

    while (o_xgmii_ctrl != 4'hF) begin
        assert(xgmii_obj_t.randomize()) else $fatal("Failed to randomize xgmii pause object");
        if (o_xgmii_valid) begin
            xgmii.xgmii_data = o_xgmii_txd;
            xgmii.xgmii_ctrl = o_xgmii_ctrl;
            xgmii.xgmii_valid = o_xgmii_valid;
            sampled_data.push_back(xgmii);
        end
        i_xgmii_pause <= xgmii_obj_t.xgmii_pause;
        @(posedge clk);
        cntr++;
    end

    // Wait for the valid signal to be high again
    if (!o_xgmii_valid)
        @(posedge o_xgmii_valid);

    // Sample the final output word
    xgmii.xgmii_data = o_xgmii_txd;
    xgmii.xgmii_ctrl = o_xgmii_ctrl;
    xgmii.xgmii_valid = o_xgmii_valid;
    sampled_data.push_back(xgmii);

    @(posedge clk);

endtask : sample_xgmii_data


endinterface : xgmii_if