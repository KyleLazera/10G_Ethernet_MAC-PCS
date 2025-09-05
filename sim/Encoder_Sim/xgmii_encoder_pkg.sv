
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

    // Allows testing data to be held in a queue
    typedef struct packed {
        logic [63:0] data_word;
        logic [7:0]  ctrl_word;
    } xgmii_frame_t;

    /************************* Golden Model *************************/

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

    /* This function is used to generate a 32 bit word and 4 bit associated
     * control word based on the block type field input. It outputs the 
     * encapsulated packet containing both.
     */
    function xgmii_frame_t generate_word(logic [7:0] block_type_field);
        
        xgmii_frame_t data;
        int i;

        data.ctrl_word = 8'b0;
        
        for(i = 0; i < 8; i++) begin
            case(block_type_field)
                BLOCK_CTRL: begin
                    data.data_word[((i+1)*8)-1 -: 8] = XGMII_IDLE;
                    data.ctrl_word = 8'hFF;
                end
                BLOCK_START_0 : begin
                    if (i == 0)
                       data.data_word[7:0] = XGMII_START;
                    else 
                        data.data_word[((i+1)*8)-1 -: 8] = $urandom_range(0, 255);
                    data.ctrl_word = 8'h01;
                end
                BLOCK_START_4: begin
                    if(i == 4)
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_START;
                    else if (i < 4)
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_IDLE;
                    else 
                        data.data_word[((i+1)*8)-1 -: 8] = $urandom_range(0, 255);
                    data.ctrl_word = 8'b00011111;                        
                end
                BLOCK_TERM_0: begin
                    if (i == 0)
                       data.data_word[((i+1)*8)-1 -: 8] = XGMII_TERM;
                    else 
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_IDLE;
                    data.ctrl_word = 8'hFF;                    
                end
                BLOCK_TERM_1: begin
                    if(i == 1)
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_TERM;
                    else if (i < 1)
                        data.data_word[((i+1)*8)-1 -: 8] = $urandom_range(0, 255);
                    else 
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_IDLE;
                    data.ctrl_word = 8'b11111110;                    
                end
                BLOCK_TERM_2: begin
                    if(i == 2)
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_TERM;                        
                    else if(i < 2)
                        data.data_word[((i+1)*8)-1 -: 8] = $urandom_range(0, 255);
                    else 
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_IDLE;
                    data.ctrl_word = 8'b11111100;                    
                end
                BLOCK_TERM_3: begin
                    if(i == 3)
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_TERM;                        
                    else if(i < 3)
                        data.data_word[((i+1)*8)-1 -: 8] = $urandom_range(0, 255);
                    else 
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_IDLE;
                    data.ctrl_word = 8'b11111000;                    
                end
                BLOCK_TERM_4: begin
                    if(i == 4)
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_TERM;                        
                    else if(i < 4)
                        data.data_word[((i+1)*8)-1 -: 8] = $urandom_range(0, 255);
                    else 
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_IDLE;
                    data.ctrl_word = 8'b11110000;                    
                end
                BLOCK_TERM_5: begin
                    if(i == 5)
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_TERM;                        
                    else if(i < 5)
                        data.data_word[((i+1)*8)-1 -: 8] = $urandom_range(0, 255);
                    else 
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_IDLE;
                    data.ctrl_word = 8'b11100000;                    
                end
                BLOCK_TERM_6: begin
                    if(i == 6)
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_TERM;                        
                    else if(i < 6)
                        data.data_word[((i+1)*8)-1 -: 8] = $urandom_range(0, 255);
                    else 
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_IDLE;
                    data.ctrl_word = 8'b11000000;                    
                end
                BLOCK_TERM_7: begin
                    if(i == 7)
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_TERM;                        
                    else if(i < 7)
                        data.data_word[((i+1)*8)-1 -: 8] = $urandom_range(0, 255);
                    else 
                        data.data_word[((i+1)*8)-1 -: 8] = XGMII_IDLE;
                    data.ctrl_word = 8'b10000000;  
                end     
                default: 
                    data.data_word[((i+1)*8)-1 -: 8] = $urandom_range(0, 255);          
            endcase
        end

        return data;

    endfunction : generate_word

    /* This function is used to generate a full frame and store it in a queue based on the arguments
     * specified.
     * 
     * Args: 
     *      start_type: Lane to start in
     *      term_type: Lane to end in
     *      tx_queue: Queue to store the data in 
     */
    function void generate_frame(logic [7:0] start_type, logic [7:0] term_type, ref xgmii_frame_t tx_queue[$]);
        int i;
        int num_data_words, num_idle_words;

        num_data_words = $urandom_range(50, 100);
        num_idle_words = $urandom_range(5, 10);

        // Queue Start Frame
        tx_queue.push_back(generate_word(start_type));
        
        // Queue randomized number of data frames
        for(i = 0; i < num_data_words; i++)
            tx_queue.push_back(generate_word(8'h00));
        
        // Queue termination type
        tx_queue.push_back(generate_word(term_type));     

    endfunction : generate_frame

    /************************* Test Cases *************************/

    ////////////////////////////////////////////////////////////////////
    // Sanity test is used to test basic functionality of the DUT by  
    // sending the following frames:
    //  1) Start Condition lane 0 & 4
    //  2) Data Frames
    //  3) Terminate Lane 0 - 7
    //  4) Idle frames
    /////////////////////////////////////////////////////////////////////
    function void sanity_test(output xgmii_frame_t tx_queue[$]);

        // Queue random number of IDLE frames
        for(int i = 0; i < $urandom_range(20, 40); i++)
            tx_queue.push_back(generate_word(BLOCK_CTRL));  

        /* Start Lane 4 and terminate in lane 0 */
        generate_frame(BLOCK_START_4, BLOCK_TERM_0, tx_queue);
        /* Start Lane 0 and terminate in lane 0 */
        generate_frame(BLOCK_START_0, BLOCK_TERM_0, tx_queue);
        
        /* Start Lane 4 and terminate in lane 1 */
        generate_frame(BLOCK_START_4, BLOCK_TERM_1, tx_queue);
        /* Start Lane 0 and terminate in lane 1 */
        generate_frame(BLOCK_START_0, BLOCK_TERM_1, tx_queue);
        
        /* Start Lane 4 and terminate in lane 2 */
        generate_frame(BLOCK_START_4, BLOCK_TERM_2, tx_queue);
        /* Start Lane 0 and terminate in lane 2 */
        generate_frame(BLOCK_START_0, BLOCK_TERM_2, tx_queue);
        
        /* Start Lane 4 and terminate in lane 3 */
        generate_frame(BLOCK_START_4, BLOCK_TERM_3, tx_queue);
        /* Start Lane 0 and terminate in lane 3 */
        generate_frame(BLOCK_START_0, BLOCK_TERM_3, tx_queue);
        
        /* Start Lane 4 and terminate in lane 4 */
        generate_frame(BLOCK_START_4, BLOCK_TERM_4, tx_queue);
        /* Start Lane 0 and terminate in lane 4 */
        generate_frame(BLOCK_START_0, BLOCK_TERM_4, tx_queue);
        
        /* Start Lane 4 and terminate in lane 5 */
        generate_frame(BLOCK_START_4, BLOCK_TERM_5, tx_queue);
        /* Start Lane 0 and terminate in lane 5 */
        generate_frame(BLOCK_START_0, BLOCK_TERM_5, tx_queue);
        
        /* Start Lane 4 and terminate in lane 6 */
        generate_frame(BLOCK_START_4, BLOCK_TERM_6, tx_queue);
        /* Start Lane 0 and terminate in lane 6 */
        generate_frame(BLOCK_START_0, BLOCK_TERM_6, tx_queue);
        
        /* Start Lane 4 and terminate in lane 7 */
        generate_frame(BLOCK_START_4, BLOCK_TERM_7, tx_queue);
        /* Start Lane 0 and terminate in lane 7 */
        generate_frame(BLOCK_START_0, BLOCK_TERM_7, tx_queue);
                

    endfunction : sanity_test

    function void fuzz_test(output xgmii_frame_t tx_queue[$]);

        int start_condition_rand, stop_condition_rand;
        logic [7:0] start_block, term_block;

        repeat(100) begin
            // Randomly select the position to generate a start condition
            start_condition_rand = $urandom_range(0,1);

            case(start_condition_rand)
                0: start_block = BLOCK_START_0;
                1: start_block = BLOCK_START_4;
            endcase

            // Randomize teh terminate position
            stop_condition_rand = $urandom_range(0,7);

            case(stop_condition_rand)
                0: term_block = BLOCK_TERM_0;
                1: term_block = BLOCK_TERM_1;
                2: term_block = BLOCK_TERM_2;
                3: term_block = BLOCK_TERM_3;
                4: term_block = BLOCK_TERM_4;
                5: term_block = BLOCK_TERM_5;
                6: term_block = BLOCK_TERM_6;
                7: term_block = BLOCK_TERM_7;
            endcase

            // Generate the frame with teh randomized conditions
            generate_frame(start_block, term_block, tx_queue);
        end

    endfunction : fuzz_test


endpackage : xgmii_encoder_pkg