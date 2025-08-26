`include "block_sync_pkg.sv"

module block_sync_top;

    import block_sync_pkg::*;

    /* Parameters */
    localparam DUT_DATA_WIDTH = 32;
    localparam HDR_WIDTH = 2;

    /* Signal Declarations */
    logic clk;
    logic reset_n;
    // Sync to Descrambler
    logic [DUT_DATA_WIDTH-1:0] o_data;
    logic [HDR_WIDTH-1:0] o_data_hdr;
    logic o_data_valid;
    // Transciever to sync
    logic i_slip;
    logic [DUT_DATA_WIDTH-1:0] i_data;

    int slip_cntr = 0;
    int allow_slip = 1;

    /* DUT Instantiation */
    block_sync #(
        .DATA_WIDTH(DUT_DATA_WIDTH),
        .HDR_WIDTH(HDR_WIDTH)
    ) DUT (
        .i_clk(clk),
        .i_reset_n(reset_n),
        .o_tx_data(o_data),
        .o_tx_sync_hdr(o_data_hdr),
        .o_tx_data_valid(o_data_valid),
        .i_slip(i_slip),
        .i_rx_data(i_data)  
    );

    /* Drive Stimulus Tasks */
    task drive_data();
        logic [DUT_DATA_WIDTH-1:0] data_vector;
        int i;
        logic slip;

        generate_66b_block();  

        // Pull data out of the data_stream queue to create a 64 bit word
        for(i = 0; i < 32; i++)
            data_vector[i] = data_stream.pop_back();

        $display("Data Transmitted: %08h", data_vector);

        slip = (allow_slip) ? set_slip(i_slip) : 1'b0;
        
        // Transmit the data 
        // The i_slip input is set to 1'b1 with a 10% probability
        // to make this more realistic to the actual design.        
        i_slip <= slip;       
        i_data <= data_vector;      
        @(posedge clk);
        
        if (i_slip)
            slip_set <= 1'b1;        

        $display("i_slip Value: %0b, slip_set value: %0b", i_slip, slip_set);

        if (i_slip) begin
            if(slip_cntr < 65)
                slip_cntr++;
            else
                allow_slip = 0;
        end
    
    endtask : drive_data

    /* Read Stimulus */
    task read_data();

        logic [HDR_WIDTH-1:0] o_hdr;
        logic [DUT_DATA_WIDTH-1:0] o_data_word [1:0];

        encoded_data_t ref_data;

        int i;   

        // Get reference data for validation
        ref_data = get_ref_data();             

        for(i = 0; i < 2; i++) begin            
            
            @(posedge clk iff o_data_valid);  

            $display("Slip Value: %0b", slip_set);  

            if (slip_set) begin
                slip_data(i, ref_data); 
                slip_set = 1'b0;
            end

            // Sample the sync header only if it is the first transmitted cycle
            if (i == 0)
                o_hdr = o_data_hdr;

            // Sample data word
            o_data_word[i] = o_data;
        end       

        /* ------- Validation Logic ------- */ 
        validate_hdr(ref_data.sync_hdr, o_hdr);
        validate_data(ref_data.data_word, o_data_word);
         

    endtask : read_data


    task block_sync_model();

        logic [DUT_DATA_WIDTH-1:0] data_vector;
        logic [HDR_WIDTH-1:0] o_hdr;
        logic [DUT_DATA_WIDTH-1:0] o_data_word [1:0];
        logic slip, slip_delayed;

        encoded_data_t ref_data;

        int seq_cntr = 0;
        int i;

        // Validate ref data and data stream
        assert(ref_model.size() == data_stream.size())
            else begin
                $display("Ref queue %0d != Data queue %0d", ref_model.size(), data_stream.size());
                $finish;
            end

        while(data_stream.size() > 32) begin
            /* --- Gather data for next cycle --- */
            for (i = 0; i < 32; i++)
                data_vector[i] = data_stream.pop_back();

            slip = slip_queue.pop_back();

            /* --- Drive DUT inputs --- */
            i_slip <= slip;
            i_data <= data_vector;

            /* --- Wait one clock so DUT sees inputs --- */
            @(posedge clk);
            $display("i_slip: %0b, delayed_slip: %0b", i_slip, slip_delayed);

            /* --- Sample outputs --- */
            if (o_data_valid) begin
                // Fetch output data from DUT
                if (seq_cntr % 2 == 0) begin
                    o_hdr = o_data_hdr;
                    o_data_word[0] = o_data;
                end else
                    o_data_word[1] = o_data;

                // Get reference data
                if (seq_cntr % 2 == 0)
                    ref_data = get_ref_data();

                // Apply slip from previous cycle
                if (i_slip) 
                    slip_data((seq_cntr % 2 == 0), ref_data);

                // Validate only on every second word
                if (seq_cntr % 2 == 1) begin
                    validate_hdr(ref_data.sync_hdr, o_hdr);
                    validate_data(ref_data.data_word, o_data_word);
                end

                seq_cntr++;
            end
        
            /* --- Update delayed slip --- */
            slip_delayed <= i_slip;  
        
        end        
        
    endtask : block_sync_model

    /* Clock Instantiation */

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    /* Stimulus */
    initial begin

        i_slip = 1'b0;
        i_data = '0;

        // Initial Reset for design
        reset_n = 1'b0;
        @(posedge clk);
        reset_n <= 1'b1;  

        // Generate a large serial bit stream
        //generate_serial_bit_stream(65); 

        //block_sync_model();   

        fork
            begin
                repeat(500) begin
                    drive_data();                    
                end
            end
            begin
                while(1) begin
                    read_data();                    
                end
            end
        join_any
        disable fork;

        #100;
        scb.print_summary();

        $finish;
    end

endmodule : block_sync_top