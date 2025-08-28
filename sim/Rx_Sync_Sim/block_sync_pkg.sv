package block_sync_pkg;

    `include "../Common/scoreboard_base.sv"
    `include "circular_buffer.sv"

    /* Parameters */
    parameter DATA_WIDTH = 32;
    parameter HDR_WIDTH = 2;
    parameter BLOCK_SIZE = 66;

    /* Data Queues */
    logic data_stream[$];

    /* Class Initializations */
    scoreboard_base scb = new();
    circular_buffer #(
        .BUFFER_SIZE(BLOCK_SIZE), 
        .BUFF_DATA_WIDTH(DATA_WIDTH)
    ) buffer = new();

    /* Variables/Structs */
    typedef struct{
        logic [HDR_WIDTH-1:0] sync_hdr;
        logic [DATA_WIDTH-1:0] data_word [1:0];
    } encoded_data_t;

    //---------------------------------------------------------------------
    // This function generates a 66 bit block of data in the format output
    // by a 64b/66b encoder:
    //
    //  {data_words[65:2], sync_hdr[1:0]}
    //
    // It then appends each bit from this block into a data_stream queue
    // for data transmission & adds the full encoded data to a reference 
    // queue for comparison.
    //---------------------------------------------------------------------
    function void generate_66b_block();

        encoded_data_t data;
        int i,j;

        // Randomize sync header & append bits to data stream
        data.sync_hdr = $urandom_range(1, 2);
        data_stream.push_front(data.sync_hdr[0]);
        data_stream.push_front(data.sync_hdr[1]);     

        // Randomize data words and push into data stream queue
        for(i = 0; i < 2; i++) begin
            data.data_word[i] = $urandom;
            for(j = 0; j < 32; j++) begin
                data_stream.push_front(data.data_word[i][j]);
            end
        end

    endfunction : generate_66b_block  

    //---------------------------------------------------------------------
    // Helper function that is used to randomize the probability of setting
    // the i_slip input to the design. This function randomizes this with a 
    // 10% probability of being set on each occasion.
    //---------------------------------------------------------------------    
    function bit set_slip(bit current_slip);
        int rand_num;

        rand_num = $urandom_range(0, 10);

        // i_slip MUST be only a pulse, it cannot be 2 pulses back to back
        if (current_slip)
            return 1'b0;

        if (rand_num == 10) begin
            $display("i_slip set to 1'b1");
        end

        return (rand_num == 10);
    endfunction : set_slip

    //---------------------------------------------------------------------
    // Simple validation function used to validate header and send the validation
    // results to the scoreboard for logging.
    //---------------------------------------------------------------------    
    function void validate_hdr(logic [1:0] expected_hdr, logic [1:0] actual_hdr);
        assert(expected_hdr == actual_hdr) begin
            $display("MATCH: Header expected: %0h == Actual header: %0h", expected_hdr, actual_hdr);
            scb.record_success();
        end else begin
            $display("MISMATCH: Header expected: %0h != Actual header: %0h", expected_hdr, actual_hdr);
            scb.record_failure();
        end        
    endfunction : validate_hdr

    //---------------------------------------------------------------------
    // Simple validation function used to validate data words and send the validation
    // results to the scoreboard for logging.
    //---------------------------------------------------------------------    
    function void validate_data(logic [DATA_WIDTH-1:0] expected_data, logic [DATA_WIDTH-1:0] actual_data);
        assert(expected_data == actual_data) begin
            $display("MATCH: Expected Data: %0h == Actual Data: %0h", expected_data, actual_data);
            scb.record_success();                
        end else begin
            $display("MISMATCH: Expected Data: %0h != Actual Data: %0h", expected_data, actual_data);   
            scb.record_failure();   
        end

        if (scb.num_failures != 0)
            $finish;
    endfunction : validate_data


endpackage : block_sync_pkg