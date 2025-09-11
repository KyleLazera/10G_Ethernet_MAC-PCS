
interface axi_stream_if
#(
    parameter DATA_WIDTH
)
(
    input logic clk,
    input logic reset_n
);

/* AXI Stream Slave Signals */

logic [DATA_WIDTH-1:0]  s_axis_tdata;
logic                   s_axis_tvalid;
logic                   s_axis_tlast;
logic                   s_axis_trdy;

/* AXI Stream Methods (BFM)*/

task init_axi_stream();
    s_axis_tdata = '0;
    s_axis_tvalid = 1'b0;
    s_axis_tlast = 1'b0;
    s_axis_trdy = 1'b0;
endtask: init_axi_stream

task drive_data_axi_stream(ref logic [DATA_WIDTH-1:0] data_queue[$]);

    int data_size = data_queue.size();

    // Put intial data on the data line
    s_axis_tdata <= data_queue.pop_back();

    // Continue to transmit data while there is data in the queue
    while(data_queue.size()) begin

        $display("Queue size: %0d", data_queue.size());

        s_axis_tvalid <= 1'b1;

        // If AXI handshake is met, transmit data 
        if (s_axis_trdy & s_axis_tvalid) begin
            s_axis_tdata <= data_queue.pop_back();

            if (data_queue.size() == 1)
                s_axis_tlast <= 1'b1;
        end

        @(posedge clk);
    end

    s_axis_tlast <= 1'b0;
    s_axis_tvalid <= 1'b0;
    @(posedge clk);


endtask : drive_data_axi_stream


endinterface : axi_stream_if