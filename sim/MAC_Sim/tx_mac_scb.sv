`include "../Common/scoreboard_base.sv"
`include "mac_pkg.sv"

import mac_pkg::*;

class tx_mac_scb extends scoreboard_base;
    
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

    function verify_data(xgmii_stream_t expected_data[$], xgmii_stream_t actual_data[$]);
        
        int actual_data_size, ref_data_size;

        actual_data_size = actual_data.size();
        ref_data_size = expected_data.size();

        /* Validate Size of Queues */
        if (actual_data_size == ref_data_size) begin
            record_packet_success();
            foreach(actual_data[i]) begin
                assert(actual_data[i] == expected_data[i]) begin
                    record_success();
                end else begin
                    $fatal("Data Mismatch on word %0d", i);
                    record_failure();
                    $display("XGMII Actual Data: %0h, XGMII Expected Data: %0h", actual_data[i].xgmii_data, expected_data[i].xgmii_data);
                    $display("XGMII Actual Control: %0h XGMII Expected Control: %0h", actual_data[i].xgmii_ctrl, expected_data[i].xgmii_ctrl);
                    $display("XGMII Actual Valid: %0b XGMII Expected Valid: %0b", actual_data[i].xgmii_valid, expected_data[i].xgmii_valid);
                end
            end
        end else begin
            $display("Expected Packet Size: %0d != Actual Packet Size: %0d", ref_data_size, actual_data_size);
            record_packet_failure();
        end
        
    endfunction : verify_data

endclass : tx_mac_scb