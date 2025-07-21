
`include "xgmii_encoder_pkg.sv"
`include "xgmii_if.sv"

import xgmii_encoder_pkg::*;

module xgmii_encoder_top;

    /* Parameters */
    localparam DATA_WIDTH = 32;
    localparam CTRL_WIDTH = 4;
    localparam HDR_WIDTH = 2;

    /* Signal Descriptions */
    logic clk;
    logic i_reset_n;

    /* Interface declaration */
    xgmii_if xgmii(clk, i_reset_n) ;

    /* DUT Instantiation */
    xgmii_encoder#( 
        .DATA_WIDTH(DATA_WIDTH),
        .CTRL_WIDTH(CTRL_WIDTH),
        .HDR_WIDTH(HDR_WIDTH)
    )DUT(
        .i_clk(clk),
        .i_reset_n(i_reset_n),
        // XGMII Interface
        .i_xgmii_txd(xgmii.i_xgmii_txd),
        .i_xgmii_txc(xgmii.i_xgmii_txc),
        .i_xgmii_valid(xgmii.i_xgmii_valid),
        .o_xgmii_pause(xgmii.o_xgmii_pause),
        // Scrambler Interface/Encoder Output
        .i_scrambler_trdy(xgmii.i_scrambler_trdy),
        .o_encoded_data_valid(xgmii.o_encoded_data_valid),
        .o_encoded_data(xgmii.o_encoded_data),
        .o_sync_hdr(xgmii.o_sync_hdr),
        .o_encoding_err(xgmii.o_encoding_err)
    );

    /* Clock Instantiation */

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    /* Stimulus/Test */
    initial begin

        logic [63:0] data_word;
        logic [7:0] ctrl_word;
        logic [65:0] expected_data;

        // Initial Reset for design
        i_reset_n = 1'b0; #10;
        @(posedge clk)
        i_reset_n = 1'b1;

        /* Stimulus */

        /* Test 1: Start Condition - Lane 4 & Term Lane 0 */
        data_word = 64'h030201FB07070707;
        ctrl_word = 8'b00011111;
        expected_data = encode_data(data_word, ctrl_word);
        xgmii.drive_xgmii_data(data_word, ctrl_word);
        
        /*@(posedge clk);
        xgmii_txd  <= data_word[31:0]; 
        xgmii_ctrl <= ctrl_word[3:0];
        @(posedge clk);
        xgmii_txd  <= data_word[63:32];
        xgmii_ctrl <= ctrl_word[7:4];*/    

        // Data
        //@(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h04030201;
        xgmii.i_xgmii_txc <= 4'b0000;
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h08070605;
        xgmii.i_xgmii_txc <= 4'b0000;        

        // Term Lane 0
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h070707FD;
        xgmii.i_xgmii_txc <= 4'b1111; 
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h07070707;
        xgmii.i_xgmii_txc <= 4'b1111;    

        /* Test 2: Start Condition in Lane 0 & Term in Lane 1 */
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h0C0B0AFB;
        xgmii.i_xgmii_txc <= 4'b0001; 
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h20100E0D;
        xgmii.i_xgmii_txc <= 4'b0000;      

        // Data Frame
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h04030201;
        xgmii.i_xgmii_txc <= 4'b0000;
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h08070605;
        xgmii.i_xgmii_txc <= 4'b0000;   

        // Terminate in Lane 1
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h0707FDAA;
        xgmii.i_xgmii_txc <= 4'b1110; 
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h07070707;
        xgmii.i_xgmii_txc <= 4'b1111;  

        /* Test 3: Start Condition in Lane 0 & Term in Lane 4 */
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h0C0B0AFB;
        xgmii.i_xgmii_txc <= 4'b0001; 
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h20100E0D;
        xgmii.i_xgmii_txc <= 4'b0000;      

        // Test 5: Data Frame
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h04030201;
        xgmii.i_xgmii_txc <= 4'b0000;
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h08070605;
        xgmii.i_xgmii_txc <= 4'b0000;   

        // Test 6: Terminate in Lane 4
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'hDDCCBBAA;
        xgmii.i_xgmii_txc <= 4'b0000; 
        @(posedge clk);
        xgmii.i_xgmii_txd  <= 32'h070707FD;
        xgmii.i_xgmii_txc <= 4'b1111;          

        #100;
        $finish;

    end


endmodule : xgmii_encoder_top