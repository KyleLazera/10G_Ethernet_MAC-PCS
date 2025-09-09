
interface pcs_if
(
    input i_clk,
    input i_reset_n
);

    localparam DATA_WIDTH = 32;
    localparam CTRL_WIDTH = 4;

    /* -------------------- TX Data Path -------------------- */

    /* MAC to PCS Interface */
    logic [DATA_WIDTH-1:0] i_xgmii_txd;
    logic [CTRL_WIDTH-1:0] i_xgmii_txc;
    logic i_xgmii_valid;
    logic o_xgmii_pause;

    /* PCS Output to GTY Transciever*/
    logic [DATA_WIDTH-1:0] pcs_tx_gearbox_data;

    /* -------------------- RX Data Path -------------------- */

    /* MAC to PCS Interface */
    logic [DATA_WIDTH-1:0] o_xgmii_rxd;
    logic [CTRL_WIDTH-1:0] o_xgmii_rxc;
    logic o_xgmii_rvalid;

    /* PCS Input from GTY Transciever*/
    logic [DATA_WIDTH-1:0] pcs_rx_gearbox_data;


    /* Task used to drive Data to the PCS via XGMII Interface */
    task drive_xgmii_data(logic[63:0] input_word, logic[7:0] input_ctrl, ref event data_transmitted);
        int i;

        for (i = 0; i < 2; i++) begin
            
            // If pause is high, wait before sending this chunk
            if (o_xgmii_pause) begin
                i_xgmii_valid <= 1'b0;   // Deassert valid
                @(posedge i_clk);
                -> data_transmitted;     // Signal that we "handled" this cycle
            end
    
            // Send the chunk
            i_xgmii_valid <= 1'b1;
            i_xgmii_txd   <= input_word[(32*(i+1))-1 -: 32];
            i_xgmii_txc   <= input_ctrl[(4*(i+1))-1 -: 4];
            @(posedge i_clk);
            -> data_transmitted;
    
        end

    endtask

    /* Sample data from the GTY Transciever interface */
    task sample_gty_tx_data(output logic [DATA_WIDTH-1:0] gty_tx_data);
        gty_tx_data = pcs_tx_gearbox_data;
        @(posedge i_clk);
    endtask : sample_gty_tx_data

    /* Task used to sample the output XGMII data from rx-data path */
    task sample_xgmii_data(output logic [DATA_WIDTH-1:0] xgmii_rxd, output logic [CTRL_WIDTH-1:0] xgmii_ctrl, output logic xgmii_rxd_valid);

        xgmii_rxd = o_xgmii_rxd;
        xgmii_ctrl = o_xgmii_rxc;
        xgmii_rxd_valid = o_xgmii_rvalid;

    endtask : sample_xgmii_data


endinterface : pcs_if