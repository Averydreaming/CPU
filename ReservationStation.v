`include "op_map.v"
//1、每个周期calc一条指令
//2、每个周期读入一条指令
module ReservationStation(
    input  wire             clk, rst, rdy,                          
    // 这一周期需要处理的指令
    //from decoder
    input  wire            update_Decoder_valid,                                   // 指令是否有效
    //From IF
    input  wire [5:0]      update_opcode_id,                                       // 指令类型
    input  wire            update_reg1_ready, update_reg2_ready,                   // reg1，reg2 是否已经拿到值
    input  wire [31:0]     update_reg1,update_reg2,update_imm,                     // reg1，reg2，imm 的值，如果 reg1，reg2 没拿到真值，则为 ROB 编号
    //from ROB  新指令在 ROB 中的编号
    input  wire [3:0]      update_ROB_pos,
    // 其他容器在上一周期是否发来更新
    //from RS
    input  wire           update_RS_valid,                                
    input  wire [3:0]     update_RS_ROB_pos,                                 
    input  wire [31:0]    update_RS_val,                                     
    //from LSB
    input  wire           update_LSB_valid,
    input  wire [3:0]     update_LSB_ROB_pos,
    input  wire [31:0]    update_LSB_val,                                     

    // CDB
    output reg              val_flag,                                  
    output reg  [3:0]     val_idx,                                    
    output reg  [31:0]     val                                      

);

    reg  [5:0]     RS_opcode_id;        [31:0];                            
    reg  [31:0]    RS_busy;                                               
    reg  [31:0]    RS_vj,RS_vk;         [31:0];                           
    reg  [31:0]    RS_qj,RS_qk;
    reg  [31:0]    RS_imm              [31:0];
    reg  [3:0]     RS_ROB_pos          [31:0];                            
    wire   ex_valid;                                      
    assign ex_valid = ((~RS_busy) != 0);   

    wire [31:0]    ready_ex = RS_busy & RS_vj & RS_vk;
    reg  [5:0]     ex_pos; 
    reg  [5:0]     ex_opcode_id;                                         
    reg  [31:0]    ex_vj, ex_vk;
    reg  [3:0]     ex_ROB_pos;
    
    always @(*) begin
    //每个周期calc一条指令
        if (ready_ex==0) begin
            ex_opcode_id = 0;
            ex_v1 = 0; ex_v2 = 0;
            ex_ROB_pos = 0;
        end
        else 
        begin 
            for (i = 31; i >=0; i = i - 1)
                if (ready_ex[i])
                begin
                    ex_pos=i;
                end
            ex_opcode_id = RS_opcode_id[ex_pos];
            ex_vj = RS_vj[ex_pos];
            ex_vk = RS_vk[ex_pos];
            ex_ROB_pos = RS_ROB_pos[ex_pos];
        end
    end
    
    integer i;
    always @(posedge clk) begin
        //将这一周期的新指令放入下一周期的RS
        if (rst) begin busy <= 0;end
        if (!rst && rdy)
        begin
            if (update_Decoder_valid) begin
                for (i = 0; i < 31; i = i + 1)
                if (!RS_busy[i])
                begin
                    RS_busy[i] <= 1;
                    RS_opcode_id[i] <= update_opcode_id;
                    RS_ROB_pos[i] <= update_ROB_pos;
                    RS_vj[i] <= update_reg1;
                    RS_qj[i] <= update_reg1_ready;
    
                    if (opcode_id == `JALR || (!opcode_id[5] && !opcode_id[0] && opcode_id != `SUB)) begin //处理立即数
                        RS_imm[i] <= imm;
                        RS_vk[i] <= 0;
                        RS_qk[i] <=1;
                    end
                    else begin
                        RS_vk[i] <= update_reg2;
                        RS_imm[i] <= 0;
                        RS_qk[i] <= update_reg2_ready;
                    end    
                end
            end
             //用这一周期计算完的指令更新下一周期的RS
            busy[ex_pos]=1;
            for (i = 0; i < 32; i = i + 1)
            if (RS_busy[i]) begin
                if (update_RS_valid && !RS_qj[i] && RS_vj[i][3:0] == update_RS_ROB_pos) begin
                    RS_vj[i] <= update_RS_val; RS_qj[i] <= 1;
                    end
                if (update_RS_valid && !RS_qk[i] && RS_vk[i][3:0] == update_RS_ROB_pos) begin
                    RS_vk[i] <= update_RS_val; RS_qk[i] <= 1;
                    end
                if (update_LSB_valid && !RS_qj[i] && RS_vj[i][3:0] == update_LSB_ROB_pos) begin
                    RS_vj[i] <= update_LSB_val; RS_qj[i] <= 1;
                    end
                if (update_LSB_valid && !RS_qk[i] && RS_vk[i][3:0] == update_LSB_ROB_pos) begin
                    RS_vk[i] <= update_LSB_val; RS_qk[i] <= 1;
                    end
            end 
            else if (ready_ex && i==ex_pos) begin
                     if (update_RS_valid && !update_reg1_ready && update_reg1[3:0] == update_RS_ROB_pos) begin
                        RS_vj[i] <= update_RS_val; RS_qj[i] <= 1;
                     end
                     if (update_RS_valid && !update_reg2_ready && update_reg2[3:0] == update_RS_ROB_pos) begin
                        RS_vk[i] <= update_RS_val; RS_qk[i] <= 1;
                     end
                     if (update_LSB_valid && !update_reg1_ready && update_reg1[3:0] == update_LSB_ROB_pos) begin
                        RS_vj[i] <= update_LSB_val; RS_qj[i] <= 1;
                     end
                     if (update_LSB_valid && !update_reg2_ready && update_reg2[3:0] == update_LSB_ROB_pos) begin
                        RS_vk[i] <= update_LSB_val; RS_qk[i] <= 1;
                     end
            end
        end
    end

endmodule