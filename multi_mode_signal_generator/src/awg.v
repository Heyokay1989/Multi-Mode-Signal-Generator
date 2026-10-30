`timescale 1ns / 1ps


module awg(
    input  wire        clk,
    input  wire        rst_n,
    // 频率控制（和 dds_core 一样的 ftw）
    input  wire [31:0] ftw,
    input  wire        ftw_valid,
    // 写接口（来自 cmd_parser）
    input  wire        wr_en,
    input  wire [9:0]  wr_addr,
    input  wire [11:0] wr_data,
    // 输出
    output wire [11:0] dds_out
);

    // ---- 独立的相位累加器 ----
    reg [31:0] phase_acc;
    reg [31:0] ftw_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc <= 32'd0;
            ftw_reg   <= 32'd8590;      // 默认 200Hz
        end else begin
            if (ftw_valid)
                ftw_reg <= ftw;
            phase_acc <= phase_acc + ftw_reg;
        end
    end

    // ---- 用相位高 10 位当读地址 ----
    wire [9:0] rd_addr = phase_acc[31:22];

    // ---- 双口 RAM ----
    awg_ram u_ram (
        // Port A（写）
        .clka  (clk),
        .wea   (wr_en),
        .addra (wr_addr),
        .dina  (wr_data),
        .douta (),
        // Port B（读）
        .clkb  (clk),
        .web   (1'b0),
        .addrb (rd_addr),
        .dinb  (12'd0),
        .doutb (dds_out)
    );

endmodule
