`include "op_map.v"
//1、每个周期calc一条指令
//2、每个周期读入一条指令
module LoadStoreBuffer(
    input  wire             clk, rst, rdy,
    // 这一周期需要处理的指令 from decoder
    input  wire            update_Decoder_valid,//是否需要处理

    input  wire [5:0]      opcode_ID, //From IF
    input  wire            reg1_ready,
    input  wire            reg2_ready,
    input  wire [31:0]     reg1,//不存在就显示在ROB中的编号
    input  wire [31:0]     reg2,
    input  wire [31:0]     imm,
    input  wire [3:0]      ROB_pos, //from ROB  新指令在 ROB 中的编号

    // 其他容器在上一周期是否发来更新
    input  wire           update_RS_valid,//from RS
    input  wire [3:0]     update_RS_ROB_pos,
    input  wire [31:0]    update_RS_val,
    input  wire           update_LSB_valid,//from LSB
    input  wire [3:0]     update_LSB_ROB_pos,
    input  wire [31:0]    update_LSB_val,



    //memctrl有空时执行一条指令
    input wire memctrl_could_update
    //load
    output wire             update_Load,
    output wire [ 2: 0]     Load_opcode_ID,
    output wire [31: 0]     Load_mem_address,
    input wire [31: 0]      Load_value,
    //store
    output wire             update_Store,
    output wire [ 2: 0]     Store_opcode_ID,
    input wire [31: 0]      Store_value,

);
    input  wire [5:0]      update_opcode_id,
    input  wire            update_reg1_ready,
    input  wire            update_reg2_ready,
    input  wire [31:0]     update_reg1,
    input  wire [31:0]     update_reg2,
    input  wire [31:0]     update_imm,
    input  wire [3:0]      update_ROB_pos,

    reg  [5:0]     LSB_opcode_id;        [31:0];
    reg  [31:0]    LSB_rs1,LSB_rs2;      [31:0];
    reg  [31:0]    LSB_rs1_ready,LSB_rs2_ready;
    reg  [31:0]    LSB_reg1,LSB_reg2;    [31:0];
    reg  [31:0]    LSB_imm               [31:0];
    reg  [3:0]     LSB_ROB_pos           [31:0];


    always @(*) begin
            update_opcode_id=opcode_id;
            update_reg1_ready=reg1_ready;
            update_reg2_ready=reg2_ready;
            update_reg1=reg1;
            update_reg2=reg2;
            update_imm=imm;
            update_ROB_pos=ROB_pos;
    end
    always @(*) begin
        if (update_RS_valid && !update_reg1_ready && update_reg1[3:0] == update_RS_ROB_pos) begin
            update_reg1[3:0]=update_RS_val; update_reg1_ready=1;
        end else if (update_LSB_valid && !update_reg1_ready && update_reg1[3:0] == update_LSB_ROB_pos) begin
            update_reg1[3:0]=update_LSB_val; update_reg1_ready=1;
        end


        if (update_RS_valid && !update_reg2_ready && update_reg2[3:0] == update_RS_ROB_pos) begin
            update_reg2[3:0]=update_RS_val; update_reg2_ready=1;
        end else if (update_LSB_valid && !update_reg2_ready && update_reg2[3:0] == update_LSB_ROB_pos) begin
            update_reg2[3:0]=update_LSB_val; update_reg2_ready=1;
        end
    end
    integer i;
    always @(posedge clk) begin
        //将这一周期的新指令放入下一周期的LSB
        if (rst)
        begin
            LSB_full <= 0;
            front<= 0;
            rear <= 0;
            LSB_rs1_ready<=0;
            LSB_rs2_ready<=0;
        end
        if (!rst && rdy)
        begin
            //输入decoder中的一条指令
            if (update_Decoder_valid) begin
                rear <= -(~rear);
                LSB_busy[rear]=1;
                LSB_opcode_ID[rear] <= update_opcode_id;
                LSB_rs1_ready[rear] <= update_reg1_ready;
                LSB_rs2_ready[rear] <= update_reg2_ready;
                LSB_ROB_pos[rear] <= update_ROB_pos;
                LSB_reg1[rear] <= update_reg1;
                LSB_reg2[rear] <= update_reg2;
                LSB_imm[rear]  <= update_imm;
            end
            //memctrl有空时执行一条指令
            if (memctrl_could_update)
            begin//Load

            //Store
            end

            //用这一周期计算完的指令更新下一周期的LSB
            for (i = 0; i < 32; i = i + 1)
            if (LSB_busy[i]) begin
                if (update_RS_valid && !LSB_rs1_ready[i] && LSB_reg1[i][3:0] == update_RS_ROB_pos) begin
                LSB_reg1[i] <= update_RS_val; LSB_rs1_ready[i] <= 1;
                end
                if (update_RS_valid && !LSB_rs2_ready[i] && LSB_reg2[i][3:0] == update_RS_ROB_pos) begin
                LSB_reg2[i] <= update_RS_val; LSB_rs2_ready[i] <= 1;
                end
                if (update_LSB_valid && !LSB_rs1_ready[i] && LSB_reg1[i][3:0] == update_LSB_ROB_pos) begin
                LSB_reg1[i] <= update_LSB_val; LSB_rs1_ready[i] <= 1;
                end
                if (update_LSB_valid && !LSB_rs2_ready[i] && LSB_reg2[i][3:0] == update_LSB_ROB_pos) begin
                LSB_reg2[i] <= update_LSB_val; LSB_rs2_ready[i] <= 1;
                end
            end
        end
    end

endmodule