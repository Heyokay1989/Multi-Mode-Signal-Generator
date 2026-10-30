`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/04 21:23:56
// Design Name: 
// Module Name: data_pack
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


module data_pack (
    input  wire clk,           // 100MHz
    input  wire rst_n,
    input  wire [11:0] dds_out,       // 来自 dds_core
    input  wire tx_done,        // 来自 uart_tx
    output reg [7:0] tx_data,
    output reg tx_valid       // 单周期脉冲
    );
   
    reg [15:0] timer;      // 16位够（40000 < 65536）
    reg sample_tick;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer <= 16'd0;
            sample_tick <= 1'b0;
        end else begin
            sample_tick <= 1'b0;    // 默认清零，只脉冲一拍
            if (timer == 16'd4999) begin
                timer <= 16'd0;
                sample_tick <= 1'b1;  // 脉冲
            end else
                timer <= timer + 1'b1;
        end
    end 
    
    localparam S_IDLE = 2'd0;
    localparam S_LOAD = 2'd1;
    localparam S_WAIT = 2'd2;
    
    reg [1:0]  state;
    reg [2:0]  data_index;    // 0~4，表示当前发第几个字节
    reg [11:0] dds_out_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            data_index  <= 3'd0;
            tx_data     <= 8'd0;
            tx_valid    <= 1'b0;
            dds_out_reg <= 12'd0;
        end else begin
            tx_valid <= 1'b0;    // 默认清零
            case (state)
                S_IDLE: begin
                    if (sample_tick) begin
                        dds_out_reg <= dds_out;
                        data_index  <= 3'd0;
                        state       <= S_LOAD;
                    end
                end
                S_LOAD: begin
                    // 根据 data_index 决定发什么
                    case (data_index)
                        3'd0: tx_data <= 8'hAA;
                        3'd1: tx_data <= dds_out_reg[7:0];
                        3'd2: tx_data <= {4'b0, dds_out_reg[11:8]};
                        3'd3: tx_data <= 8'h55;
                        default: tx_data <= 8'h00;
                    endcase
                    tx_valid <= 1'b1;    // 通知 uart_tx 发这个字节
                    state    <= S_WAIT;
                end
                S_WAIT: begin
                    if (tx_done) begin
                        if (data_index == 3'd3) begin
                            state <= S_IDLE;     // 4 个字节发完
                        end else begin
                            data_index <= data_index + 1'b1;
                            state      <= S_LOAD;   // 发下一个字节
                        end
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
    
endmodule    
