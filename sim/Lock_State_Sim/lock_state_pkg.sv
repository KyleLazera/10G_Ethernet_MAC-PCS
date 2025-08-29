
package lock_state_pkg;

    `include "../Common/scoreboard_base.sv"

    localparam HDR_WIDTH = 2;

    scoreboard_base scb = new();

    //----------------------------------------------------------
    // This function generates a random 2-bit header value to be
    // used as input to the DUT. It generates both valid and
    // invalid headers randomly.
    //----------------------------------------------------------    
    function logic [HDR_WIDTH-1:0] generate_header();
        logic [HDR_WIDTH-1:0] hdr;
        hdr = $urandom_range(0,3);
        return hdr;
    endfunction : generate_header

    //----------------------------------------------------------
    // This function represents the golden model for the lock state
    // machine. It is used to compare the output of the DUT
    // to ensure correct functionality.
    //----------------------------------------------------------
    task golden_model(
        input logic i_clk,
        input logic i_hdr_valid, 
        input logic [HDR_WIDTH-1:0] i_hdr,
        output logic o_slip, 
        output logic o_block_lock);

        typedef enum logic [2:0] {
            RESET_CNT,
            TEST_SH,
            VALID_SH,
            INVALID_SH
        } lock_state_t;

        lock_state_t state;
        logic [5:0] sh_counter = '0;
        logic [3:0] sh_invalid_cntr = '0;
        logic block_lock = 1'b0;
        logic slip = 1'b0;
        logic sh_valid;

        //  Initialize state
        state = RESET_CNT;

        while(1) begin

            case(state)
                RESET_CNT: begin
                    slip = 1'b0;
                    block_lock = 1'b0;
                    sh_counter = '0;
                    sh_invalid_cntr = '0;
                    block_lock = 1'b0;
                    state = TEST_SH;
                end
                TEST_SH: begin
                    if (i_hdr_valid) begin
                        if(!(^i_hdr)) begin                            
                            state = INVALID_SH;
                        end else begin
                            state = VALID_SH;
                        end
                    end
                end
                VALID_SH: begin
                    if (sh_counter < 64)
                        state = TEST_SH;
                    else if (sh_counter == 64 & sh_invalid_cntr == 0) begin 
                        block_lock = 1'b1;
                        state = RESET_CNT;
                    end else if (sh_counter == 64 & sh_invalid_cntr != 0) begin
                        state = RESET_CNT;
                    end

                    sh_counter = sh_counter + 1;
                end
                INVALID_SH: begin
                    
                    if (sh_counter == 64 && sh_invalid_cntr < 16 && block_lock) begin
                        state = RESET_CNT;
                    end else if (sh_invalid_cntr == 16 || !block_lock) begin
                        slip = 1'b1;
                        block_lock = 1'b0;
                        state = RESET_CNT;
                    end else begin
                        state = TEST_SH;
                    end

                    sh_invalid_cntr = sh_invalid_cntr + 1;
                end
            endcase     

            @(posedge i_clk);       

        end


    endtask : golden_model

    function void validate_slip(input logic slip, input logic ref_slip);
        assert(slip == ref_slip) begin
            $display("SLIP MATCH: DUT SLIP = %0b, REF SLIP = %0b", slip, ref_slip);
            scb.record_success();
        end else begin
            $error("SLIP MISMATCH: DUT SLIP = %0b, REF SLIP = %0b", slip, ref_slip);
            scb.record_failure();
        end
    endfunction : validate_slip

    function void validate_block_lock(input logic block_lock, input logic ref_block_lock);
        assert(block_lock == ref_block_lock) begin
            $display("BLOCK LOCK MATCH: DUT BLOCK LOCK = %0b, REF BLOCK LOCK = %0b", block_lock, ref_block_lock);
            scb.record_success();
        end else begin
           $error("BLOCK LOCK MISMATCH: DUT BLOCK LOCK = %0b, REF BLOCK LOCK = %0b", block_lock, ref_block_lock);
           scb.record_failure(); 
        end
    endfunction : validate_block_lock

endpackage : lock_state_pkg