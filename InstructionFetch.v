`include "opcode.v"
//拿出一条指令执行Decoder
//处理出下一条指令的位置（pc）
/*
    if(IQ.size==32)return;
    unsigned x1=get_pc_Num(pc);
	Order order=Instruction_Decode(x1);
	if(order.o==END){next_fle=1;return;}
	Insturction_Queue_node x;
	x.inst=x1,x.o=order.o,x.pc=pc;
	if(judge_order(order.o)==3 && order.o!=JAL && order.o!=JALR)
	{ x.jumppc=pc+order.imm; if(BranchJudge(x.inst&0xfff))x.isjump=1; else x.isjump=0;}
	next_IQ.rear=(IQ.rear+1)%32;
	next_IQ.l[next_IQ.rear]=x;
	next_IQ.size++;
	if(judge_order(order.o)!=3){ next_pc=pc+4; return;}
	if(judge_order(order.o)==3){
		if(order.o==JAL) {next_pc=pc+order.imm; return;}
		if(order.o==JALR) {next_pc=pc+4; return;}
		if(BranchJudge(x.inst&0xfff))next_pc=pc+order.imm;else next_pc=pc+4;
	}
*/
module InstructionFetch (
    input  wire              clk,
    input  wire              rst,
    input  wire              rdy,
    //从ICache 拿出一条指令执行Decoder
    input  wire             Instr_valid,
    input  wire [31: 0]     Instr,
    input                   Decoder_not_ready_accept,  // Decoder上一条指令是否已经执行完成

    output wire             Instr_valid_Decoder,
    output wire [31: 0]     Instr_Decoder,
    output wire             Instr_isjump,//TO SB 1 +imm 0 +4
    output reg  [31: 0]     Instr_jump_wrong_to_pc,

    //处理出下一条指令的位置（pc）向ICache读取
    output reg  [31: 0]     next_pc

    //处理分支预测错误时的情况
     input  wire            jump_wrong,
     input  wire [31: 0]    jump_wrong_to_pc,
     input  wire            SB_commit,

);
    wire [ 6: 0]    opcode=instr[6:0];
    reg  [31: 0]    imm;
    reg  [31: 0]    pc;
    reg  [ 1: 0]    BHT [4095:0];
    reg  [ 11:0]    jumppc [15:0];
    interger i;
    interger x;
    always @(*) begin
        Instr_valid_Decoder=Instr_valid;
        Instr_Decoder=Instr;
    end
    always @(*) begin
        imm = (op==7'd23)? {Instr[31:12], 12'b0} : (op==7'd55) ? {Instr[31:12], 12'b0}  : (op==7'd103)?{{20{Instr[31]}}, Instr[31:20]}   :    (op==7'd111) ? {{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21]} << 1   :   {{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8]} << 1   ;
    end
    always @(*) begin
           x=jumppc[head];
    end
    always @(*) begin
        if (!Instr_valid ||  Decoder_not_ready_accept) begin
            next_pc=pc; Instr_isjump=0; Instr_jump_pc=pc;
        end else begin
            next_pc=pc+4; Instr_isjump=0; Instr_jump_wrong_to_pc=pc+4;
            if (opcode==`opcode_JAL || (opcode==`opcode_SB && BHT[pc[13:2]][1])) next_pc=pc+imm;    
            if (opcode==`opcode_SB  && BHT[pc[13:2]][1])  begin Instr_isjump=1; Instr_jump_wrong_to_pc=pc+4; end
            if (opcode==`opcode_SB  && !BHT[pc[13:2]][1]) begin Instr_isjump=0; Instr_jump_wrong_to_pc=pc+imm; end
        end
    end
    
    always @(posedge clk) begin
        if (rst) begin
            pc<=0;
            head<=0;
            tail<=0;
            for (i=0;i<4096; i=i+1) BHT[i]<=1;
        end else if (rdy) begin
            if (jump_wrong) begin
                 pc<=jump_pc;
                 head<=0;
                 tail<=0;
                 if (SB_commit) begin
                    if(BHT[x][0]==0&&BHT[x][1]==0)begin BHT[x][0]<=0; BHT[x][1]<=1; end
                    if(BHT[x][0]==0&&BHT[x][1]==1)begin BHT[x][0]<=1; BHT[x][1]<=0; end
                    if(BHT[x][0]==1&&BHT[x][1]==0)begin BHT[x][0]<=0; BHT[x][1]<=1; end
                    if(BHT[x][0]==1&&BHT[x][1]==1)begin BHT[x][0]<=1; BHT[x][1]<=0; end
                 end
            end 
            if (!jump_wrong) begin
                if (!Decoder_not_ready_accept && Instr_valid) begin
                    if (opcode==`opcode_JAL || (opcode==`opcode_SB && BHT[pc[13:2]][1])) pc<=pc+imm; else pc<=pc+4;
                    if (opcode==`opcode_SB) begin  tail<=-(~tail);  jumppc[tail] <= pc[13:2]; end
                end
                 if (SB_commit) begin
                    head<=-(~head);
                    if(BHT[x][0]==0&&BHT[x][1]==0)begin BHT[x][0]<=0; BHT[x][1]<=0; end
                    if(BHT[x][0]==0&&BHT[x][1]==1)begin BHT[x][0]<=0; BHT[x][1]<=0; end
                    if(BHT[x][0]==1&&BHT[x][1]==0)begin BHT[x][0]<=1; BHT[x][1]<=1; end
                    if(BHT[x][0]==1&&BHT[x][1]==1)begin BHT[x][0]<=1; BHT[x][1]<=1; end
                 end
            end 
        end
    end

endmodule