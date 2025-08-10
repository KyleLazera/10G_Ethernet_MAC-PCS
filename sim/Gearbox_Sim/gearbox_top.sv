
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

    /* Signal Declarations */
    logic clk;
    logic reset_n;
    logic [DUT_DATA_WIDTH-1:0] data_in;
    logic data_valid;
    logic [1:0] sync_hdr;
    logic [DUT_DATA_WIDTH-1:0] data_out;
    logic gearbox_pause;

    /* Class Instantiations */
    scoreboard_base scb = new();

    /* DUT Instantiation */
    gearbox #(.DATA_WIDTH(DUT_DATA_WIDTH)) DUT(
        .i_clk(clk),
        .i_reset_n(reset_n),
        .i_data(data_in),
        .i_data_valid(data_valid),
        .i_hdr(sync_hdr),
        .o_data(data_out),
        .o_gearbox_pause(gearbox_pause)
    );

    /* Drive/Read Stimulus Tasks */
    task drive_data(encoded_data_t tx_data);

        // If gearbox_pause signal is high, wait for it to go low
        if (gearbox_pause) begin
            data_valid <= 1'b0;
            @(posedge clk);
            ->data_transmitted;
        end 

        data_valid <= 1'b1;

        foreach(tx_data.data_word[i]) begin
            sync_hdr <= tx_data.sync_hdr;
            data_in <= tx_data.data_word[i];
            @(posedge clk);
            ->data_transmitted;
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
            rx_data = data_out;

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
        data_valid = 1'b0;
        sync_hdr = 2'b0;
        data_in = 32'b0;

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