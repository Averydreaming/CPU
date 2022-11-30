`include "op_map.v"
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
module IF (
    input  wire             clk, rst, rdy, 
    //拿出一条指令执行Decoder
    input  wire             IC_Instr_valid, 
    input  wire [31: 0]     IC_Instr, 
   
    output wire             Instr_ID_valid, 
    output wire [31: 0]     Instr_ID, 
    // Decoder上一条指令是否已经执行完成
    input                   Decoder_not_ready_accept,
     //处理出下一条指令的位置（pc）
    output reg  [31: 0]     next_pc
    
);
    reg  [31: 0]    imm;
    assign imm = (op==7'd23)? {Instr[31:12], 12'b0}   :   (op==7'd55)?{Instr[31:12], 12'b0}   :   (op==7'd103)?{{20{Instr[31]}}, Instr[31:20]}   :    (op==7'd111) ? {{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21]} << 1   :   {{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8]} << 1   ;
    reg  [31: 0]    pc;
    assign Instr_ID_valid= IC_Instr_valid;
    assign Instr_ID =IC_Instr;

    always @(*) begin
        if (!IC_Instr_valid ||  Decoder_ready_accept) begin
            next_pc = pc;
        end
        else begin
            case (op)
                7'd99   : begin
                    next_pc = pc + imm;
                end
                7'd111   : begin
                    next_pc = pc + imm;
                end
                7'd103    : begin
                    next_pc = pc + 4;
                end
                7'd55     : begin
                    next_pc = pc + 4;
                end
                default    :  begin
                    next_pc = pc + 4;
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'b0;
        end 
        else if (IC_Instr_valid) begin
            case (op)
                7'd99       : pc <= pc + imm;
                7'd111      : pc <= pc + imm;
                default     : pc <= pc + 4;
            endcase
        end
    end

endmodule