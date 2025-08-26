package block_sync_pkg;

    `include "../Common/scoreboard_base.sv"

    /* Parameters */
    parameter DATA_WIDTH = 32;
    parameter HDR_WIDTH = 2;

    /* Data Queues */
    logic ref_model[$];
    logic data_stream[$];
    logic slip_queue[$];

    /* Synchronization Events */
    event data_transmitted;

    /* Scoreboard class Init */
    scoreboard_base scb = new();

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
    int cycle_cntr = 0;

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

    function void generate_32b_block();

        logic [DATA_WIDTH-1:0] data_word;
        logic slip_word;

        int i;
        int slip_size;

        slip_size = slip_queue.size();

        $display("Slip Size: %0d, last Value: %0b", slip_size, slip_queue[0]);

        // Randomize a 32 bit word
        data_word = $urandom; 

        // Make sure we do not set the slip value in 2 conditions:
        // 1) There was a slip on the previous input
        // 2) It is the first cycle of the simulation
        if (slip_size != 0)
            slip_word = set_slip(slip_queue[0]);
        else
            slip_word = 1'b0;

        // Randomize data words and push into data stream queue
        for(i = 0; i < 32; i++) begin
            data_stream.push_front(data_word[i]);
            ref_model.push_front(data_word[i]);
        end

        //Push slip inot data stream
        slip_queue.push_front(slip_word);

    endfunction : generate_32b_block    

    //---------------------------------------------------------------------
    // This function utilizes the generate_32b_block to create a serial bit
    // stream with a variable number of 32 bit words & populates the 
    // data_stream, ref_model & slip queues with this data.
    //---------------------------------------------------------------------    
    function void generate_serial_bit_stream(int num_words);

        repeat(num_words)
            generate_32b_block();

    endfunction : generate_serial_bit_stream

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
    function encoded_data_t get_ref_data();

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

        $display("Shifting Word, index %0d", data_index);
        $display("Full data BEFORE shifting: %066b", {ref_data.data_word[1], ref_data.data_word[0], ref_data.sync_hdr});

        if (data_index == 0) begin
            ref_data.sync_hdr = {ref_data.data_word[0][0], ref_data.sync_hdr[1]};
            ref_data.data_word[0] = {ref_data.data_word[1][0], ref_data.data_word[0][DATA_WIDTH-1:1]};
            ref_data.data_word[1] = {ref_model.pop_back(), ref_data.data_word[1][DATA_WIDTH-1:1]};                        
        end else begin
            ref_data.data_word[1] = {ref_model.pop_back(), ref_data.data_word[1][DATA_WIDTH-1:1]};
        end

        $display("Full data AFTER shifting: %066b", {ref_data.data_word[1], ref_data.data_word[0], ref_data.sync_hdr});

        $display("Shifted Word:");
        $display("Sync Header: %0h", ref_data.sync_hdr);
        $display("Data word 0: %0h", ref_data.data_word[0]);
        $display("Data Word 1: %0h", ref_data.data_word[1]);

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
    function void validate_data(logic [DATA_WIDTH-1:0] expected_data [1:0], logic [DATA_WIDTH-1:0] actual_data [1:0]);
        foreach(actual_data[i])
            assert(expected_data[i] == actual_data[i]) begin
                $display("MATCH: Expected Data[%0d]: %0h == Actual Data[%0d]: %0h", i, expected_data[i], i, actual_data[i]);
                scb.record_success();                
            end else begin
                $display("MISMATCH: Expected Data[%0d]: %0h != Actual Data[%0d]: %0h", i, expected_data[i], i, actual_data[i]);   
                scb.record_failure();   
            end

            if (scb.num_failures != 0)
                $finish;
    endfunction : validate_data


endpackage : block_sync_pkg