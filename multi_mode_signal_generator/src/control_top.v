`timescale 1ns / 1ps
module control_top #(
    parameter [20:0] DEBOUNCE_CNT = 21'd2_000_000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire uart_rx,
    input  wire key1,
    input  wire key2,
    input  wire key3,
    input  wire key4,
    output wire [1:0]  wave_sel,
    output wire [31:0] ftw,
    output wire ftw_valid,
    output wire [2:0] mode_sel_uart,
    output wire mode_valid_uart,
    output wire [6:0] mod_depth,
    output wire [6:0] mod_freq,
    output wire        awg_wr_en,
    output wire [9:0]  awg_wr_addr,
    output wire [11:0] awg_wr_data
);

    localparam [31:0] FTW_DEFAULT = 32'd8590;

    wire [7:0] rx_data;
    wire       rx_done;
    wire [2:0] serial_mode_sel;       
    wire       serial_mode_valid; 
    wire [6:0] serial_mod_depth;
    wire [6:0] serial_mod_freq;
    wire        serial_awg_wr_en;
    wire [9:0]  serial_awg_wr_addr;
    wire [11:0] serial_awg_wr_data;

    assign mode_sel_uart   = serial_mode_sel;
    assign mode_valid_uart = serial_mode_valid;
    
    assign awg_wr_en   = serial_awg_wr_en;
    assign awg_wr_addr = serial_awg_wr_addr;
    assign awg_wr_data = serial_awg_wr_data;
    
    uart_rx u_uart_rx(
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .Rx_Done(rx_done),
        .Rx_Data(rx_data)
    );

    wire [1:0]  serial_wave_sel;
    wire [31:0] serial_ftw;
    wire        serial_wave_valid;
    wire        serial_ftw_valid;

    cmd_parser u_cmd_parser(
        .clk(clk),
        .rst_n(rst_n),
        .Rx_Done(rx_done),
        .Rx_Data(rx_data),
        .wave_sel(serial_wave_sel),
        .ftw(serial_ftw),
        .ftw_valid(serial_ftw_valid),
        .wave_valid(serial_wave_valid),
        .mode_sel   (serial_mode_sel),     
        .mode_valid (serial_mode_valid),
        .mod_depth  (serial_mod_depth),
        .mod_freq   (serial_mod_freq),
        .awg_wr_en       (serial_awg_wr_en),      
        .awg_wr_addr     (serial_awg_wr_addr),   
        .awg_wr_data     (serial_awg_wr_data)      
    );
    
    assign mod_depth = serial_mod_depth;
    assign mod_freq  = serial_mod_freq;

    wire key1_p, key2_p, key3_p, key4_p;

    key_debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) u_db1(.clk(clk), .rst_n(rst_n), .key_in(key1), .key_pulse(key1_p));
    key_debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) u_db2(.clk(clk), .rst_n(rst_n), .key_in(key2), .key_pulse(key2_p));
    key_debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) u_db3(.clk(clk), .rst_n(rst_n), .key_in(key3), .key_pulse(key3_p));
    key_debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) u_db4(.clk(clk), .rst_n(rst_n), .key_in(key4), .key_pulse(key4_p));

    wire [1:0]  key_wave_sel;
    wire [31:0] key_ftw;
    wire        key_wave_valid;
    wire        key_ftw_valid;

    key_control u_key_control(
        .clk(clk),
        .rst_n(rst_n),
        .Key1_P_Flag(key1_p),
        .Key2_P_Flag(key2_p),
        .Key3_P_Flag(key3_p),
        .Key4_P_Flag(key4_p),
        .key_wave_sel(key_wave_sel),
        .key_wave_valid(key_wave_valid),
        .key_ftw(key_ftw),
        .key_ftw_valid(key_ftw_valid)
    );

    reg [1:0]  wave_sel_r;
    reg [31:0] ftw_r;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wave_sel_r <= 2'd0;
            ftw_r      <= FTW_DEFAULT;
        end else begin
            if(serial_wave_valid)
                wave_sel_r <= serial_wave_sel;
            else if(key_wave_valid)
                wave_sel_r <= key_wave_sel;

            if(serial_ftw_valid)
                ftw_r <= serial_ftw;
            else if(key_ftw_valid)
                ftw_r <= key_ftw;
        end
    end

    assign wave_sel  = wave_sel_r;
    assign ftw = serial_ftw_valid ? serial_ftw :
                 key_ftw_valid    ? key_ftw    :
                 ftw_r;

    assign ftw_valid = serial_ftw_valid | key_ftw_valid;

endmodule