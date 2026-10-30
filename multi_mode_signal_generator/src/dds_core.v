`timescale 1ns / 1ps

module dds_core #(
    parameter PHASE_W = 32,   // 相位累加器位宽
    parameter ADDR_W  = 10,   // ROM 地址位宽 (1024 点)
    parameter DATA_W  = 12    // 输出数据位宽
)(
    input  wire               clk,
    input  wire               rst_n,        // 低电平有效异步复位
    input  wire [1:0]         wave_sel,     // 00=正弦, 01=方波, 10=三角, 11=锯齿
    input  wire [PHASE_W-1:0] ftw,          // 频率控制字
    input  wire               ftw_valid,    // 单周期脉冲_
    output wire [DATA_W-1:0]  dds_out       // 波形数据输出
);

    // 1. ftw 同步更新逻辑与相位累加器
    reg [PHASE_W-1:0] ftw_reg;
    reg [PHASE_W-1:0] phase_acc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ftw_reg   <= {PHASE_W{32'd8590}};
            phase_acc <= {PHASE_W{1'b0}};
        end else begin
            if (ftw_valid)
                ftw_reg <= ftw;

            phase_acc <= phase_acc + ftw_reg;
        end
    end

  
    // 2. 截断相位取高 10 位作为 ROM 地址
    wire [ADDR_W-1:0] rom_addr = phase_acc[PHASE_W-1 -: ADDR_W];

    // 3. 例化 4 个 ROM IP 核
    wire [DATA_W-1:0] sin_d, square_d, tri_d, saw_d;

    rom_sin u_rom_sin (
        .clka  (clk),
        .addra (rom_addr),
        .douta (sin_d)
    );

    rom_square u_rom_square (
        .clka  (clk),
        .addra (rom_addr),
        .douta (square_d)
    );

    rom_tri u_rom_tri (
        .clka  (clk),
        .addra (rom_addr),
        .douta (tri_d)
    );

    rom_saw u_rom_saw (
        .clka  (clk),
        .addra (rom_addr),
        .douta (saw_d)
    );

    // 4. 四选一 MUX
    reg [DATA_W-1:0] mux_out;
    always @(*) begin
        case (wave_sel)
            2'd0: mux_out = sin_d;
            2'd1: mux_out = square_d;
            2'd2: mux_out = tri_d;
            2'd3: mux_out = saw_d;
            default: mux_out = sin_d;
        endcase
    end

    assign dds_out = mux_out;

endmodule
