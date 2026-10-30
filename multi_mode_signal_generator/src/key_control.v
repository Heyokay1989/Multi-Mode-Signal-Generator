`timescale 1ns / 1ps
module key_control(
    input  wire clk,
    input  wire rst_n,
    input  wire Key1_P_Flag,
    input  wire Key2_P_Flag,
    input  wire Key3_P_Flag,
    input  wire Key4_P_Flag,
    output reg  [1:0]  key_wave_sel,
    output reg         key_wave_valid,
    output reg  [31:0] key_ftw,
    output reg         key_ftw_valid
);

    localparam [31:0] FTW_STEP    = 32'd2147; // 50Hz ²½½ø
    localparam [31:0] FTW_DEFAULT = 32'd8590;  // 200Hz Ä¬ÈÏ

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            key_wave_sel   <= 2'd0;
            key_wave_valid <= 1'b0;
            key_ftw        <= FTW_DEFAULT;
            key_ftw_valid  <= 1'b0;
        end else begin
            key_wave_valid <= 1'b0;
            key_ftw_valid  <= 1'b0;

            if(Key4_P_Flag) begin
                key_wave_sel   <= 2'd0;
                key_ftw        <= FTW_DEFAULT;
                key_wave_valid <= 1'b1;
                key_ftw_valid  <= 1'b1;
            end else begin
                if(Key1_P_Flag) begin
                    key_wave_valid <= 1'b1;
                    key_wave_sel   <= (key_wave_sel == 2'd3) ? 2'd0
                                                            : key_wave_sel + 2'd1;
                end
                if(Key2_P_Flag) begin
                    key_ftw_valid <= 1'b1;
                    if(key_ftw > (32'hFFFFFFFF - FTW_STEP))
                        key_ftw <= 32'hFFFFFFFF;
                    else
                        key_ftw <= key_ftw + FTW_STEP;
                end
                if(Key3_P_Flag) begin
                    key_ftw_valid <= 1'b1;
                    if(key_ftw > FTW_STEP)
                        key_ftw <= key_ftw - FTW_STEP;
                    else
                        key_ftw <= 32'd0;
                end
            end
        end
    end
endmodule