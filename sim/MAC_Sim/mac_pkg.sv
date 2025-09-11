
package mac_pkg;

    /* Parameters */
    localparam DATA_WIDTH = 32;
    localparam CTRL_WIDTH = 4;

    /* Data Queues */
    logic [DATA_WIDTH-1:0] tx_mac_data_queue[$];

    function void generate_tx_data_stream(ref logic [DATA_WIDTH-1:0] queue[$]);

        int num_data_words = $urandom_range(50, 100);
        $display("Number of data words to output: %0d", num_data_words);

        repeat(num_data_words) begin
            queue.push_front($random);
        end

        $display("Queue full");

    endfunction : generate_tx_data_stream

endpackage : mac_pkg