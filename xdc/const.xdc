# Generate a 322.265625MHz clock signal
create_clock -period 3.103 -name gty_tx_usr_clk [get_ports gty_tx_usr_clk]
create_clock -period 3.103 -name gty_rx_usr_clk [get_ports gty_rx_usr_clk]