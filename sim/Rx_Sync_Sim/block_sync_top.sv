`include "block_sync_pkg.sv"
`include "../Common/scoreboard_base.sv"

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

    scoreboard_base scb = new();

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
        
        i_slip = 1'b0;

        // Generate encoded data - this populates the data_stream queue
        // and reference queue
        generate_66b_block();

        // Pull data out of the data_stream queue to create a 64 bit word
        for(i = 0; i < 32; i++)
            data_vector[i] = data_stream.pop_back();
        
        // Transmit the data with the least significant word first
        i_data <= data_vector;
        @(posedge clk);
    
    endtask : drive_data

    /* Read Stimulus */
    task read_data();
        encoded_data_t rx_expected_block;

        int i;

        logic [HDR_WIDTH-1:0] o_hdr;
        logic [DUT_DATA_WIDTH-1:0] o_data_word [1:0];

        // Fetch the expected data from the reference queue
        rx_expected_block = ref_model.pop_back();

        for(i = 0; i < 2; i++) begin
            
            @(posedge clk iff o_data_valid);                    

            // Sample the sync header only if it is the first transmitted cycle
            if (i == 0)
                o_hdr = o_data_hdr;
            
            // Sample data word
            o_data_word[i] = o_data;
        end

        // Validate Header Data First 
        assert(o_hdr == rx_expected_block.sync_hdr) begin
            $display("MATCH: Header expected: %0h == Actual header: %0h", rx_expected_block.sync_hdr, o_hdr);
            scb.record_success();
        end else begin
            $display("MISMATCH: Header expected: %0h != Actual header: %0h", rx_expected_block.sync_hdr, o_hdr);
            scb.record_failure();
        end
            

        // Validate the data words
        foreach(rx_expected_block.data_word[i])
            assert(o_data_word[i] == rx_expected_block.data_word[i]) begin
                $display("MATCH: Expected Data[%0d]: %0h == Actual Data[%0d]: %0h", i, rx_expected_block.data_word[i], i, o_data_word[i]);
                scb.record_success();
            end else begin
                $display("MISMATCH: Expected Data[%0d]: %0h != Actual Data[%0d]: %0h", i, rx_expected_block.data_word[i], i, o_data_word[i]);   
                scb.record_failure();     
            end

    endtask : read_data

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