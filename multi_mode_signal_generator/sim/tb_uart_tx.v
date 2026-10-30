`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/04 21:38:31
// Design Name: 
// Module Name: tb_uart_tx
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


module tb_uart_tx;
    reg clk, rst_n, tx_valid;
    reg [7:0] tx_data;
    wire tx, Tx_Done;
    
    uart_tx dut (.clk(clk), .rst_n(rst_n), .tx_data(tx_data), 
                 .tx_valid(tx_valid), .tx(tx), .Tx_Done(Tx_Done));
    
    initial clk = 0;
    always #5 clk = ~clk;
    
    initial begin
        rst_n = 0; tx_valid = 0; tx_data = 8'h57;  // 'W'
        #200;
        rst_n = 1;
        #100;
        
        @(posedge clk);
        tx_valid <= 1'b1;
        @(posedge clk);
        tx_valid <= 1'b0;
        
        #100000;
        $stop;
    end
endmodule
