
package lock_state_pkg;

    `include "../Common/scoreboard_base.sv"

    localparam HDR_WIDTH = 2;

    typedef struct{
        logic [HDR_WIDTH-1:0] header;
        logic header_valid;
        logic slip;
        logic block_lock;
    } lock_state_transaction_t;

    lock_state_transaction_t sync_queue[$];

    scoreboard_base scb = new();

    event data_tx, data_rx;

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
    task golden_model(input logic i_clk);

        typedef enum logic {
            RESET_CNT,
            TEST_SH
        } lock_state_t;

        lock_state_transaction_t actual_data;
        lock_state_t state;
        logic [5:0] sh_counter = '0;
        logic [3:0] sh_invalid_cntr = '0;
        logic sh_valid;
        logic o_slip, pipe_slip;
        logic o_block_lock, pipe_block_lock;

        //  Initialize state
        state = RESET_CNT;

        while(sync_queue.size() != 0) begin  
            actual_data = sync_queue.pop_back();
            $display("DUT Header: %0d, valid: %0b, slip: %0b, block_lock: %0b", actual_data.header, actual_data.header_valid, actual_data.slip, actual_data.block_lock);                  

            case(state)
                RESET_CNT: begin
                    o_slip = 1'b0;
                    o_block_lock = 1'b0;
                    sh_counter = '0;
                    sh_invalid_cntr = '0;
                    state = TEST_SH;
                end
                TEST_SH: begin
                    if (actual_data.header_valid) begin
                        sh_counter = sh_counter + 1;
                        // ------- Invalid Header State ------- //
                        if(!(^actual_data.header)) begin        
                            $display("Header %0d is invalid", actual_data.header);
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

            if (pipe_slip !== 1'bx || pipe_block_lock !== 1'bx) begin
                validate_slip(actual_data.slip, pipe_slip);
                validate_block_lock(actual_data.block_lock, pipe_block_lock);    
            end

            pipe_slip = o_slip;
            pipe_block_lock = o_block_lock;       

        end
    endtask : golden_model

    function void validate_slip(input logic slip, input logic ref_slip);
        assert(slip == ref_slip) begin
            $display("MATCH: DUT slip = %0b, ref slip = %0b", slip, ref_slip);
            scb.record_success();
        end else begin
            $display("MISMATCH: DUT slip = %0b, ref slip = %0b", slip, ref_slip);
            scb.record_failure();
            $finish;
        end
    endfunction : validate_slip

    function void validate_block_lock(input logic block_lock, input logic ref_block_lock);
        assert(block_lock == ref_block_lock) begin
            $display("MATCH: DUT block lock = %0b, ref block lock = %0b", block_lock, ref_block_lock);
            scb.record_success();
        end else begin
           $display("MISMATCH: DUT block lock = %0b, ref block lock = %0b", block_lock, ref_block_lock);
           scb.record_failure(); 
           $finish;
        end
    endfunction : validate_block_lock

endpackage : lock_state_pkg