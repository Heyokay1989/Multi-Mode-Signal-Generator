module uart_rx(
    clk,
    rst_n,
    uart_rx,
    Rx_Done,
    Rx_Data
    );
    
    input clk;
    input rst_n;
    input uart_rx;
    output reg Rx_Done;
    output reg [7:0]Rx_Data;
    
    parameter CLOCK_FREQ=100_000_000;
    parameter BAUD=921600;
    parameter MCNT_BAUD=CLOCK_FREQ/BAUD-1;
    
    reg [7:0]r_Rx_Data;
    reg [29:0]baud_div_cnt;
    reg en_baud_cnt;
    reg [3:0]bit_cnt;
    wire nedge_uart_rx;
    wire w_Rx_Done;
    reg r_uart_rx;
    reg dff0_uart_rx,dff1_uart_rx;
    
//波特率计数器逻辑
    always@(posedge clk or negedge rst_n)
    if(!rst_n)
        baud_div_cnt<=0;
    else if(en_baud_cnt)begin
        if(baud_div_cnt==MCNT_BAUD)
            baud_div_cnt<=0;
        else
            baud_div_cnt<=baud_div_cnt+1'b1;
    end
    else 
        baud_div_cnt<=0;

//UART信号边沿检测逻辑
    always@(posedge clk)
        dff0_uart_rx<=uart_rx;
        
    always@(posedge clk)
        dff1_uart_rx<=dff0_uart_rx;
        
    always@(posedge clk)
        r_uart_rx<=dff1_uart_rx;
    
    assign nedge_uart_rx=((dff1_uart_rx==0)&&(r_uart_rx==1));

//波特率计数器使能逻辑
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        en_baud_cnt<=0;
    else if(nedge_uart_rx)
        en_baud_cnt<=1;
    else if((baud_div_cnt==MCNT_BAUD/2)&&(bit_cnt==0)&&(dff1_uart_rx==1))
        en_baud_cnt<=0;
    else if((baud_div_cnt==MCNT_BAUD/2)&&(bit_cnt==9))
        en_baud_cnt<=0;
        

//位计数器逻辑
    always@(posedge clk or negedge rst_n)
    if(!rst_n)
        bit_cnt<=0;        
    else if((bit_cnt==9)&&(baud_div_cnt==MCNT_BAUD/2))
            bit_cnt<=0;
    else if(baud_div_cnt==MCNT_BAUD)
            bit_cnt<=bit_cnt+1'b1;

//位接收逻辑
    always@(posedge clk or negedge rst_n)
    if(!rst_n)
        r_Rx_Data<=8'b0;
    else if(baud_div_cnt==MCNT_BAUD/2)begin
        case(bit_cnt)
            1:r_Rx_Data[0]<=dff1_uart_rx;
            2:r_Rx_Data[1]<=dff1_uart_rx;
            3:r_Rx_Data[2]<=dff1_uart_rx;
            4:r_Rx_Data[3]<=dff1_uart_rx;
            5:r_Rx_Data[4]<=dff1_uart_rx;
            6:r_Rx_Data[5]<=dff1_uart_rx;
            7:r_Rx_Data[6]<=dff1_uart_rx;
            8:r_Rx_Data[7]<=dff1_uart_rx;
            default:r_Rx_Data<=r_Rx_Data;
        endcase
    end

//接收完成标志信号
    assign w_Rx_Done=((baud_div_cnt==MCNT_BAUD/2)&&(bit_cnt==9));
    
     always@(posedge clk)
        Rx_Done<=w_Rx_Done;
        
    always@(posedge clk)
    if(w_Rx_Done)
        Rx_Data<=r_Rx_Data;

endmodule
