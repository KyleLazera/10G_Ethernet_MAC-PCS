
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

    task drive_data(ref lock_state_transaction_t data);        
        logic [HDR_WIDTH-1:0] header;
        header = generate_header();
        
        i_hdr <= header;
        i_hdr_valid <= ~i_hdr_valid;

        data.header = header;
        data.header_valid = ~i_hdr_valid;
    endtask : drive_data

    task read_data(ref lock_state_transaction_t data);
        data.slip = o_slip;
        data.block_lock = o_block_lock;      
    endtask : read_data

    task validate_lock_state(int iterations);
        lock_state_transaction_t lock_struct; 

        fork
            begin
                repeat(iterations) begin
                    drive_data(lock_struct);
                    @(posedge clk);
                    ->data_tx;
                    @(data_rx);
                end
            end
            begin
                repeat(iterations) begin
                    @(data_tx);
                    read_data(lock_struct);
                    sync_queue.push_front(lock_struct);
                    ->data_rx;
                end
            end
        join
    
        golden_model(clk);

    endtask : validate_lock_state

    // ---------------- Stimulus/Test ---------------- //
    initial begin
        i_hdr       = '0;
        i_hdr_valid = '0;
        
        // Initial Reset for design
        reset_n = 1'b0;
        @(posedge clk);
        reset_n <= 1'b1; 

        validate_lock_state(100);

        scb.print_summary();
        #100;
        $finish;

    end




endmodule : lock_state_top