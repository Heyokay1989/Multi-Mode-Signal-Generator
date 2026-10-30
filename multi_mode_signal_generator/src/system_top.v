`timescale 1ns / 1ps


module system_top(
    input clk_50M,
    input rst_n,
    input uart_rx,
    input wire [3:0] key,
    output wire uart_txd
    );
    
    wire clk_100M;
    wire rst_n_sys;
    wire [1:0]wave_sel_out;
    wire ftw_valid_out;
    wire [11:0] dds_out;
    wire [7:0]tx_data;
    wire tx_valid;
    wire tx_done;  
    reg [2:0]mode_sel;
    wire key3_pulse;    // 独立给 key[3] 做消抖
    
    key_debounce #(.DEBOUNCE_CNT(21'd2_000_000)) u_db_mode(
        .clk       (clk_100M),
        .rst_n     (rst_n_sys),
        .key_in    (key[3]),       // KEY4 引脚 T6
        .key_pulse (key3_pulse)
    );
    
    always @(posedge clk_100M or negedge rst_n_sys) begin
        if (!rst_n_sys)
            mode_sel <= 3'd0;
        else if (key3_pulse) begin
            if (mode_sel == 3'd0)
                mode_sel <= 3'd1;
            else
                mode_sel <= 3'd0;
        end
    end
   
    
    clk_gen u_clk_gen(
        .clk_50M(clk_50M),
        .rst_n(rst_n),
        .clk_100M(clk_100M),
        .rst_n_sys(rst_n_sys)
    );
    
    dds_top u_dds_top(
        .clk(clk_100M),       
        .rst_n(rst_n_sys),
        .uart_rx(uart_rx),
        .key1(key[0]),
        .key2(key[1]),
        .key3(key[2]),
        .key4(key[3]),
        .dds_out(dds_out),
        .mode_sel(mode_sel),
        .wave_sel_out(wave_sel_out),
        .ftw_valid_out(ftw_valid_out)
    );
    
    data_pack u_data_pack (
        .clk      (clk_100M),
        .rst_n    (rst_n_sys),
        .dds_out  (dds_out),
        .tx_data  (tx_data),
        .tx_valid (tx_valid),
        .tx_done  (tx_done)
    );
    
    uart_tx u_uart_tx (
        .clk      (clk_100M),
        .rst_n    (rst_n_sys),
        .tx_data  (tx_data),
        .tx_valid (tx_valid),
        .tx       (uart_txd),
        .Tx_Done  (tx_done)
    );
    
    ila_0 u_ila(
        .clk(clk_100M),
        .probe0(u_dds_top.awg_out),
        .probe1(wave_sel_out),
        .probe2(u_dds_top.awg_wr_en)
    );

endmodule
