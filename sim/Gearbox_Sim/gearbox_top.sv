
`include "gearbox_pkg.sv"
`include "../Common/scoreboard_base.sv"

import gearbox_pkg::*;

/*
 * This testbench is used to verify the basic functionality of the gearbox used for 
 * data transmission in the PCS. For information regarding the design see the README.
 * This simulation utilizes a reference model to compare the actual data retreieved 
 * from the DUT with the expected data. It mainly serves to verify the following:
 *      1) Output data in the correct order/formatting.
 *      2) Ensure the gearbox is not overrun (see README for details on this).
 */

module gearbox_top;

    /* Parameters */
    localparam DUT_DATA_WIDTH = 32;

    /* Variables */
    int cycle_cntr = 0;

    /* Signal Declarations */
    logic clk;
    logic reset_n;
    // Scrambler-to-Gearbox Interface
    logic [DATA_WIDTH-1:0] i_rx_data;
    logic [HDR_WIDTH-1:0] i_rx_sync_hdr;
    logic i_rx_data_valid;
    logic o_tx_trdy;
    // Gearbox Data Output
    logic [DATA_WIDTH-1:0] o_tx_data;

    /* Class Instantiations */
    scoreboard_base scb = new();

    /* DUT Instantiation */
    gearbox #(.DATA_WIDTH(DUT_DATA_WIDTH)) DUT(
        .i_clk(clk),
        .i_reset_n(reset_n),
        .i_rx_data(i_rx_data),
        .i_rx_sync_hdr(i_rx_sync_hdr),
        .i_rx_data_valid(i_rx_data_valid),
        .o_tx_trdy(o_tx_trdy),
        .o_tx_data(o_tx_data)
    );

    /* Drive/Read Stimulus Tasks */
    task drive_data(encoded_data_t tx_data);

        // ---------------------------------------------------------
        // When the gearbox o_tx_rdy signal goes low, this indicates
        // we need an idle cycle. However, in this design, we lower
        // the signal 6 clock cycles in advance. This allows the 
        // signal to propogate to the MAC, and then gives time for the 
        // idle cycle to propogate back to the gearbox and arrive exactly
        // on the 33rd transmission. Therefore, we use a cycle cntr to 
        // determine when to lower the valid flag.
        // ---------------------------------------------------------
        foreach(tx_data.data_word[i]) begin

            // If gearbox is not ready, set cycle counter to 6
            if (!o_tx_trdy) begin
                cycle_cntr = 6;
            end else if(cycle_cntr == 1) begin
                i_rx_data_valid <= 1'b0;
                @(posedge clk);
                ->data_transmitted;
            end

            i_rx_data_valid <= 1'b1;

        
            i_rx_sync_hdr <= tx_data.sync_hdr;
            i_rx_data <= tx_data.data_word[i];
            @(posedge clk);
            ->data_transmitted;

            if (cycle_cntr > 0)
                cycle_cntr--;
        end 

    endtask : drive_data

    task read_data();
        logic [DUT_DATA_WIDTH-1:0] rx_data, ref_data_packed;
        logic ref_data_unpacked [DUT_DATA_WIDTH-1:0];

        // Remove 32 bits from the back of the reference model
        if (ref_model.size >= 32) begin
            for(int i = 0; i < 32; i++) begin
                ref_data_unpacked[i] = ref_model.pop_back();
            end

            // Pack the 32 bits into a vector for comparison
            ref_data_packed = {>>{ref_data_unpacked}};
            rx_data = o_tx_data;

            // Compare the current output data to the reference/expected data 
            assert(ref_data_packed == rx_data) begin
                $display("MATCH: RX Data: %0h == Ref Data: %0h", rx_data, ref_data_packed);
                scb.record_success();
            end else begin 
                $display("MISMATCH: RX Data: %0h != Ref Data: %0h", rx_data, ref_data_packed);
                scb.record_failure();
            end
        end

    endtask : read_data

    /* Clock Instantiation */

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    /* Stimulus */
    initial begin

        // Initial signal values
        i_rx_data_valid = 1'b0;
        i_rx_sync_hdr = 2'b0;
        i_rx_data = 32'b0;

        // Initial Reset for design
        reset_n = 1'b0; #10;
        @(posedge clk)
        reset_n = 1'b1; 

        fork 
            begin
                encoded_data_t tx_data_word; 
                repeat(1000) begin        
                    tx_data_word = generate_data();
                    drive_data(tx_data_word);
                end
            end
            begin
                while(1) begin
                    @(data_transmitted);
                    read_data();
                end
            end
        join_any

        #100;

        scb.print_summary();

        $finish;
    end

endmodule : gearbox_top