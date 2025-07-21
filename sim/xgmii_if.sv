
interface xgmii_if
(
    input i_clk,
    input i_reset_n
);

    localparam DATA_WIDTH = 32;
    localparam CTRL_WIDTH = 4;
    localparam HDR_WIDTH = 2;

    /* MAC to PCS Interface */
    logic [DATA_WIDTH-1:0] i_xgmii_txd;
    logic [CTRL_WIDTH-1:0] i_xgmii_txc;
    logic i_xgmii_valid;
    logic o_xgmii_pause;

    /* 64b/66b Encoder to Scrambler Interface */
    logic i_scrambler_trdy;
    logic o_encoded_data_valid;
    logic [DATA_WIDTH-1:0] o_encoded_data;
    logic [HDR_WIDTH-1:0] o_sync_hdr;
    logic o_encoding_err;


    task drive_xgmii_data(logic[63:0] input_word, logic[7:0] input_ctrl);

        int i;

        // Set data valid
        i_xgmii_valid <= 1'b1;
        //@(posedge i_clk);

        for(i = 0; i < 2; i++) begin
            //if (!o_xgmii_pause) begin
            // Drive data onto input signals 
            i_xgmii_txd <= input_word[(32*(i+1))-1 -: 32];
            i_xgmii_txc <= input_ctrl[(4*(i+1))-1 -: 4];
            //end
            @(posedge i_clk);
        end

    endtask : drive_xgmii_data




endinterface : xgmii_if