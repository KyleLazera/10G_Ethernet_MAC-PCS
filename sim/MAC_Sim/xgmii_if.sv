`include "mac_pkg.sv"

// Object used to randomize & Store XGMII Pause
class xgmii_obj;
    rand bit xgmii_pause;
    
    constraint c_xgmii_pause {xgmii_pause dist {1 := 1, 0:= 99};}

    function new();
    endfunction
endclass 


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

// XGMII Input Signals
logic [XGMII_DATA_WIDTH-1:0]     i_xgmii_data;
logic [XGMII_CTRL_WIDTH-1:0]     i_xgmii_ctrl;
logic                            i_xgmii_valid;

xgmii_obj xgmii_obj_t;

function void init_xgmii();
    xgmii_obj xgmii_object_t = new();
    xgmii_obj_t = xgmii_object_t;
    i_xgmii_pause = 1'b0;
    i_xgmii_data = {XGMII_DATA_WIDTH{8'h00}};
    i_xgmii_ctrl = {XGMII_CTRL_WIDTH{1'b0}};
    i_xgmii_valid = 1'b0;
endfunction : init_xgmii

task automatic drive_xgmii_data(input xgmii_stream_t xgmii_q[$]);

    xgmii_stream_t xgmii;
    int stream_size = xgmii_q.size();

    repeat(stream_size) begin
        xgmii = xgmii_q.pop_front();
        i_xgmii_data <= xgmii.xgmii_data;
        i_xgmii_ctrl <= xgmii.xgmii_ctrl;
        i_xgmii_valid <= xgmii.xgmii_valid;
        @(posedge clk);
    end


endtask : drive_xgmii_data

task automatic sample_xgmii_data(output xgmii_stream_t sampled_data[$]);

    xgmii_stream_t xgmii;
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