
//TODO: Add support for other XGMII encoded starts

package xgmii_encoder_pkg;

    /* XGMII Coded Signals */
    localparam XGMII_IDLE   = 8'h07,
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


    /* This function is used to encode a 64 bit word using the 64b/66b encoding procedure 
     * outlined in IEEE 802.3-2012 Section 49.2. It takes in a 64 bit word, determines the 
     * block type for the word along with the synchronous header, and returns the encoded
     * data.
     */
    function automatic logic[65:0] encode_data(logic[63:0] raw_data, logic [7:0] ctrl_data);

        logic[63:0] encoded_word;
        logic[1:0] encoded_hdr = 2'b10;

        for(int i = 0; i < 8; i++) begin
            if (ctrl_data[i]) begin
                case(raw_data[((i+1)*8)-1 -: 8])
                    XGMII_IDLE: encoded_word[((i+1)*8)-2 -: 7] = CTRL_IDLE;
                    XGMII_START: begin
                        // If start is in position 0, set block type field to 0x78
                        if (i == 0) begin
                            encoded_word[7:0] = BLOCK_START_0;
                        end 
                        // If the start is in position 4, set block type field to 0x33
                        else if(i == 4) begin
                            encoded_word[7:0] = BLOCK_START_4;
                        end
                    end
                    XGMII_TERM: begin
                        // If the block is a terminate, set block type depending on which lane it is
                        case(i)
                            0: encoded_word[7:0] = BLOCK_TERM_0;
                            1: encoded_word[7:0] = BLOCK_TERM_1;
                            2: encoded_word[7:0] = BLOCK_TERM_2;
                            3: encoded_word[7:0] = BLOCK_TERM_3;
                            4: encoded_word[7:0] = BLOCK_TERM_4;
                            5: encoded_word[7:0] = BLOCK_TERM_5;    
                            6: encoded_word[7:0] = BLOCK_TERM_6;
                            7: encoded_word[7:0] = BLOCK_TERM_7;                                                                                  
                        endcase
                    end
                    XGMII_ERROR: encoded_word[((i+1)*8)-2 -: 7] = CTRL_ERROR;                    
                endcase
            end else begin
                encoded_word[((i+1)*8)-1 -: 8] = raw_data[((i+1)*8)-1 -: 8];
            end
        end

        // Append the block type field if teh control bits were all idle
        if (encoded_word[55:0] == 56'h0) begin
            encoded_word = (encoded_word << 8) | 56'h1E;
        end
        // If all the control bits were set to 0, this indicates a data frame
        else if (|ctrl_data == 0) begin
            encoded_word = raw_data;
            encoded_hdr = 2'b01;
        end

        // Concatenate header & encoded data
        return {encoded_hdr, encoded_word};

    endfunction : encode_data


endpackage : xgmii_encoder_pkg