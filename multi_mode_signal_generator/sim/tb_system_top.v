`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/21 18:15:29
// Design Name: 
// Module Name: tb_system_top
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


module tb_system_top();

    reg clk_50M;
    reg rst_n;
    reg uart_rx;
    
    system_top u_system_top(
        .clk_50M(clk_50M),
        .rst_n(rst_n),
        .uart_rx(uart_rx)
    );
    
    initial clk_50M=0;
    always #10 clk_50M=~clk_50M;
    
    task send_byte(input [7:0] data);
        integer i;
        begin
            uart_rx = 1'b0;         // 起始位
            #(868*10);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];  // 数据位
                #(868*10);
            end
            uart_rx = 1'b1;         // 停止位
            #(868*10);
        end
    endtask
    
    initial begin
        rst_n=1'b0;
        uart_rx=1'b1;
        #200;
        rst_n=1'b1;
        
        #100000;   //等PLL锁定
        
        // 发方波命令
        send_byte("W");
        send_byte("1");
        send_byte("\n");

        // 发频率命令
        send_byte("F");
        send_byte("2");
        send_byte("1");
        send_byte("4");
        send_byte("7");
        send_byte("\n");

        #2000000;   // 再跑 2ms 看波形
    
        $stop;
    end
    
    
endmodule
