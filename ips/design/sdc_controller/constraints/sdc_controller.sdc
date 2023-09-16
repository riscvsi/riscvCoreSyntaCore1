create_clock -name {clk} -period 50.000 -waveform { 0.000 4.000 } [list  [get_ports {wb_clk_i}]]
