`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/21 10:49:31
// Design Name: 
// Module Name: clk_gen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module clk_gen(
    input wire clk_50M,
    input wire  rst_n,
    output wire clk_100M,
    output wire rst_n_sys
    );
    
    wire pll_reset;
    wire locked;
    
    assign pll_reset=~rst_n;
    
    clk_wiz_0 u_clk_wiz_o(
    .clk_out1(clk_100M),    
    .reset(pll_reset), 
    .locked(locked),       
    .clk_in1(clk_50M)
    );  
    
    assign rst_n_sys = rst_n & locked;  
    
endmodule
