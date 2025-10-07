# Generate a 322.265625MHz clock signal
create_clock -period 3.103 -name tx_clk [get_ports i_tx_clk]
create_clock -period 3.103 -name rx_clk [get_ports i_rx_clk]