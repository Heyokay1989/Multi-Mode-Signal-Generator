# ==========================================
# 自动重建 Vivado 工程脚本 
# ==========================================

# 自动获取当前脚本所在的绝对路径，并推算出工程的根目录
set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file dirname $script_dir]

# 1. 设置工程名和器件型号
set proj_name "multi_mode_signal_generator"
set part_name "xc7a35tfgg484-2"

# 2. 在当前目录下创建工程
create_project -force $proj_name $repo_root/$proj_name -part $part_name

# 3. 添加源码 (利用绝对路径自动抓取)
add_files -norecurse [glob -nocomplain $repo_root/src/*.v]
add_files -fileset sim_1 -norecurse [glob -nocomplain $repo_root/sim/*.v]
add_files -fileset constrs_1 -norecurse $repo_root/build/system_top.xdc
add_files -norecurse [glob -nocomplain $repo_root/data/*.coe]

# 4. 设置顶层模块
set_property top system_top [current_fileset]

# ==========================================
# 5. 自动重建并配置所有 IP 核
# ==========================================

# 5.1 PLL 锁相环
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clk_wiz_0
set_property -dict [list CONFIG.PRIM_IN_FREQ {50.000} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} CONFIG.RESET_TYPE {ACTIVE_HIGH}] [get_ips clk_wiz_0]

# 5.2 ROM 核 (使用绝对路径绑定 COE)
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name rom_sin
set_property -dict [list CONFIG.Memory_Type {Single_Port_ROM} CONFIG.Write_Width_A {12} CONFIG.Write_Depth_A {1024} CONFIG.Enable_A {Always_Enabled} CONFIG.Register_PortA_Output_of_Memory_Primitives {false} CONFIG.Load_Init_File {true} CONFIG.Coe_File [file join $repo_root data sin.coe]] [get_ips rom_sin]

create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name rom_square
set_property -dict [list CONFIG.Memory_Type {Single_Port_ROM} CONFIG.Write_Width_A {12} CONFIG.Write_Depth_A {1024} CONFIG.Enable_A {Always_Enabled} CONFIG.Register_PortA_Output_of_Memory_Primitives {false} CONFIG.Load_Init_File {true} CONFIG.Coe_File [file join $repo_root data square.coe]] [get_ips rom_square]

create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name rom_tri
set_property -dict [list CONFIG.Memory_Type {Single_Port_ROM} CONFIG.Write_Width_A {12} CONFIG.Write_Depth_A {1024} CONFIG.Enable_A {Always_Enabled} CONFIG.Register_PortA_Output_of_Memory_Primitives {false} CONFIG.Load_Init_File {true} CONFIG.Coe_File [file join $repo_root data tri.coe]] [get_ips rom_tri]

create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name rom_saw
set_property -dict [list CONFIG.Memory_Type {Single_Port_ROM} CONFIG.Write_Width_A {12} CONFIG.Write_Depth_A {1024} CONFIG.Enable_A {Always_Enabled} CONFIG.Register_PortA_Output_of_Memory_Primitives {false} CONFIG.Load_Init_File {true} CONFIG.Coe_File [file join $repo_root data saw.coe]] [get_ips rom_saw]

# 5.3 AWG 双口 RAM
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name awg_ram
set_property -dict [list CONFIG.Memory_Type {True_Dual_Port_RAM} CONFIG.Write_Width_A {12} CONFIG.Write_Depth_A {1024} CONFIG.Write_Width_B {12}  CONFIG.Operating_Mode_A {WRITE_FIRST} CONFIG.Operating_Mode_B {READ_FIRST} CONFIG.Enable_A {Always_Enabled} CONFIG.Enable_B {Always_Enabled}] [get_ips awg_ram]

# 5.4 ILA
create_ip -name ila -vendor xilinx.com -library ip -module_name ila_0
set_property -dict [list CONFIG.C_NUM_OF_PROBES {3} CONFIG.C_PROBE0_WIDTH {12} CONFIG.C_PROBE1_WIDTH {2} CONFIG.C_PROBE2_WIDTH {3}] [get_ips ila_0]

# 6. 生成所有 IP 的输出产物
update_compile_order -fileset sources_1

puts "========================================="
puts "Project Rebuild Success!"
puts "========================================="