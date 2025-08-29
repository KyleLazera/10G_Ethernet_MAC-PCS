
package lock_state_pkg;

    `include "../Common/scoreboard_base.sv"

    localparam HDR_WIDTH = 2;

    scoreboard_base scb = new();

    event data_sampled;
    event golden_model_done;

    //----------------------------------------------------------
    // This function generates a random 2-bit header value to be
    // used as input to the DUT. It generates invalid headers with 
    // a probability of 33%.
    //----------------------------------------------------------    
    function logic [HDR_WIDTH-1:0] generate_header();
        logic [HDR_WIDTH-1:0] hdr;
        int invalid_hdr;

        invalid_hdr = $urandom_range(0,15);
        if (invalid_hdr == 0)
            hdr = 2'b00; 
        else if (invalid_hdr == 5)
            hdr = 2'b11;
        else
            hdr = $urandom_range(1,2);
        
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
        ref logic o_slip, 
        ref logic o_block_lock);

        typedef enum logic {
            RESET_CNT,
            TEST_SH
        } lock_state_t;

        lock_state_t state;
        logic [5:0] sh_counter = '0;
        logic [3:0] sh_invalid_cntr = '0;
        logic o_block_lock;
        logic sh_valid;

        //  Initialize state
        state = RESET_CNT;

        while(1) begin

            @(data_sampled);

            case(state)
                RESET_CNT: begin
                    o_slip = 1'b0;
                    o_block_lock = 1'b0;
                    sh_counter = '0;
                    sh_invalid_cntr = '0;
                    state = TEST_SH;
                end
                TEST_SH: begin
                    if (i_hdr_valid) begin
                        sh_counter = sh_counter + 1;
                        // ------- Invalid Header State ------- //
                        if(!(^i_hdr)) begin        

                            if (sh_counter == 64 && sh_invalid_cntr < 16 && o_block_lock) begin
                                state = RESET_CNT;
                            end else if (sh_invalid_cntr == 16 || !o_block_lock) begin
                                o_slip = 1'b1;
                                o_block_lock = 1'b0;
                                state = RESET_CNT;
                            end else begin
                                state = TEST_SH;
                            end

                            sh_invalid_cntr = sh_invalid_cntr + 1;
                        // ------- Valid Header State ------- //
                        end else begin
                            if (sh_counter < 64)
                                state = TEST_SH;
                            else if (sh_counter == 64 & sh_invalid_cntr == 0) begin 
                                o_block_lock = 1'b1;
                                state = RESET_CNT;
                            end else if (sh_counter == 64 & sh_invalid_cntr != 0) begin
                                state = RESET_CNT;
                            end
                        end
                    end
                end
            endcase     

            $display("ref_slip: %0b, ref_block_lock: %0b", o_slip, o_block_lock);
            ->golden_model_done;
            @(posedge i_clk);       

        end


    endtask : golden_model

    function void validate_slip(input logic slip, input logic ref_slip);
        assert(slip == ref_slip) begin
            $display("MATCH: DUT slip = %0b, ref slip = %0b", slip, ref_slip);
            scb.record_success();
        end else begin
            $display("MISMATCH: DUT slip = %0b, ref slip = %0b", slip, ref_slip);
            scb.record_failure();
        end
    endfunction : validate_slip

    function void validate_block_lock(input logic block_lock, input logic ref_block_lock);
        assert(block_lock == ref_block_lock) begin
            $display("MATCH: DUT block lock = %0b, ref block lock = %0b", block_lock, ref_block_lock);
            scb.record_success();
        end else begin
           $display("MISMATCH: DUT block lock = %0b, ref block lock = %0b", block_lock, ref_block_lock);
           scb.record_failure(); 
        end
    endfunction : validate_block_lock

endpackage : lock_state_pkg