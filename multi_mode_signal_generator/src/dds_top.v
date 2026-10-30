`timescale 1ns / 1ps

module dds_top(
    input clk,
    input rst_n,
    input uart_rx,
    input key1,
    input key2,
    input key3,
    input key4,
    input [2:0]mode_sel,
    output [11:0]dds_out,
    output [1:0]wave_sel_out,
    output ftw_valid_out
    );
   
    wire [1:0]wave_sel;  
    wire [31:0] ftw_normal;
    wire        ftw_valid_normal;
    wire [31:0] ftw_final;
    wire        ftw_valid_final;
    wire [31:0] lfsr_raw;
    wire lfsr_tick;
    wire [2:0] mode_sel_uart;
    wire       mode_valid_uart;
    wire [11:0] dds_out_raw; 
    wire        awg_wr_en;
    wire [9:0]  awg_wr_addr;
    wire [11:0] awg_wr_data;
    wire [11:0] awg_out;
    wire [11:0] dds_out_mux;
    
    reg [2:0] mode_sel_final;
    reg [2:0] mode_sel_d;
    wire mode_key_changed = (mode_sel != mode_sel_d);
    wire [6:0] mod_depth;
    wire [6:0] mod_freq;
    wire [31:0] ftw_cpfsk;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_sel_d     <= 3'd0;
            mode_sel_final <= 3'd0;
        end else begin
            mode_sel_d <= mode_sel;              // 记录上一拍的按键值
            if (mode_valid_uart)
                mode_sel_final <= mode_sel_uart; // 串口优先
            else if (mode_key_changed)
                mode_sel_final <= mode_sel;      // 按键值变化时才跟随
        end
    end
    
    control_top u_control_top (
    .clk       (clk),
    .rst_n     (rst_n),
    .uart_rx   (uart_rx),
    .key1      (key1),
    .key2      (key2),
    .key3      (key3),
    .key4      (1'b1),
    .wave_sel  (wave_sel),     
    .ftw       (ftw_normal),          
    .ftw_valid (ftw_valid_normal),
    .mode_sel_uart  (mode_sel_uart),      
    .mode_valid_uart(mode_valid_uart),
    .mod_depth (mod_depth),       
    .mod_freq  (mod_freq),
    .awg_wr_en      (awg_wr_en),       
    .awg_wr_addr    (awg_wr_addr),     
    .awg_wr_data    (awg_wr_data)               
    );
    
    
    dds_core u_dds_core(
    .clk      (clk),
    .rst_n    (rst_n),            
    .wave_sel (wave_sel),
    .ftw      (ftw_final),
    .ftw_valid(ftw_valid_final),
    .dds_out  (dds_out_raw)
    );
    
    assign wave_sel_out = wave_sel;
    assign ftw_valid_out = ftw_valid_final;
    
     
    lfsr u_lfsr (
        .clk      (clk),
        .rst_n    (rst_n),
        .rand_out (lfsr_raw)
    );
    
    
    lfsr_timer u_lfsr_timer (
        .clk       (clk),
        .rst_n     (rst_n),
        .lfsr_tick (lfsr_tick)
    );
    
    wire [31:0] lfsr_val  = {16'b0, lfsr_raw[15:0]};       // 0~65535
    wire [31:0] lfsr_fold = (lfsr_val >= 32'd42908) ? 
                            (lfsr_val - 32'd42908) : lfsr_val;
    wire [31:0] ftw_lfsr  = 32'd43 + lfsr_fold;
    
    
    wire [31:0] ftw_sweep;
    wire        sweep_tick;
    wire [31:0] ftw_fm;
    mode_mux u_mode_mux (
        .ftw_normal       (ftw_normal),
        .ftw_valid_normal (ftw_valid_normal),
        .ftw_lfsr         (ftw_lfsr),
        .lfsr_tick        (lfsr_tick),
        .ftw_sweep        (ftw_sweep),       
        .sweep_tick       (sweep_tick), 
        .mode_sel         (mode_sel_final),
        .ftw_out          (ftw_final),
        .ftw_fm           (ftw_fm),
        .ftw_cpfsk        (ftw_cpfsk),
        .ftw_valid_out    (ftw_valid_final)
    );
    
    //扫频
    sweep u_sweep (
    .clk        (clk),
    .rst_n      (rst_n),
    .ftw_out    (ftw_sweep),
    .sweep_tick (sweep_tick)
    );
    
    // FM调制
    fm_mod u_fm_mod (
    .clk      (clk),
    .rst_n    (rst_n),
    .ftw_base (ftw_normal),
    .mod_depth(mod_depth),
    .mod_freq (mod_freq),
    .ftw_fm   (ftw_fm)
    );
   
   //AM调制    
    am_mod u_am_mod (
    .clk            (clk),
    .rst_n          (rst_n),
    .dds_out        (dds_out_mux),
    .mode_sel       (mode_sel_final),
    .mod_depth      (mod_depth),
    .mod_freq       (mod_freq),
    .dds_out_final  (dds_out)
    );
    
    // AWG 模块
    awg u_awg (
    .clk       (clk),
    .rst_n     (rst_n),
    .ftw       (ftw_final),
    .ftw_valid (ftw_valid_final),
    .wr_en     (awg_wr_en),
    .wr_addr   (awg_wr_addr),
    .wr_data   (awg_wr_data),
    .dds_out   (awg_out)
    );
    assign dds_out_mux = (mode_sel_final == 3'd5) ? awg_out : dds_out_raw;
     
    // CPFSK 数字调制
    cpfsk u_cpfsk (
    .clk     (clk),
    .rst_n   (rst_n),
    .ftw_out (ftw_cpfsk)
    );
           
endmodule
