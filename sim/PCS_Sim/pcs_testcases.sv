`include "pcs_pkg.sv"
`include "pcs_if.sv"
`include "../Encoder_Sim/xgmii_encoder_pkg.sv"

/*
 * This package holds teh different test cases developed to test the 
 * PCS. 
 */

package pcs_testcases;

    import pcs_pkg::*;
    import xgmii_encoder_pkg::*;

    /* Synchronization Events */
    event data_transmitted;

    // Store the type of the virtual interface
    typedef virtual pcs_if pcs_vif;

    task automatic test_sanity(pcs_vif pcs);
        xgmii_frame_t tx_queue[$];

        sanity_test(tx_queue);

        fork
            // Transmission thread
            begin
                foreach (tx_queue[i]) begin
                    xgmii_frame_t tx_data = tx_queue.pop_back();

                    pcs.drive_xgmii_data(tx_data.data_word, tx_data.ctrl_word);
                    pcs_golden_model(tx_data);
                    ->data_transmitted;
                end
            end

            // Reception thread
            begin
                logic [DATA_WIDTH-1:0] sampled_data;

                // Implement a 2 clock cycle latency delay at start
                @(data_transmitted);
                @(posedge pcs.i_clk);
                //@(posedge pcs.i_clk);

                pcs.sample_gty_tx_data(sampled_data);
                validate_data(sampled_data);

                while (1) begin
                    @(data_transmitted);
                    pcs.sample_gty_tx_data(sampled_data);
                    validate_data(sampled_data);
                end
            end
        join_any
    endtask

endpackage : pcs_testcases

