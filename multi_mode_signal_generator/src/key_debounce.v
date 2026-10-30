`timescale 1ns / 1ps
module key_debounce(
    input  wire clk,
    input  wire rst_n,
    input  wire key_in,
    output reg  key_pulse
);
    parameter [20:0] DEBOUNCE_CNT = 21'd2_000_000; // 20ms @100MHz

    reg key_in_r0;
    reg key_in_r1;
    reg key_stable;
    reg key_stable_d;
    reg [20:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            key_in_r0 <= 1'b1;
            key_in_r1 <= 1'b1;
        end else begin
            key_in_r0 <= key_in;
            key_in_r1 <= key_in_r0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt <= 21'd0;
            key_stable <= 1'b1;
        end else begin
            if(key_in_r1 != key_stable) begin
                if(cnt == DEBOUNCE_CNT) begin
                    key_stable <= key_in_r1;
                    cnt <= 21'd0;
                end else begin
                    cnt <= cnt + 21'd1;
                end
            end else begin
                cnt <= 21'd0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            key_stable_d <= 1'b1;
        else
            key_stable_d <= key_stable;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            key_pulse <= 1'b0;
        else
            key_pulse <= key_stable_d & ~key_stable;
    end
endmodule