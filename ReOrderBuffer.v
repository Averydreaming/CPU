`include "map_op.v"
//每个周期 从 decoder 读入一条指令，进行rename
//处理 LSB/RS 改变产生的影响
//每个周期 commit 一条指令
module ReOrderBuffer (
    input  wire              clk,
    input  wire              rst,
    input  wire              rdy,

    //完善decoder指令信息, 每个周期 从 decoder 读入一条指令，进行rename
    input  wire [3:0]     rs1_ROB_pos,
    input  wire [3:0]     rs2_ROB_pos, // rs1，rs2 对应的 ROB 编号

    output wire           rs1_ready,
    output wire           rs2_ready,// rs1，rs2拿到值为 1,否则为0。
    output wire [31:0]    reg1,// 两个寄存器的值，若没拿到真正的值，则为 ROB 编号
    output wire [31:0]    reg2,

    output wire           ROB_full,
    output reg  [3:0]     front,
    output reg  [3:0]     rear,

    //每个周期 commit 一条指令
    output wire           commit_valid,// to RegFile 是否 commit 了一条指令写寄存器
    output wire [3:0]     commit_ROB_pos,
    output wire [4:0]     commit_rd,
    output wire [31:0]    new_val,
    output wire           update_ROB_valid,// to RegFile 新的指令写入寄存器
    output wire [3:0]     update_ROB_pos,
    output wire [4:0]     update_ROB_rd,

    //处理 RS/LSB 改变产生的影响
    input  wire            RS_update,                              
    input  wire [3:0]      RS_ROB_pos,                                 
    input  wire [31:0]     RS_val,
    input  wire            LSB_update,
    input  wire [3:0]      LSB_ROB_pos,
    input  wire [31:0]     LSB_val,

    // 每个周期 从 decoder 读入一条指令，放到ROB
    input  wire           instr_valid
    input  wire [4:0]     rd,  // 目标寄存器
    input  wire [5:0]     opcode_ID,  // opcode_ID

);


    reg             full;                                               // ROB 是否已满
    reg  [4:0]     sz;  //当前存储多少条指令
    reg  [15:0]    ready; // 是否可以 commit
    reg  [31:0]    val         [15:0];// ROB 中储存的值
    reg  [4:0]     dest        [15:0];// 目标寄存器的编号
    reg  [5:0]     inst        [15:0];// 保存的指令

    assign ROB_full = ready[front] ? (full && ins_flag)  : (full || (ins_flag && (front == (-(~rear)))));

    //update reg(每个周期有一条指令进入ROB)
    assign update_ROB_valid= instr_valid ? (rd != 0) : 0;
    assign update_ROB_pos = rear;
    assign update_rd = rd;

    //update reg（每个周期有一条commit一条指令）
    assign commit_flag = (ROB_full || front != rear) && ready[front];//not null and ready
    assign commit_ROB_pos = front;
    assign commit_dest = dest[front];
    assign commit_value = value[front];

    //每个周期 从 decoder 读入一条指令，进行rename 完善指令信息
    assign rs1_ready= ready[rs1_ROB_pos];
    assign rs2_ready= ready[rs2_ROB_pos];
    assign reg1 = ready[rs1_ROB_pos] ? value[rs1_ROB_pos] : rs1_ROB_pos;
    assign reg2 = ready[rs2_ROB_pos] ? value[rs2_ROB_pos] : rs2_ROB_pos;
always @(posedge clk) begin

        if (!rst and ready)
            begin
            if (ready[front]) ROB_full <= (ROB_full && instr_valid); else  ROB_full <=(ROB_full || (instr_valid && (front == (-(~rear)))));

            //每个周期 从 decoder 读入一条指令，放到ROB
            if (instr_valid) begin
                rear <= -(~rear);
                ready[rear] <= (opcode_ID == `SB || opcode_ID == `SH || opcode_ID == `SW || opcode_ID == `JAL || opcode_ID == `LUI || opcode_ID == `AUIPC);
                value[rear] <= pc;
                dest[rear]  <= rd
                inst[rear] <= opcode_ID;
            end

            if (full || front != rear)
                if (ready[front]) begin
                    front <= -(~front);
             end
            //处理 LSB/RS 改变产生的影响
            if (RS_update) begin
                ready[LSB_ROB_pos] <= `True;
                value[LSB_ROB_pos] <= LSB_val;
            end

            if (LSB_update) begin
                ready[LSB_ROB_pos] <= `True;
                value[LSB_ROB_pos] <= LSB_val;
            end
        end
    end

endmodule