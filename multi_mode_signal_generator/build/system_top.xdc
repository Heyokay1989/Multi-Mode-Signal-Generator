create_clock -period 20.000 -name clk_50M [get_ports clk_50M]

# 时钟引脚
set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS15} [get_ports clk_50M]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_50M]
# 复位引脚
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS15} [get_ports rst_n]

# UART 接收引脚
set_property -dict {PACKAGE_PIN E14 IOSTANDARD LVCMOS33} [get_ports uart_rx]
set_false_path -from [get_ports uart_rx]

# 按键引脚
set_property -dict {PACKAGE_PIN T4 IOSTANDARD LVCMOS15} [get_ports {key[0]}]
set_property -dict {PACKAGE_PIN T3 IOSTANDARD LVCMOS15} [get_ports {key[1]}]
set_property -dict {PACKAGE_PIN R6 IOSTANDARD LVCMOS15} [get_ports {key[2]}]
set_property -dict {PACKAGE_PIN T6 IOSTANDARD LVCMOS15} [get_ports {key[3]}]

# uart_txd
set_property -dict {PACKAGE_PIN D17 IOSTANDARD LVCMOS33} [get_ports uart_txd]

