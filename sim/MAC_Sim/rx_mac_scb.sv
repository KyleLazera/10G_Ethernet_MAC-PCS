`ifndef RX_MAC_SCB
`define RX_MAC_SCB

`include "mac_pkg.sv"
`include "../Common/scoreboard_base.sv"

import mac_pkg::*;

class rx_mac_scb extends scoreboard_base;
    
    function new();
        super.new();    
        packet_match_success = 0;
        packet_match_failure = 0;
    endfunction : new

    int packet_match_success;
    int packet_match_failure;

    function record_packet_failure();
        packet_match_failure++;
    endfunction

    function record_packet_success();
        packet_match_success++;
    endfunction    

    function void print_summary();
        int unsigned total_pkts = packet_match_failure + packet_match_success;
        $display("----- Scoreboard Summary -----");
        $display("Total Tests Run : %0d", total_pkts);
        $display("Packet Successes: %0d", packet_match_success);
        $display("Packet Failures : %0d", packet_match_failure);
        $display("Data Successes  : %0d", num_successes);
        $display("Data Failures   : %0d", num_failures);
        $display("------------------------------");
    endfunction    

    function void isolate_valid_data(ref axi_stream_t ref_data, ref axi_stream_t output_data);

        for(int i = 0; i < 4; i++) begin
            if (!output_data.axis_tkeep[i])
                output_data.axis_tdata[(i*8) +: 8] = 8'h00;

            if (!ref_data.axis_tkeep[i])
                ref_data.axis_tdata[(i*8) +: 8] = 8'h00;
        end

    endfunction : isolate_valid_data

    function verify_data(ref axi_stream_t output_data[$], ref axi_stream_t ref_data[$]);
        
        int output_data_size, ref_data_size;
        axi_stream_t output_pkt, ref_pkt;

        output_data_size = output_data.size();
        ref_data_size = ref_data.size();

        /* Validate Size of queues */
        if (output_data_size == ref_data_size) begin
            record_packet_success();
            $display("MATCH Output Size: %0d == Ref Size %0d", output_data.size(), ref_data.size());
            // Compare valid data only
            while(ref_data.size()) begin
                output_pkt = output_data.pop_back();
                ref_pkt = ref_data.pop_back();

                isolate_valid_data(ref_pkt, output_pkt);

                assert(ref_pkt.axis_tdata == output_pkt.axis_tdata) begin
                    record_success();
                    //$display("MATCH: Output %0h == Ref: %0h", output_pkt.axis_tdata, ref_pkt.axis_tdata);
                end else begin
                    record_failure();
                    $display("MISMATCH: Output %0h != Ref: %0h", output_pkt.axis_tdata, ref_pkt.axis_tdata);
                end
            end
        end else begin
            $display("MISMATCH of the output data. Expected: %0d Actual: %0d", ref_data.size(), output_data.size());
            record_packet_failure();

            foreach(output_data[i])
                $display("Expected: %0h, Actual: %0h", ref_data[i].axis_tdata, output_data[i].axis_tdata);

            $stop;
        end 
        
    endfunction : verify_data

endclass : rx_mac_scb

`endif // RX_MAC_SCB