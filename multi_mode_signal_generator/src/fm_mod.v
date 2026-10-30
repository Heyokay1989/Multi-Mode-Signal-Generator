`timescale 1ns / 1ps

module fm_mod(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] ftw_base,
    input  wire [6:0]  mod_depth,
    input  wire [6:0]  mod_freq,
    output reg  [31:0] ftw_fm
);

    reg [19:0] step_cnt;
    reg [11:0] tri_val;      // 0~250
    reg        dir;

    wire [19:0] step_max = 20'd500_000 - (mod_freq << 12);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_cnt <= 20'd0;
            tri_val  <= 12'd0;
            dir      <= 1'b0;
        end else begin
            if (step_cnt >= step_max - 1) begin
                step_cnt <= 20'd0;
                if (dir == 1'b0) begin
                    if (tri_val >= 12'd250)
                        dir <= 1'b1;
                    else
                        tri_val <= tri_val + 1'b1;
                end else begin
                    if (tri_val == 12'd0)
                        dir <= 1'b0;
                    else
                        tri_val <= tri_val - 1'b1;
                end
            end else
                step_cnt <= step_cnt + 1'b1;
        end
    end

    wire [31:0] mod_offset = (tri_val * mod_depth) >> 1;

    wire [31:0] ftw_up = ftw_base + mod_offset;
    wire [31:0] ftw_dn = ftw_base - mod_offset;

    always @(*) begin
        if (dir == 1'b0)
            ftw_fm = (ftw_up > 32'd50000) ? 32'd50000 : ftw_up;
        else
            ftw_fm = (ftw_dn < 32'd2000)  ? 32'd2000  : ftw_dn;
    end

endmodule