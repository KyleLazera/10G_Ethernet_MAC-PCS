
`include "lock_state_pkg.sv"

module lock_state_top;

    import lock_state_pkg::*;

    // ---------------- Signal Declarations ---------------- //
    logic clk;
    logic reset_n;
    logic [HDR_WIDTH-1:0] i_hdr;
    logic i_hdr_valid;
    logic o_slip;
    logic o_block_lock;

    // ---------------- DUT Instantiation ---------------- //
    lock_state #(
        .HDR_WIDTH(HDR_WIDTH)
    ) DUT (
        .i_clk(clk),
        .i_reset_n(reset_n),
        .i_hdr(i_hdr),
        .i_hdr_valid(i_hdr_valid),
        .o_slip(o_slip),
        .o_block_lock(o_block_lock)
    );

    // ---------------- Clock Instantiation ---------------- // 
    always #10 clk = ~clk;
    initial begin
        clk = 1'b0;
    end 

    //TODO: add more variablitity in the i_hdr_valid value
    task drive_data(input logic [HDR_WIDTH-1:0] header);        
        i_hdr <= header;
        i_hdr_valid <= 1'b1;
    endtask : drive_data

    task read_data(output logic slip, output logic block_lock);
        slip = o_slip;
        block_lock = o_block_lock;       
    endtask : read_data

    task validate_lock_state(int iterations);
        logic [HDR_WIDTH-1:0] header;
        logic slip, block_lock;
        logic ref_slip, ref_block_lock;

        repeat(iterations) begin
            header = generate_header();
            drive_data(header);
            @(posedge clk);

            fork
                read_data(slip, block_lock);
                golden_model(clk, i_hdr_valid, i_hdr, ref_slip, ref_block_lock);
            join_any

            validate_slip(ref_slip, slip);
            validate_block_lock(ref_block_lock, block_lock);
        end

    endtask : validate_lock_state

    // ---------------- Stimulus/Test ---------------- //
    initial begin
        i_hdr       = '0;
        i_hdr_valid = '0;
        
        // Initial Reset for design
        reset_n = 1'b0;
        @(posedge clk);
        reset_n <= 1'b1; 

        validate_lock_state(10);

        #100;
        $finish;

    end




endmodule : lock_state_top