`timescale 1ns / 1ps

module am_mod(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] dds_out,
    input  wire [2:0]  mode_sel,
    input  wire [6:0]  mod_depth,      // 0~100
    input  wire [6:0]  mod_freq,       // 0~100
    output reg  [11:0] dds_out_final
);

    // ---- 低频三角波（调制信号）----
    reg [19:0] step_cnt;
    reg [7:0]  mod_val;      // 0~255
    reg        dir;

    wire [19:0] step_max = 20'd500_000 - (mod_freq << 12);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_cnt <= 20'd0;
            mod_val  <= 8'd0;
            dir      <= 1'b0;
        end else begin
            if (step_cnt >= step_max - 1) begin
                step_cnt <= 20'd0;
                if (dir == 1'b0) begin
                    if (mod_val >= 8'd254)
                        dir <= 1'b1;
                    else
                        mod_val <= mod_val + 1'b1;
                end else begin
                    if (mod_val == 8'd0)
                        dir <= 1'b0;
                    else
                        mod_val <= mod_val - 1'b1;
                end
            end else
                step_cnt <= step_cnt + 1'b1;
        end
    end

    // ---- 调制深度：0~100 映射到 0~125（乘以 1.25，无除法）----
    wire [8:0] md_ext = {2'b0, mod_depth} + ({2'b0, mod_depth} >> 2);
    
    // am_scale = 255 - (255 - mod_val) * md_ext / 128
    wire [15:0] depth_prod = (16'd255 - {8'b0, mod_val}) * md_ext;
    wire [7:0]  am_scale   = 8'd255 - depth_prod[14:7];

    // ---- 偏移二进制转有符号 ----
    wire signed [12:0] signed_dout = {1'b0, dds_out} - 13'sd2048;

    // 乘法器打一拍
    wire signed [20:0] product_comb = signed_dout * $signed({1'b0, am_scale});
    reg  signed [20:0] product_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) product_r <= 21'sd0;
        else        product_r <= product_comb;
    end
    
    wire signed [12:0] am_out = (product_r >>> 8) + 13'sd2048;

    // ---- 限幅 + 模式判断 ----
    always @(*) begin
        if (mode_sel == 3'd3) begin
            if (am_out < 13'sd0)
                dds_out_final = 12'd0;
            else if (am_out > 13'sd4095)
                dds_out_final = 12'd4095;
            else
                dds_out_final = am_out[11:0];
        end else begin
            dds_out_final = dds_out;
        end
    end

endmodule