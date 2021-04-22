`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/11/08 13:31:04
// Design Name: 
// Module Name: GMII_CRC_TOP
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
//impl:LUT:41 FF:54
//////////////////////////////////////////////////////////////////////////////////


module GMII_CRC_TOP(
     input clk
    ,input rst
    ,input gmii_dv_in
    ,input [7:0]gmii_data_in
    
    ,output gmii_dv_out
    ,output [7:0]gmii_data_out
    );
    parameter [31:0] CRC32_POLY = 'hEDB88320;
    parameter [31:0] CRC32_PLOY_i = {1'b0,CRC32_POLY[30:0]};
    reg [31:0] crc_temp;
    wire [31:0] crc_8bit;
    wire [7:0]data = gmii_data_in;
    wire dv = gmii_dv_in;
    
    wire [7:0]data_i;
    wire [31:0]crc_lut;
    
    reg [7:0]data_reg;
    reg [3:0]dv_crc; 
    reg dv_reg; 
    
//    reg [3:0]dv_crc;
    //处理输入valid信号
    //在valid下降时进入crc发送状态，此时可能需要一个输入的UNready来防止数据拥塞
    //在valid=0时，crc temp应该《=ffff，同时crc_temp的值应该接到data用于发送数据
    
    //正常数据接收计算时：
    //  temp<=temp>>8^crc_lut
    //要保证crc传送和12byte的idle，正好64bits的2周期。
    always@(posedge clk)begin   //缓存输入数据，若能保证上级数据高可靠低延迟，可以改成wire，做成generate可配，去流水线
        if(rst)begin
            dv_reg  <=  0;
            data_reg<=  0;
        end
        else begin
            dv_reg  <= gmii_dv_in;
            data_reg<= gmii_data_in;
        end 
    end

//本模块负责生成crc32的查找表
//模块内容可以由verilog实现，也可以由ram查找表实现，本模块使用两种中和的方法
    crc32_lut_mod
     crc_inst(
        .data(data_reg^crc_temp[7:0]),
        .crc32_lut(crc_lut)
    );
    

    always@(posedge clk)begin
        if(rst )begin
            crc_temp <= 32'hffffffff;//0;//
            dv_crc   <= 0;
        end 
        else if(~dv_reg)begin
            crc_temp <= {8'hff,crc_temp[31:8]};// crc_temp>> 8;//
            //根据crc32算法要求，idle的crc应该是0xfffffff
            dv_crc   <= dv_crc >> 1; 
            //crc数据valid，当输入数据invalid开始输出crc数据并同时逐渐移出crc 的valid
        end
        else begin
            crc_temp <= crc_temp>>8 ^ crc_lut;
            dv_crc   <= 4'hf;
        end
    end
    reg [7:0]gmii_data_out;
    reg gmii_dv_out;
    always @(posedge clk)begin
        if(rst)begin
            gmii_data_out <= 0;
            gmii_dv_out   <= 0;
        end
        gmii_data_out <= dv_reg ? data_reg : ~crc_temp[7:0];  //输出数据缓冲
        gmii_dv_out   <= dv_reg ? 1'b1 : dv_crc[0];           
    end
//    assign gmii_data_out = gmii_dv_in ? data_reg : crc_temp[7:0];
//    assign gmii_dv_out   = gmii_dv_in ? 1'b1 : dv_reg[0];
    
endmodule

module crc32_lut_mod(
    input   [7:0]data,
    output  [31:0]crc32_lut
    );

//    reg [31:0] bits[0:7];
    wire [31:0] bits[0:7];
//    initial begin
        assign bits[0] = 32'h77073096;// 32'h04C11DB7;// 
        assign bits[1] = 32'hee0e612c;// 32'h09823b6e;// 
        assign bits[2] = 32'h076dc419;// 32'h130476dc;// 
        assign bits[3] = 32'h0edb8832;// 32'h2608edb8;// 
        assign bits[4] = 32'h1db71064;// 32'h4c11db70;// 
        assign bits[5] = 32'h3b6e20c8;// 32'h9823b6e0;// 
        assign bits[6] = 32'h76dc4190;// 32'h34867077;// 
        assign bits[7] = 32'hedb88320;// 32'h690ce0ee;// 
//    end
//以上为8'b0000_0001，8'b0000_0010 ... 8'b1000_0000的对应crc表值
//根据crc的异或特性，由以下生成完整crc表，相比纯查表法不需要额外初始化memory文件
//或者在Verilog中引入256个memory值
//相比纯代码降低了代码复杂度和代码量
//
    assign crc32_lut = {32{data[0]}}&bits[0] ^
                       {32{data[1]}}&bits[1] ^
                       {32{data[2]}}&bits[2] ^
                       {32{data[3]}}&bits[3] ^
                       {32{data[4]}}&bits[4] ^
                       {32{data[5]}}&bits[5] ^
                       {32{data[6]}}&bits[6] ^
                       {32{data[7]}}&bits[7] ;
endmodule
