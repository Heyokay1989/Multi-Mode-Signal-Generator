`timescale 1ns / 1ps


module mode_mux(
    input  wire [31:0] ftw_normal,        // 来自 control_top
    input  wire        ftw_valid_normal,  // 来自 control_top
    input  wire [31:0] ftw_lfsr,          // 来自 lfsr
    input  wire        lfsr_tick,         // 来自 lfsr_timer
    input  wire [31:0] ftw_sweep,         //扫频
    input  wire        sweep_tick,        //扫频
    input  wire [2:0]  mode_sel,          // 0=正常，1=跳频
    input  wire [31:0] ftw_fm,
    input  wire [31:0] ftw_cpfsk,
    output reg [31:0] ftw_out,
    output reg        ftw_valid_out
);
    always @(*) begin
        case (mode_sel)
            3'd0: begin ftw_out = ftw_normal; ftw_valid_out = ftw_valid_normal; end
            3'd1: begin ftw_out = ftw_lfsr;   ftw_valid_out = lfsr_tick; end
            3'd2: begin ftw_out = ftw_sweep;  ftw_valid_out = sweep_tick; end
            3'd3: begin ftw_out = ftw_normal; ftw_valid_out = ftw_valid_normal; end
            3'd4: begin ftw_out = ftw_fm; ftw_valid_out = 1'b1; end
            3'd5: begin ftw_out = ftw_normal; ftw_valid_out = ftw_valid_normal; end
            3'd6: begin ftw_out = ftw_cpfsk; ftw_valid_out = 1'b1; end
            default: begin ftw_out = ftw_normal; ftw_valid_out = ftw_valid_normal; end
        endcase
    end
    
endmodule