`timescale 1ns / 1ps

module lfsr(
    input  wire       clk,
    input  wire       rst_n,
    output reg  [31:0] rand_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rand_out <= 32'h0000_0001;
        else
            rand_out <= {rand_out[30:0], rand_out[31] ^ rand_out[21] ^ rand_out[1] ^ rand_out[0]};
    end
endmodule
