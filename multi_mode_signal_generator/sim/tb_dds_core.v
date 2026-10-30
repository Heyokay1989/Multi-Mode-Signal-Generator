`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/14 23:48:56
// Design Name: 
// Module Name: tb_dds_core
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module tb_dds_core;

    reg         clk;
    reg         rst_n;
    reg  [1:0]  wave_sel;
    reg  [31:0] ftw;
    reg         ftw_valid;
    wire [11:0] dds_out;

    // ============================================================
    // 分层引用：直接从 dds_core 内部抓 4 个 ROM 的输出
    // 它们一直在并行变化，与 wave_sel 无关
    // ============================================================
    wire [11:0] sin_wave_viz    = dut.sin_d;
    wire [11:0] square_wave_viz = dut.square_d;
    wire [11:0] tri_wave_viz    = dut.tri_d;
    wire [11:0] saw_wave_viz    = dut.saw_d;

    // 100MHz 时钟生成
    initial clk = 0;
    always #5 clk = ~clk;

    // 例化 DDS 核心模块
    dds_core #(
        .PHASE_W (32),
        .ADDR_W  (10),
        .DATA_W  (12)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .wave_sel  (wave_sel),
        .ftw       (ftw),
        .ftw_valid (ftw_valid),
        .dds_out   (dds_out)
    );

    // 任务：给一次 ftw_valid 脉冲
    task set_ftw(input [31:0] val);
        begin
            @(posedge clk);
            ftw       <= val;
            ftw_valid <= 1'b1;
            @(posedge clk);
            ftw_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

       initial begin
        rst_n     = 0;
        wave_sel  = 2'd0;
        ftw       = 32'd0;
        ftw_valid = 1'b0;

        #200;
        rst_n = 1;
        #100;

        set_ftw(32'd42949);   // ~1kHz

        // 每 2ms 切换一次 wave_sel
        forever begin
            wave_sel = 2'd0;  #2000000;  // 0~2ms  正弦
            wave_sel = 2'd1;  #2000000;  // 2~4ms  方波
            wave_sel = 2'd2;  #2000000;  // 4~6ms  三角
            wave_sel = 2'd3;  #2000000;  // 6~8ms  锯齿
        end
    end
endmodule
