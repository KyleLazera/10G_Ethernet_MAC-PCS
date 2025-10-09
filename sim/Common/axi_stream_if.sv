`include "../MAC_Sim/mac_pkg.sv"


interface axi_stream_if
#(
    parameter DATA_WIDTH
)
(
    input logic clk,
    input logic reset_n
);

import mac_pkg::axi_stream_t;

localparam KEEP_WIDTH = DATA_WIDTH/8;

/* AXI Stream Master Signals */

logic [DATA_WIDTH-1:0]  m_axis_tdata;
logic [KEEP_WIDTH-1:0]  m_axis_tkeep;
logic                   m_axis_tvalid;
logic                   m_axis_tlast;
logic                   m_axis_trdy;

/* AXI Stream Slave Signals */

logic [DATA_WIDTH-1:0]  s_axis_tdata;
logic [KEEP_WIDTH-1:0]  s_axis_tkeep;
logic                   s_axis_tvalid;
logic                   s_axis_tlast;
logic                   s_axis_trdy;

/* AXI Stream Methods (BFM)*/

task init_axi_stream();
    m_axis_tdata = '0;
    m_axis_tkeep = '0;
    m_axis_tvalid = 1'b0;
    m_axis_tlast = 1'b0;
    m_axis_trdy = 1'b0;
    s_axis_trdy = 1'b0;
endtask: init_axi_stream

task drive_data_axi_stream(input axi_stream_t data_queue[$]);

    axi_stream_t axi_pkt;
    int data_size = data_queue.size();

    axi_pkt = data_queue.pop_back();

    // Put intial data on the data line
    m_axis_tdata <= axi_pkt.axis_tdata;
    m_axis_tkeep <= axi_pkt.axis_tkeep;

    // Continue to transmit data while there is data in the queue
    while(data_queue.size()) begin

        m_axis_tvalid <= axi_pkt.axis_tvalid;

        // If AXI handshake is met, transmit data 
        if (m_axis_trdy & m_axis_tvalid) begin
            axi_pkt = data_queue.pop_back();
            m_axis_tdata <= axi_pkt.axis_tdata;
            m_axis_tkeep <= axi_pkt.axis_tkeep;

            if (data_queue.size() == 0)
                m_axis_tlast <= axi_pkt.axis_tlast;
        end

        @(posedge clk);
    end

    while(!(m_axis_trdy & m_axis_tvalid))
        @(posedge clk);
    
    m_axis_tlast <= 1'b0;
    m_axis_tvalid <= 1'b0;
    m_axis_tkeep <= 4'h0;
    @(posedge clk);


endtask : drive_data_axi_stream

task sample_axi_data(output axi_stream_t sampled_data[$]);

    axi_stream_t data;

    s_axis_trdy <= 1'b1;

    while(s_axis_tvalid) begin
        data.axis_tdata = s_axis_tdata;
        data.axis_tkeep = s_axis_tkeep;
        data.axis_tlast = s_axis_tlast;
        data.axis_tvalid = s_axis_tvalid;
        sampled_data.push_back(data);
        @(posedge clk);
    end

endtask : sample_axi_data


endinterface : axi_stream_if