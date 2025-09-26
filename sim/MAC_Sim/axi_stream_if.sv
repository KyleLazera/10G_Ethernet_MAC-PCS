`include "mac_pkg.sv"


interface axi_stream_if
#(
    parameter DATA_WIDTH
)
(
    input logic clk,
    input logic reset_n
);

import mac_pkg::*;

localparam KEEP_WIDTH = DATA_WIDTH/8;

/* AXI Stream Slave Signals */

logic [DATA_WIDTH-1:0]  s_axis_tdata;
logic [KEEP_WIDTH-1:0]  s_axis_tkeep;
logic                   s_axis_tvalid;
logic                   s_axis_tlast;
logic                   s_axis_trdy;

/* AXI Stream Methods (BFM)*/

task init_axi_stream();
    s_axis_tdata = '0;
    s_axis_tkeep = '0;
    s_axis_tvalid = 1'b0;
    s_axis_tlast = 1'b0;
    s_axis_trdy = 1'b0;
endtask: init_axi_stream

task drive_data_axi_stream(ref axi_stream_t data_queue[$]);

    axi_stream_t axi_pkt;
    int data_size = data_queue.size();

    axi_pkt = data_queue.pop_back();

    // Put intial data on the data line
    s_axis_tdata <= axi_pkt.axis_tdata;
    s_axis_tkeep <= axi_pkt.axis_tkeep;

    // Continue to transmit data while there is data in the queue
    while(data_queue.size()) begin

        s_axis_tvalid <= axi_pkt.axis_tvalid;

        // If AXI handshake is met, transmit data 
        if (s_axis_trdy & s_axis_tvalid) begin
            axi_pkt = data_queue.pop_back();
            s_axis_tdata <= axi_pkt.axis_tdata;
            s_axis_tkeep <= axi_pkt.axis_tkeep;

            if (data_queue.size() == 0)
                s_axis_tlast <= axi_pkt.axis_tlast;
        end

        @(posedge clk);
    end

    s_axis_tlast <= 1'b0;
    s_axis_tvalid <= 1'b0;
    s_axis_tkeep <= 4'h0;
    @(posedge clk);


endtask : drive_data_axi_stream


endinterface : axi_stream_if