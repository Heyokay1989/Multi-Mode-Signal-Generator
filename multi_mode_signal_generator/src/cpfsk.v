`timescale 1ns / 1ps

module cpfsk(
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] ftw_out
);

    // 比特周期：10ms @ 100MHz
    localparam [19:0] BIT_PERIOD = 20'd1_000_000;

    // 预设 8 位数据（循环发送 10110010）
    localparam [7:0]  DATA_BYTE = 8'b1011_0010;

    // 两个频率对应的 FTW
    // f0 = 500Hz  → 500 × 42.94967296 ≈ 21475
    // f1 = 1000Hz → 1000 × 42.94967296 ≈ 42950
    localparam [31:0] FTW_F0 = 32'd21475;
    localparam [31:0] FTW_F1 = 32'd42950;

    reg [19:0] bit_cnt;
    reg [2:0]  bit_idx;
    reg        current_bit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt     <= 20'd0;
            bit_idx     <= 3'd0;
            current_bit <= 1'b0;
        end else begin
            if (bit_cnt >= BIT_PERIOD - 1) begin
                bit_cnt <= 20'd0;
                current_bit <= DATA_BYTE[3'd7 - bit_idx];  // MSB 先发
                if (bit_idx == 3'd7)
                    bit_idx <= 3'd0;
                else
                    bit_idx <= bit_idx + 1'b1;
            end else begin
                bit_cnt <= bit_cnt + 1'b1;
            end
        end
    end

    // 连续相位：直接根据当前比特选频率，不重置相位
    assign ftw_out = current_bit ? FTW_F1 : FTW_F0;

endmodule
