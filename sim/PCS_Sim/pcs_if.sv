
interface pcs_if
(
    input i_clk,
    input i_reset_n
);

    localparam DATA_WIDTH = 32;
    localparam CTRL_WIDTH = 4;

    /* MAC to PCS Interface */
    logic [DATA_WIDTH-1:0] i_xgmii_txd;
    logic [CTRL_WIDTH-1:0] i_xgmii_txc;
    logic i_xgmii_valid;
    logic o_xgmii_pause;

    /* PCS Output to GTY Transciever*/
    logic [DATA_WIDTH-1:0] pcs_tx_gearbox_data;


    /* Task used to drive Data to the PCS via XGMII Interface */
    task drive_xgmii_data(logic[63:0] input_word, logic[7:0] input_ctrl);
        int i;

        if (o_xgmii_pause) begin
            i_xgmii_valid <= 1'b0;
            @(posedge i_clk);
        end else begin
            for(i = 0; i < 2; i++) begin
                i_xgmii_valid <= 1'b1;
                i_xgmii_txd   <= input_word[(32*(i+1))-1 -: 32];
                i_xgmii_txc   <= input_ctrl[(4*(i+1))-1 -: 4];
                @(posedge i_clk);
            end
        end

    endtask

    task sample_gty_tx_data(output logic [DATA_WIDTH-1:0] gty_tx_data);
        gty_tx_data = pcs_tx_gearbox_data;
        @(posedge i_clk);
    endtask : sample_gty_tx_data


endinterface : pcs_if