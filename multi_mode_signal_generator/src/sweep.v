`timescale 1ns / 1ps


module sweep(
    input  wire        clk,
    input  wire        rst_n,
    output reg  [31:0] ftw_out,
    output reg         sweep_tick
);

    localparam [31:0] FTW_START = 32'd43;      //1Hz
    localparam [31:0] FTW_END   = 32'd42950;   //1000Hz
    localparam [31:0] FTW_STEP  = 32'd430;     //10Hz

    reg [19:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt        <= 20'd0;
            ftw_out    <= FTW_START;              // 初值
            sweep_tick <= 1'b0;
        end else begin
            sweep_tick <= 1'b0;
            if (cnt == 20'd999_999) begin   // 10ms 到了
                cnt        <= 20'd0;
                sweep_tick <= 1'b1;
                if (ftw_out + FTW_STEP > FTW_END)
                    ftw_out <= FTW_START;         // 超上限，回到起点
                else
                    ftw_out <= ftw_out + FTW_STEP;
            end else
                cnt <= cnt + 1'b1;
        end
    end

endmodule
