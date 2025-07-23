
//TODO: Add support for other XGMII encoded starts

package xgmii_encoder_pkg;

    localparam CTRL_WIDTH = 8;
    localparam DATA_WIDTH = 64;

    /* XGMII Coded Signals */
    localparam XGMII_IDLE   = 8'h07,
               XGMII_LPI    = 8'h06,
               XGMII_START  = 8'hFB,
               XGMII_TERM   = 8'hFD,
               XGMII_ERROR  = 8'hFE,
               XGMII_SEQ_OS = 8'h9C,
               XGMII_RES_0  = 8'h1C,
               XGMII_RES_1  = 8'h3C,
               XGMII_RES_2  = 8'h7C,
               XGMII_RES_3  = 8'hBC,
               XGMII_RES_4  = 8'hDC,
               XGMII_RES_5  = 8'hF7,
               XGMII_SIG_OS = 8'h5C;

    /* 10G-BASER Control COdes */
    localparam CTRL_IDLE  = 7'h00,
               CTRL_LPI   = 7'h06,
               CTRL_ERROR = 7'h1E,
               CTRL_RES_0 = 7'h2D,
               CTRL_RES_1 = 7'h33,
               CTRL_RES_2 = 7'h4B,
               CTRL_RES_3 = 7'h55,
               CTRL_RES_4 = 7'h66,
               CTRL_RES_5 = 7'h78;

    localparam [3:0]
        O_SEQ_OS = 4'h0,
        O_SIG_OS = 4'hf;               

    /* 64b/66b Block Type Fields */
    localparam BLOCK_CTRL = 8'h1E,      
               BLOCK_OS_4 = 8'h2D,      
               BLOCK_START_4 = 8'h33,   
               BLOCK_START_4_OS = 8'h66,
               BLOCK_OS_0_4 = 8'h55,    
               BLOCK_START_0 = 8'h78,   
               BLOCK_OS_0 = 8'h4B,         
               BLOCK_TERM_0 = 8'h87,    
               BLOCK_TERM_1 = 8'h99,    
               BLOCK_TERM_2 = 8'hAA,    
               BLOCK_TERM_3 = 8'hB4,    
               BLOCK_TERM_4 = 8'hCC,    
               BLOCK_TERM_5 = 8'hD2,    
               BLOCK_TERM_6 = 8'hE1,    
               BLOCK_TERM_7 = 8'hFF; 

    typedef struct packed {
        logic [63:0] data_word;
        logic [7:0]  ctrl_word;
    } xgmii_frame_t;


    /* This function is used to encode a 64 bit word using the 64b/66b encoding procedure 
     * outlined in IEEE 802.3-2012 Section 49.2. It takes in a 64 bit word, determines the 
     * block type for the word along with the synchronous header, and returns the encoded
     * data.
     */
    function automatic logic[65:0] encode_data(logic[DATA_WIDTH-1:0] raw_data, logic [CTRL_WIDTH-1:0] ctrl_data);

        int i;
        logic[DATA_WIDTH*7/8-1:0] encoded_ctrl;
        logic [DATA_WIDTH-1:0] encoded_word;
        logic[1:0] encoded_hdr = 2'b10;

        for (i = 0; i < 8; i = i + 1) begin
            if (ctrl_data[i]) begin
                // control
                case (raw_data[8*i +: 8])
                    XGMII_IDLE: begin
                        encoded_ctrl[7*i +: 7] = CTRL_IDLE;
                    end
                    XGMII_LPI: begin
                        encoded_ctrl[7*i +: 7] = CTRL_LPI;
                    end
                    XGMII_ERROR: begin
                        encoded_ctrl[7*i +: 7] = CTRL_ERROR;
                    end
                    XGMII_RES_0: begin
                        encoded_ctrl[7*i +: 7] = CTRL_RES_0;
                    end
                    XGMII_RES_1: begin
                        encoded_ctrl[7*i +: 7] = CTRL_RES_1;
                    end
                    XGMII_RES_2: begin
                        encoded_ctrl[7*i +: 7] = CTRL_RES_2;
                    end
                    XGMII_RES_3: begin
                        encoded_ctrl[7*i +: 7] = CTRL_RES_3;
                    end
                    XGMII_RES_4: begin
                        encoded_ctrl[7*i +: 7] = CTRL_RES_4;
                    end
                    XGMII_RES_5: begin
                        encoded_ctrl[7*i +: 7] = CTRL_RES_5;
                    end
                    default: begin
                        encoded_ctrl[7*i +: 7] = CTRL_ERROR;
                    end
                endcase
            end else begin
                // data (always invalid as control)
                encoded_ctrl[7*i +: 7] = CTRL_ERROR;
            end
        end

        if (ctrl_data == 8'h00) begin
            encoded_word = raw_data;
            encoded_hdr = 2'b01;
        end else begin
            if (ctrl_data == 8'h1f && raw_data[39:32] == XGMII_SEQ_OS) begin
                // ordered set in lane 4
                encoded_word = {raw_data[63:40], O_SEQ_OS, encoded_ctrl[27:0], BLOCK_OS_4};
            end else if (ctrl_data == 8'h1f && raw_data[39:32] == XGMII_START) begin
                // start in lane 4
                encoded_word = {raw_data[63:40], 4'd0, encoded_ctrl[27:0], BLOCK_START_4};
            end else if (ctrl_data == 8'h11 && raw_data[7:0] == XGMII_SEQ_OS && raw_data[39:32] == XGMII_START) begin
                // ordered set in lane 0, start in lane 4
                encoded_word = {raw_data[63:40], 4'd0, O_SEQ_OS, raw_data[31:8], BLOCK_START_4_OS};
            end else if (ctrl_data == 8'h11 && raw_data[7:0] == XGMII_SEQ_OS && raw_data[39:32] == XGMII_SEQ_OS) begin
                // ordered set in lane 0 and lane 4
                encoded_word = {raw_data[63:40], O_SEQ_OS, O_SEQ_OS, raw_data[31:8], BLOCK_OS_4};
            end else if (ctrl_data == 8'h01 && raw_data[7:0] == XGMII_START) begin
                // start in lane 0
                encoded_word = {raw_data[63:8], BLOCK_START_0};
            end else if (ctrl_data == 8'hf1 && raw_data[7:0] == XGMII_SEQ_OS) begin
                // ordered set in lane 0
                encoded_word = {encoded_ctrl[55:28], O_SEQ_OS, raw_data[31:8], BLOCK_OS_0};
            end else if (ctrl_data == 8'hff && raw_data[7:0] == XGMII_TERM) begin
                // terminate in lane 0
                encoded_word = {encoded_ctrl[55:7], 7'd0, BLOCK_TERM_0};
            end else if (ctrl_data == 8'hfe && raw_data[15:8] == XGMII_TERM) begin
                // terminate in lane 1
                encoded_word = {encoded_ctrl[55:14], 6'd0, raw_data[7:0], BLOCK_TERM_1};
            end else if (ctrl_data == 8'hfc && raw_data[23:16] == XGMII_TERM) begin
                // terminate in lane 2
                encoded_word = {encoded_ctrl[55:21], 5'd0, raw_data[15:0], BLOCK_TERM_2};
            end else if (ctrl_data == 8'hf8 && raw_data[31:24] == XGMII_TERM) begin
                // terminate in lane 3
                encoded_word = {encoded_ctrl[55:28], 4'd0, raw_data[23:0], BLOCK_TERM_3};
            end else if (ctrl_data == 8'hf0 && raw_data[39:32] == XGMII_TERM) begin
                // terminate in lane 4
                encoded_word = {encoded_ctrl[55:35], 3'd0, raw_data[31:0], BLOCK_TERM_4};
            end else if (ctrl_data == 8'he0 && raw_data[47:40] == XGMII_TERM) begin
                // terminate in lane 5
                encoded_word = {encoded_ctrl[55:42], 2'd0, raw_data[39:0], BLOCK_TERM_5};
            end else if (ctrl_data == 8'hc0 && raw_data[55:48] == XGMII_TERM) begin
                // terminate in lane 6
                encoded_word = {encoded_ctrl[55:49], 1'd0, raw_data[47:0], BLOCK_TERM_6};
            end else if (ctrl_data == 8'h80 && raw_data[63:56] == XGMII_TERM) begin
                // terminate in lane 7
                encoded_word = {raw_data[55:0], BLOCK_TERM_7};
            end else if (ctrl_data == 8'hff) begin
                // all control
                encoded_word = {encoded_ctrl, BLOCK_CTRL};
            end else begin
                // no corresponding block format
                encoded_word = {{8{CTRL_ERROR}}, BLOCK_CTRL};
            end
        end

        // Concatenate header & encoded data
        return {encoded_hdr, encoded_word};

    endfunction : encode_data


endpackage : xgmii_encoder_pkg