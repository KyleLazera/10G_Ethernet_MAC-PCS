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

    task validate_block_sync(int iterations);
        logic [DUT_DATA_WIDTH-1:0] data_vector;
        logic [HDR_WIDTH-1:0] o_hdr, ref_hdr;
        logic [DUT_DATA_WIDTH-1:0] o_data_word [1:0], ref_data_word [1:0];        
        bit slip;
        bit even;

        int i;        
        int seq_cntr = 0;
        int slip_cntr = 0;

        repeat(iterations) begin

            if (i_slip) begin
                if(slip_cntr < 65)
                    slip_cntr++;
                else
                    allow_slip = 0;
            end            

            even = (seq_cntr % 2 == 0);

            // Pull data out of the data_stream queue to create a 64 bit word
            for(i = 0; i < 32; i++)
                data_vector[i] = data_stream.pop_back();

            slip = (allow_slip) ? set_slip(i_slip) : 1'b0;

            $display("Data: %08h written at buffer: %0d", data_vector, buffer.get_ptr());
            $display("seq_counter %0d", seq_cntr);

            // Write data into the reference circular buffer
            buffer.write(data_vector, slip);
            
            // Transmit the data 
            // The i_slip input is set to 1'b1 with a 10% probability
            // to make this more realistic to the actual design.        
            i_slip <= slip;       
            i_data <= data_vector;  

            @(posedge clk);    

            if (o_data_valid) begin

                if (even) begin                    
                    ref_data_word[1] = buffer.read(((slip_cntr % 2 == 0) ? 34 : 35), DATA_WIDTH);
                end else begin
                    ref_hdr = buffer.read(((slip_cntr % 2 == 0) ? 0 : 1), HDR_WIDTH)[1:0];
                    ref_data_word[0] = buffer.read(((slip_cntr % 2 == 0) ? 2 : 3), DATA_WIDTH);                
                end 

                // Sample the sync header only if it is the first transmitted cycle
                if (even) begin                    
                    o_data_word[1] = o_data;
                    validate_data(ref_data_word[1], o_data_word[1]);  
                end else begin
                    o_hdr = o_data_hdr;
                    o_data_word[0] = o_data;
                    validate_hdr(ref_hdr, o_hdr);
                    validate_data(ref_data_word[0], o_data_word[0]);                    
                end

            end
            
            if(!i_slip)
                seq_cntr = (seq_cntr == 32) ? 0 : seq_cntr + 1;

        end

    endtask : validate_block_sync

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

        repeat(300) begin
            generate_66b_block();
        end

        validate_block_sync(500);

        #100;
        scb.print_summary();

        $finish;
    end

endmodule : block_sync_top