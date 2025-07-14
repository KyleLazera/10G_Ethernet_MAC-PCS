
module xgmii_encoder_top;

    /* Parameters */
    localparam DATA_WIDTH = 32;
    localparam CTRL_WIDTH = 4;
    localparam HDR_WIDTH = 2;

    /* Signal Descriptions */
    logic clk;
    logic i_reset_n;
    // XGMII Signals
    logic [DATA_WIDTH-1:0] xgmii_txd;
    logic [CTRL_WIDTH-1:0] xgmii_ctrl;
    logic xgmii_pause;
    // Encoder output signals
    logic [DATA_WIDTH-1:0] encoded_data;
    logic [HDR_WIDTH-1:0] header;
    logic encoding_err;


    /* DUT Instantiation */
    xgmii_encoder#( 
        .DATA_WIDTH(DATA_WIDTH),
        .CTRL_WIDTH(CTRL_WIDTH),
        .HDR_WIDTH(HDR_WIDTH)
    )DUT(
        .i_clk(clk),
        .i_reset_n(i_reset_n),
        // XGMII Interface
        .i_xgmii_txd(xgmii_txd),
        .i_xgmii_txc(xgmii_ctrl),
        .o_xgmii_pause(xgmii_pause),
        // Scrambler Interface/Encoder Output
        .o_encoded_data(encoded_data),
        .o_sync_hdr(header),
        .o_encoding_err(encoding_err)
    );

    /* Clock Instantiation */

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    /* Stimulus/Test */
    initial begin

        // Initial Reset for design
        i_reset_n = 1'b0; #10;
        @(posedge clk)
        i_reset_n = 1'b1;

        /* Stimulus */

        // Test 1: Idle Test Case 
        @(posedge clk);
        xgmii_txd  <= 32'h07070707; 
        xgmii_ctrl <= 4'b1111;

        // Test 2: Start Condition 
        @(posedge clk);
        xgmii_txd  <= 32'h030201FB;
        xgmii_ctrl <= 4'b0001;      

        // Test 3: Data Frame
        @(posedge clk);
        xgmii_txd  <= 32'h04030201;
        xgmii_ctrl <= 4'b0000;

        // Test 4: Terminate in lane 0 
        @(posedge clk);
        xgmii_txd  <= 32'h070707FD;
        xgmii_ctrl <= 4'b0001; 

        // Test 5: Terminate in lane 1 
        @(posedge clk);
        xgmii_txd  <= 32'h0707FD07;
        xgmii_ctrl <= 4'b0010; 

        // Test 6: Terminate in lane 2 
        @(posedge clk);
        xgmii_txd  <= 32'h07FD0707;
        xgmii_ctrl <= 4'b0100; 

        // Test 7: Terminate in lane 3 
        @(posedge clk);
        xgmii_txd  <= 32'hFD070707;
        xgmii_ctrl <= 4'b1000; 

        #100;
        $finish;

    end


endmodule : xgmii_encoder_top