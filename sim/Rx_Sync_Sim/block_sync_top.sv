`include "../Gearbox_Sim/gearbox_pkg.sv"

import gearbox_pkg::*;

module block_sync_top;

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

    /* Struct Definition */
    encoded_data_t encoded_66b_data;

    // Set USE_TEMP_QUEUE to true
    USE_TEMP_QUEUE = 1;

    /* Drive Stimulus Tasks */
    task drive_data();
        logic [DUT_DATA_WIDTH-1:0] data_vector;

        int i;

        i_slip = 1'b0;

        // Generate encoded data - this is the data that is 
        // recieved from the transceiver
        encoded_66b_data = generate_data();

        // Pull data out of the temp queue to create a 32 bit word
        for(i = 0; i < 32; i++)
            data_vector[i] = temp_queue.pop_back();
        
        i_data <= data_vector;
        @(posedge clk);

    endtask : drive_data

    /* Read Stimulus */
    task read_data();
        logic [DUT_DATA_WIDTH-1:0] rx_ref_data;
        logic [DUT_DATA_WIDTH-1:0] rx_actual_data;
        logic [HDR_WIDTH-1:0] rx_hdr;

        int i;

        // Pull 32 bit word from ref model
        for(i = 0; i < 32; i++)
            rx_ref_data[i] = ref_model.pop_back();

        if (o_data_valid) begin
            rx_actual_data = o_data;
        end

    endtask : read_data

    /* Clock Instantiation */

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    /* Stimulus */
    initial begin

        // Initial Reset for design
        reset_n = 1'b0;
        @(posedge clk);
        reset_n <= 1'b1; 


        repeat(35)
            drive_data();


        //scb.print_summary();

        $finish;
    end

endmodule : block_sync_top