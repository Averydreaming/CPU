`include "op_map.v"
//相当于 instruction queue
//每一个周期从内存拿一条指令
//每一个周期将一条指令拿去处理
module ICache (
    input  wire             clk, rst, rdy, 
    
    //每一个周期从内存拿一条指令 from Memctrl
    input  wire             instr_valid, 
    input  wire [31: 0]     instr,
    //每一个周期将当前需要的pc传给Memctrl
    //From IF to MC
    input  wire [31: 0]     pc, 
    output wire [31: 0]     pc_MC
    //每一个周期将一条指令拿去Instryction Fetch处理
    output reg              instr_IF_valid, 
    output reg  [31: 0]     instr_IF, 

);
    
  
    reg  [31: 0]    cache_IQ       [127 : 0];
    reg  [127: 0]   used_IQ;
    reg  [17:9]    tag         [127:0];//直接 cache[PC] 空间不够
   
    always @(posedge clk) begin
        if (rst) begin
            used_IQ <= 0;
            instr_IF_vaild <= 0;
        end
        else begin
        if (used[pc[8:2]] && tag[pc[8:2]] == pc[17:9]) begin
                instr_IF_valid <= 1;
                instr_IF <= cache_IQ[pc[8:2]];
            end
            else begin
                instr_IF_vaild <= instr_valid;
                instr_IF <= instr; 
            end
            if (instr_valid) begin
                used_IQ[pc[8:2]] <= 1;
                cache_IQ[pc[8:2]] <= instr;
            end
        end
    end

endmodule