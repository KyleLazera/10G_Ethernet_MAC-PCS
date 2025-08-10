`include "../Common/scoreboard_base.sv"

class pcs_scb extends scoreboard_base;
    
    function new();
        super.new();    
    endfunction : new

    function verify_data(logic [31:0] expected_data, logic [31:0] actual_data);
        assert(expected_data == actual_data) begin
            $display("MATCH: Actual Data: %0h == Expected Data: %0h", actual_data, expected_data);
            record_success();
        end else begin
            $display("MISMATCH: Actual Data: %0h != Expected Data: %0h", actual_data, expected_data);
            record_failure(); 
        end
    endfunction : verify_data
endclass 