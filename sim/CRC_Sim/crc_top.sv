`include "../Common/scoreboard_base.sv"


module crc_top;

    /* Parameters */
    localparam DATA_WIDTH = 32;
    localparam CRC_WIDTH = 32;

    /* Signal Descriptions */
    logic clk;
    logic i_reset_n;

    logic [DATA_WIDTH-1:0]  data_word;
    logic [CRC_WIDTH-1:0]   i_crc_state;
    logic                   crc_en;
    logic [DATA_WIDTH-1:0]  crc_out;
    logic [CRC_WIDTH-1:0]   o_crc_state;   

    /* Scoreboard Declaration */
    scoreboard_base scb = new();

    /* DUT Instantiation */
    crc32 #(
        .DATA_WIDTH(DATA_WIDTH),
        .CRC_WIDTH(CRC_WIDTH)
    ) DUT (
        .i_clk(clk),
        .i_reset_n(i_reset_n),

        .i_data(data_word),
        .i_crc_state(i_crc_state),
        .i_crc_en(crc_en),

        .o_crc(crc_out),
        .o_crc_state(o_crc_state)
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

        scb.print_summary();

        #100;
        $finish;

    end


endmodule : scrambler_top