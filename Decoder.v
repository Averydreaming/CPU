`include "op_map.v"
//相当于PPCA decoder+instruction send
module Decoder (
    input  wire             clk, rst, rdy, 

    // decoder
    //每一周期从IF取一条指令，并在处理完后传到数据总线（CDB）上
    input  wire             update_instr_valid, 
    input  wire [31:0]     update_instr, 
 
    output wire             Decoder_not_ready_accept, 
    input  wire             ROB_full, LSB_full,  
    // RegFile
    input  wire [31:0]     RS_rs1,RS_rs2, 
    input  wire            RS_rs1_ready,RS_rs2_ready, 
    input  wire            RS_rs1_ROB_pos,RS_rs2_ROB_pos,
    //ROB
    input  wire [31: 0]     ROB_rs1,ROB_rs2, 
    input  wire             ROB_rs1_ready, ROB_rs2_ready_ROB, 
    //to CDB
    output reg  [4:0]      rd, 
    output reg  [4:0]      rs1, rs2, 
    output reg  [5:0]      opcode_id, 
    output wire            rs1_ready, rs2_ready, 
    output wire [31:0]     reg1,reg2, 
    output reg  [31:0]     imm, 
 
    //update
    output reg              update_LSB, 
    output reg              update_ROB, 
    output reg              update_RS
);
    assign Decoder_not_ready_accept= ROB_full | LSB_full;
    reg  [31: 0]    instr;
    assign insty_LSB = instr[2:0];
    wire instr_valid;
    wire [6:0]   op=instr[6:0];
    wire [2:0]   op1=instr[14:12];
    wire [6:0]   op2=instr[31:25];
    always @(*) begin
        if (instr_valid) begin
            rd=instr[11:7];
            rs1=instr[19:15];
            rs2=instr[24:20];
            if (op==7b0000011)   //Il
            begin
                case (op1)
                    3b000: opcode_id=`LB;
                    3b001: opcode_id=`LH;
                    3b010: opcode_id=`LW;
                    3b100: opcode_id=`LBU;
                    3b101: opcode_id=`LHU;
                endcase
                imm=(instr>>20);
                if(imm>>11)imm|=0xfffff000;
            end
            if (op==7b0010011)   //Io1
            begin
                case (op1)
                    3b000: opcode_id=`ADDI;
                    3b001: opcode_id=`SLLI;
                    3b010: opcode_id=`SLTI;
                    3b011: opcode_id=`SLTIU;
                    3b100: opcode_id=`XORI;
                    3b101: if (op2==0) opcode_id=`SRLI; else opcode_id=`SRAI;
                    3b110: opcode_id=`ORI;
                    3b111: opcode_id=`ANDI;
                endcase
                imm=(instr>>20);
                if ((op1!=3b101 && op1!=3b001)&& (imm>>11))imm|=0xfffff000;
            end
            if (op==7b1100011)
            begin
                case (op1)
                    3b000: opcode_id=`BEQ;
                    3b001: opcode_id=`BNE;
                    3b100: opcode_id=`BLT;
                    3b101: opcode_id=`BGE;
                    3b110: opcode_id=`BLTU;
                    3b111: opcode_id=`BGEU;
                endcase
                imm=(((instr>>7)&0x1)<<11) | (((instr>>8)&0xf)<<1) | (((instr>>25)&0x3f)<<5)  | (((instr>>31)&1)<<12);
                if(imm>>12)imm|=0xffffe000;
            end
            if (op==7b0110011)   //R1
            begin
                case (op1)
                    3b000: if(op2==0) opcode_id=`ADD; else opcode_id=`SUB;
                    3b001: opcode_id=`SLL;
                    3b010: opcode_id=`SLT;
                    3b011: opcode_id=`SLTU;
                    3b100: opcode_id=`XOR;
                    3b101: if (op2==3b0000000) opcode_id=`SRL; else opcode_id=`SRA;
                    3b110: opcode_id=`OR;
                    3b111: opcode_id=`AND;
                endcase
            end
            if (op==7b0010111)   begin opcode_id=`AUIPC;imm=(instr>>12)<<12;end
            if (op==7b0110111)   begin opcode_id=`LUI; imm=(instr>>12)<<12;end
            if (op==7b1101111)
            begin
                opcode_id=`JAL;
                imm=(((instr>>12)&0xff)<<12) | (((instr>>20)&0x1)<<11) | (((instr>>21)&0x3ff)<<1)  | (((instr>>31)&1)<<20);
                if(imm>>20)imm|=0xfff00000;
            end
            if (op==7b1100111)   begin 
                opcode_id=`JALR; imm=(instr>>20);	
                if(imm>>11)imm|=0xfffff000;
            end
            if (op==7b0100011)   begin
                case (op1)
                    3b000: opcode_id=`SB;
                    3b001: opcode_id=`SH;
                    3b010: opcode_id=`SW;
                endcase
                imm=((instr>>25)<<5) | ((instr>>7)&31);
                if(imm>>11)imm|=0xfffff000;
            end
            if (opcode_id==`LUI||opcode_id==`AUIPC||opcode_id==`ADD||opcode_id==`SUB||opcode_id==`SLL||opcode_id==`SLT||opcode_id==`SLTU||opcode_id==`opcode_idOR||opcode_id==`SRL||opcode_id==`SRA||opcode_id==`OR||opcode_id==`AND||opcode_id==`ADDI||opcode_id==`SLTI||opcode_id==`SLTIU||opcode_id==`opcode_idORI||opcode_id==`ORI||opcode_id==`ANDI||opcode_id==`SLLI||opcode_id==`SRLI||opcode_id==`SRAI) begin update_LSB=0; update_RS=1; end
            if (opcode_id==`LB||opcode_id==`LH||opcode_id==`LW||opcode_id==`LBU||opcode_id==`LHU) begin update_LSB=1; update_RS=0; end
            if (opcode_id==`SB||opcode_id==`SH||opcode_id==`SW) begin update_LSB=1; update_RS=0; end
            if (opcode_id==`BEQ||opcode_id==`BNE||opcode_id==`BLT||opcode_id==`BGE||opcode_id==`BLTU||opcode_id==`BGEU||opcode_id==`JAL||opcode_id==`JALR) begin update_LSB=0; update_RS=1; end
  
        end
        else begin
            rd = 0;
            rs1 = 0;
            rs2 = 0;
            opcode = 0;
            imm = 0;
            update_LSB = 0;
            update_RS = 0;
        end
    if (RS_rs1_ready) rs1_ready=1; else rs1_ready=ROB_rs1_ready;
    if (RS_rs1_ready) rs1=RS_rs1; else rs1=ROB_rs1;
    if (RS_rs2_ready) rs2_ready=1; else rs2_ready=ROB_rs2_ready;
    if (RS_rs2_ready) rs2=RS_rs2; else rs2=ROB_rs2;
    end
    always @(posedge clk) begin

        if (rst || !update_instr_valid || ROB_full || LSB_full) begin
            instr <= 0;
            instr_valid <= 0;
            update_ROB  <=0;
        end
        else begin
            instr <= update_instr;
            instr_valid <= 1;
            update_ROB  <=1;
        end
    end
    
endmodule