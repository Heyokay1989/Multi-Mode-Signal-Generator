`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/20 23:40:32
// Design Name: 
// Module Name: tb_dds_top
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


module tb_dds_top();
    
    reg clk;
    reg rst_n;
    reg uart_rx;
    wire [11:0]dds_out;
    
    dds_top u_dds_top(
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx(uart_rx),
    .dds_out(dds_out)
    );
    
initial clk=1'b1;
always #5 clk=~clk;

task send_byte(input [7:0]data);
    integer i;
    begin
        //置起始位
        uart_rx=1'b0;
        #(868*10);
    
        //置数据位
        for(i=0;i<8;i=i+1)begin
            uart_rx=data[i];
            #(868*10);
        end 
        
        //置停止位
        uart_rx=1'b1;
        #(868*10);  
    end
endtask

initial begin
    rst_n=1'b0;
    uart_rx=1'b1;
    #200;
    rst_n=1'b1;
    #1000;
    
    //发送方波
    send_byte("W");
    send_byte("1");
    send_byte("\n");
    
    //发送频率
    send_byte("F");
    send_byte("4");
    send_byte("2");
    send_byte("9");
    send_byte("4");
    send_byte("9");
    send_byte("\n");
    
    #2000000;
    $stop;
end
      
endmodule
