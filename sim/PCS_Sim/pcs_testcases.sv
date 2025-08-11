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
                    pcs.drive_xgmii_data(tx_queue[i].data_word, tx_queue[i].ctrl_word, data_transmitted);
                    pcs_golden_model(tx_queue[i]);
                end
            end

            // Reception thread
            begin
                logic [DATA_WIDTH-1:0] sampled_data;
                int tx_cntr = 0;

                while (1) begin
                    @(data_transmitted);
                    pcs.sample_gty_tx_data(sampled_data);
                    // The PCS does not output a data valid signal, therefore, to ensure we are validating
                    // correct data, we need to account for the latency from the time data is transmitted
                    // into the PCS to the time data is transmitted out of the PCS. To do this, we ignore
                    // the first 2 transmissions.
                    if (tx_cntr > 2)
                        validate_data(sampled_data);
                    tx_cntr++;
                end
            end
        join_any

        scb.print_summary();
    endtask

endpackage : pcs_testcases

