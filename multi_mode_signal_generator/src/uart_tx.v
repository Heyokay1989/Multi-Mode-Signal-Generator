`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/02 20:44:36
// Design Name: 
// Module Name: uart_tx
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


module uart_tx(
    input wire clk,
    input wire rst_n,
    input wire[7:0] tx_data,
    input wire tx_valid,
    output reg tx,
    output reg Tx_Done
    );
    
    parameter CLK_FREQ = 100_000_000;
    parameter BAUD = 921600;
    parameter MCNT_BAUD = CLK_FREQ / BAUD - 1; 
    
    localparam IDLE = 2'd0;
    localparam START = 2'd1;
    localparam DATA = 2'd2;
    localparam STOP = 2'd3;
    
    reg [1:0] state;
    reg [15:0] baud_cnt;
    reg [2:0] bit_idx;
    reg [7:0] t_Tx_data;
    
    //波特率计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            baud_cnt <= 16'd0;
        else if (state == IDLE)
            baud_cnt <= 16'd0;
        else if (baud_cnt == MCNT_BAUD)
            baud_cnt <= 16'd0;
        else
            baud_cnt <= baud_cnt + 1'b1;
    end
    
    //状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            tx        <= 1'b1;
            Tx_Done   <= 1'b0;
            bit_idx   <= 3'd0;
            t_Tx_data <= 8'd0;
        end else begin
            Tx_Done <= 1'b0;   // 默认清零，只在 STOP 结束时拉高
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (tx_valid) begin
                        t_Tx_data <= tx_data;    // 锁存数据
                        state     <= START;
                    end
                end
                START: begin
                    tx <= 1'b0;
                    if (baud_cnt == MCNT_BAUD)
                        state <= DATA;
                end
                DATA: begin
                    tx <= t_Tx_data[bit_idx];
                    if (baud_cnt == MCNT_BAUD) begin
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= STOP;
                        end else
                            bit_idx <= bit_idx + 1'b1;
                    end
                end
                STOP: begin
                    tx <= 1'b1;
                    if (baud_cnt == MCNT_BAUD) begin
                        Tx_Done <= 1'b1;
                        state   <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
    
    
endmodule
