package block_sync_pkg;

    `include "../Common/scoreboard_base.sv"
    `include "circular_buffer.sv"

    /* Parameters */
    parameter DATA_WIDTH = 32;
    parameter HDR_WIDTH = 2;
    parameter BLOCK_SIZE = 66;

    /* Data Queues */
    logic ref_model[$];
    logic data_stream[$];
    logic slip_queue[$];

    /* Synchronization Events */
    event data_transmitted;

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

    typedef struct{
        logic [HDR_WIDTH-1:0] ref_hdr;
        logic [DATA_WIDTH-1:0] ref_data;        
    } ref_data_t;

    int slip_set;
    int slip_count = 0;

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

        ref_model.push_front(data.sync_hdr[0]);
        ref_model.push_front(data.sync_hdr[1]);        

        // Randomize data words and push into data stream queue
        for(i = 0; i < 2; i++) begin
            data.data_word[i] = $urandom;
            for(j = 0; j < 32; j++) begin
                data_stream.push_front(data.data_word[i][j]);
                ref_model.push_front(data.data_word[i][j]);
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
    // This function is used to fetch and format the reference data into 
    // the 64/66b encoded data block:
    //
    //  {data[65:2], hdr[1:0]}
    //
    // It encapsulates the data within a struct and returns the struct for 
    // further validation.
    //---------------------------------------------------------------------      
    function encoded_data_t get_ref_data(bit slip);

        logic [65:0] rx_expected_block;
        encoded_data_t ref_data;

        int i;

        // Generate a 66-bit word from ref-model for verification
        for(i = 0; i < 66; i++)
            rx_expected_block[i] = ref_model.pop_back();   

        // Break 66 bit block into individual components & encapsulate
        ref_data.sync_hdr = rx_expected_block[1:0];
        ref_data.data_word[0] = rx_expected_block[33:2];
        ref_data.data_word[1] = rx_expected_block[65:34];    

        $display("Reference Data:");
        $display("Sync Header: %0h", ref_data.sync_hdr);
        $display("Data word 0: %0h", ref_data.data_word[0]);
        $display("Data Word 1: %0h", ref_data.data_word[1]);        

        return ref_data;    

    endfunction : get_ref_data

    //---------------------------------------------------------------------
    // This function is used to adjust the reference data based on the 
    // i_slip signal.
    //---------------------------------------------------------------------        
    function void slip_data(int data_index, ref encoded_data_t ref_data);

        /*$display("Slip requested at index %0d", data_index);

        // Increment slip count
        slip_count++;

        // On slip: overwrite the current word with the new one
        if (data_index == 0) begin
            ref_data.data_word[0] = ref_data.data_word[1];
            ref_data.data_word[1] = ref_model.pop_back();
        end else begin
            ref_data.data_word[1] = ref_model.pop_back();
        end

        // Adjust header interpretation depending on slip parity
        if (!(slip_count % 2 == 0)) begin
            // Even slips → normal interpretation (bits [0:1])
            ref_data.sync_hdr = {ref_data.data_word[0][1], ref_data.data_word[0][0]};
        end else begin
            // Odd slips → shifted interpretation (bits [1:2])
            ref_data.sync_hdr = {ref_data.data_word[0][2], ref_data.data_word[0][1]};
        end

        $display("Slip Count = %0d (parity = %s)", 
                  slip_count, (slip_count % 2) ? "ODD" : "EVEN");
        $display("Adjusted sync header = %0b", ref_data.sync_hdr);*/

        if (data_index == 0)
            ref_model.pop_back();
        else
            for(int i = 32; i < 64; i++)
                ref_model.delete(i);

    endfunction : slip_data

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