
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
    logic o_encoded_data_valid;
    logic [DATA_WIDTH-1:0] o_encoded_data;
    logic [HDR_WIDTH-1:0] o_sync_hdr;
    logic o_encoding_err;
    logic scrambler_rdy;


    /* Task used to drive Data to the PCS via XGMII Interface */
    task drive_xgmii_data(logic[63:0] input_word, logic[7:0] input_ctrl);
        int i;

        scrambler_rdy <= 1'b1;

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

    task sample_encoded_data(output logic [65:0] encoded_data);
        int i;

        // Wait for the data valid signal
        while (!o_encoded_data_valid) 
            @(posedge i_clk);  

        // Sample two 32-bit chunks
        for (i = 0; i < 2; i++) begin

            encoded_data[(32*(i+1))-1 -: 32] <= o_encoded_data;

            // Only assign sync header once (from the first word)
            if (i == 0)
                encoded_data[65:64] <= o_sync_hdr;

            @(posedge i_clk);
        end
    endtask : sample_encoded_data


endinterface : xgmii_if