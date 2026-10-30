`timescale 1ns / 1ps


module lfsr_timer(
    input  wire clk,
    input  wire rst_n,
    output reg  lfsr_tick
);
    reg [22:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt       <= 23'd0;
            lfsr_tick <= 1'b0;
        end else begin
            lfsr_tick <= 1'b0;                    // 默认清零
            if (cnt == 23'd4_999_999) begin         // 数到多少？
                cnt       <= 23'd0;               // 归零
                lfsr_tick <= 1'b1;                // 脉冲
            end else
                cnt <= cnt + 1'b1;
        end
    end
endmodule