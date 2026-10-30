module cmd_parser(
    input clk,
    input rst_n,
    input Rx_Done,
    input [7:0]Rx_Data,
    output reg [1:0]wave_sel,
    output reg [31:0]ftw,
    output reg ftw_valid,
    output reg wave_valid,
    output reg [2:0]mode_sel,
    output reg mode_valid,
    output reg [6:0]mod_depth,
    output reg [6:0]mod_freq,
    output reg        awg_wr_en,
    output reg [9:0]  awg_wr_addr,
    output reg [11:0] awg_wr_data
    );

    localparam S_IDLE  = 3'd0;
    localparam S_WAVE  = 3'd1;
    localparam S_FREQ  = 3'd2;
    localparam S_MODE  = 3'd3;
    localparam S_DEPTH = 3'd4;
    localparam S_MFREQ = 3'd5;
    localparam S_UADDR = 3'd6;    // 等地址数字
    localparam S_UDATA = 3'd7;    // 等数据数字

    reg [2:0]state;
    reg [31:0]value;
    reg [1:0]wave_temp;
    reg [2:0]mode_temp;
    reg [9:0]addr_temp;           // 存 U 命令的地址

    always@(negedge rst_n or posedge clk)begin
        if(!rst_n) begin
            state<=S_IDLE;
            value<=32'd0;
            wave_temp<=2'd0;
            wave_sel<=2'd0;
            ftw<=32'd0;
            ftw_valid<=1'b0;
            wave_valid<=1'b0;
            mode_sel<=3'd0;
            mode_valid<=1'b0;
            mod_depth<=7'd50;
            mod_freq<=7'd50;
            awg_wr_en<=1'b0;
            awg_wr_addr<=10'd0;
            awg_wr_data<=12'd0;
            addr_temp<=10'd0;
        end
        else begin
            ftw_valid<=1'b0;
            wave_valid<=1'b0;
            mode_valid<=1'b0;
            awg_wr_en<=1'b0;      // 默认清零，只在写那一刻拉高

            case(state)

                S_IDLE:begin
                    if(Rx_Done)begin
                        if(Rx_Data=="W")begin
                            wave_temp<=2'd0;
                            state<=S_WAVE;
                        end
                        else if(Rx_Data=="F")begin
                            value<=32'd0;
                            state<=S_FREQ;
                        end
                        else if(Rx_Data=="M")begin
                            state<=S_MODE;
                        end
                        else if(Rx_Data=="K")begin
                            value<=32'd0;
                            state<=S_DEPTH;
                        end
                        else if(Rx_Data=="L")begin
                            value<=32'd0;
                            state<=S_MFREQ;
                        end
                        else if(Rx_Data=="U")begin
                            value<=32'd0;
                            state<=S_UADDR;
                        end
                    end
                end

                S_WAVE:begin
                    if(Rx_Done)begin
                        if(Rx_Data>="0"&&Rx_Data<="3")begin
                            wave_temp<=Rx_Data-"0";
                        end
                        else if(Rx_Data==8'h0D)begin
                        end
                        else if(Rx_Data==8'h0A)begin
                            wave_sel<=wave_temp;
                            wave_valid<=1'b1;
                            state<=S_IDLE;
                        end
                        else begin
                            wave_temp<=2'd0;
                            state<=S_IDLE;
                        end
                    end
                end

                S_FREQ:begin
                    if(Rx_Done)begin
                        if(Rx_Data>="0"&&Rx_Data<="9")begin
                            value<=(value*10+(Rx_Data-"0"));
                        end
                        else if(Rx_Data==8'h0D)begin
                        end
                        else if(Rx_Data==8'h0A)begin
                            ftw<=value;
                            ftw_valid<=1'b1;
                            value<=32'd0;
                            state<=S_IDLE;
                        end
                        else begin
                            value<=32'd0;
                            state<=S_IDLE;
                        end
                    end
                end

                S_MODE:begin
                    if(Rx_Done)begin
                        if(Rx_Data>="0"&&Rx_Data<="6")begin
                            mode_temp<=Rx_Data-"0";
                        end
                        else if(Rx_Data==8'h0D)begin
                        end
                        else if(Rx_Data==8'h0A)begin
                            mode_sel<=mode_temp;
                            mode_valid<=1'b1;
                            state<=S_IDLE;
                        end
                        else begin
                            mode_temp<=3'd0;
                            state<=S_IDLE;
                        end
                    end
                end

                S_DEPTH:begin
                    if(Rx_Done)begin
                        if(Rx_Data>="0"&&Rx_Data<="9")begin
                            value<=(value*10+(Rx_Data-"0"));
                        end
                        else if(Rx_Data==8'h0D)begin
                        end
                        else if(Rx_Data==8'h0A)begin
                            if(value>32'd100)
                                mod_depth<=7'd100;
                            else
                                mod_depth<=value[6:0];
                            value<=32'd0;
                            state<=S_IDLE;
                        end
                        else begin
                            value<=32'd0;
                            state<=S_IDLE;
                        end
                    end
                end

                S_MFREQ:begin
                    if(Rx_Done)begin
                        if(Rx_Data>="0"&&Rx_Data<="9")begin
                            value<=(value*10+(Rx_Data-"0"));
                        end
                        else if(Rx_Data==8'h0D)begin
                        end
                        else if(Rx_Data==8'h0A)begin
                            if(value>32'd100)
                                mod_freq<=7'd100;
                            else
                                mod_freq<=value[6:0];
                            value<=32'd0;
                            state<=S_IDLE;
                        end
                        else begin
                            value<=32'd0;
                            state<=S_IDLE;
                        end
                    end
                end

                // ---- 解析 U 命令的地址 ----
                S_UADDR:begin
                    if(Rx_Done)begin
                        if(Rx_Data>="0"&&Rx_Data<="9")begin
                            value<=(value*10+(Rx_Data-"0"));
                        end
                        else if(Rx_Data==",")begin
                            if(value>32'd1023)
                                addr_temp<=10'd1023;
                            else
                                addr_temp<=value[9:0];
                            value<=32'd0;
                            state<=S_UDATA;
                        end
                        else if(Rx_Data==8'h0D)begin
                            // 忽略 \r     
                        end
                        else begin
                            value<=32'd0;
                            state<=S_IDLE;
                        end
                    end
                end
                // ---- 解析 U 命令的数据 ----
                S_UDATA:begin
                    if(Rx_Done)begin
                        if(Rx_Data>="0"&&Rx_Data<="9")begin
                            value<=(value*10+(Rx_Data-"0"));
                        end
                        else if(Rx_Data==8'h0D)begin
                            // 忽略 \r       
                        end
                        else if(Rx_Data==8'h0A)begin
                            awg_wr_addr<=addr_temp;
                            if(value>32'd4095)
                                awg_wr_data<=12'd4095;
                            else
                                awg_wr_data<=value[11:0];
                            awg_wr_en<=1'b1;
                            value<=32'd0;
                            state<=S_IDLE;
                        end
                        else begin
                            value<=32'd0;
                            state<=S_IDLE;
                        end
                    end
                end

                default:begin
                    state<=S_IDLE;
                end

            endcase
        end
    end

endmodule