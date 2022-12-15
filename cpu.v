// RISCV32I CPU top module
// port modification allowed for debugging purposes
`include "op_map.v"
module cpu(
    input  wire                 clk_in,			// system clock signal
    input  wire                 rst_in,			// reset signal
    input  wire					rdy_in,			// ready signal, pause cpu when low

    input  wire [ 7:0]          mem_din,		// data input bus
    output wire [ 7:0]          mem_dout,		// data output bus
    output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
    output wire                 mem_wr,			// write/read signal (1 for write)

	input  wire                 io_buffer_full, // 1 if uart buffer is full

	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)


wire ICache_can_read_from_MemCtrl;
wire[31: 0] ICache_address_MemCtrl;
wire  MemCtrl_output_instr_valid_ICache;
wire[31: 0] Memctrl_output_instr_ICache;
wire[31: 0] IF_pc_ICache;
wire ICache_Instr_valid_IF;
wire[31: 0] ICache_Instr_IF;
MemCtrl MemCtrl (

    .clk                            ( clk_in ),
    .rst                            ( rst_in ),
    .rdy                            ( rdy_in ),
    // RAM
    .io_buffer_full                 ( io_buffer_full ),
    .mem_din,                       ( mem_din ),
    .mem_dout,                      ( mem_dout ),
    .mem_a                          ( mem_a ),
    .mem_wr              // write

    // 读入一条指令 到ICache
    .update_ICache                  ( ICache_can_read_from_MemCtrl ),//是否有空间读入指令
    .ICache_address                 ( ICache_address_MemCtrl),
    .ICache_complete                ( MemCtrl_output_instr_valid_ICache ),
    .ICache_value                   ( MemCtrl_output_instr_ICache ),

    //上一周期的LSB发出的请求 这一周期需要处理的指令
    input  wire             update_LSB,//是否有指令等待这一周期处理
    input  wire             update_LSB_Load,//是否有Load指令等待这一周期处理
    input  wire             update_LSB_Store,//是否有Store指令等待这一周期处理
    input  wire [31: 0]     update_LSB_value,
    input  wire [ 2: 0]     update_LSB_opcode_ID,
    input  wire [31: 0]     update_LSB_address,
    output reg              LSB_complete,
    output reg  [31: 0]     LSB_out_value,

);

ICache ICache (
    .clk                            (clk_in),
    .rst                            (rst_in),
    .rdy                            (rdy_in),
     //每一个周期从内存拿一条指令 from Memctrl
    .ICache_need_update_instr       (ICache_need_read_from_MemCtrl),//可以输入一条指令
    .instr_address                  (ICache_address_MemCtrl),
    .instr_valid                    (MemCtrl_output_instr_valid_ICache),//存在输入
    .instr                          (MemCtrl_output_instr_ICache),

     //每一个周期将一条IF pc需要的指令拿去InstructionFetch处理
     .pc                            (IF_output_pc_to_ICache),//从InstructionFetch获取的next周期需要的instr的pc
     .instr_IF_valid,               (ICache_Instr_valid_IF),
     .instr_IF                      (ICache_Instr_IF),

     .jump_wrong                    (jump_wrong_from_ROB),
);

InstructionFetch InstructionFetch (
    .clk                             ( clk_in ),
    .rst                             ( rst_in ),
    .rdy                             ( rdy_in ),
    //从ICache 拿出一条指令执行Decoder
    .Instr_valid    (ICache_Instr_valid_IF),
    .Instr          (ICache_Instr_IF),
    .Decoder_not_ready_accept  (Decoder_not_ready_accept_from_InstructionFetch),  // Decoder上一条指令是否已经执行完成

    .Instr_valid_Decoder     (IF_output_Instr_valid_to_Decoder),
    .Instr_Decoder           (IF_output_Instr_to_Decoder),
    .Instr_isjump            (IF_output_Instr_isjump_to_Decoder),//TO SB 1 +imm 0 +4
    .Instr_jump_wrong_to_pc  (IF_output_Instr_jump_wrong_to_Decoder),

    //处理出下一条指令的位置（pc）向ICache读取
    output reg  [31: 0]     next_pc(IF_output_pc_to_ICache),

    //处理分支预测错误时的情况
    input  wire            jump_wrong,
    input  wire [31: 0]    jump_wrong_to_pc,
    input  wire            SB_commit,

);

Decoder Decoder (
    .clk                            ( clk_in ),
    .rst                            ( rst_in ),
    .rdy                            ( rdy_in ),
    .Decoder_not_ready_accept (Decoder_not_ready_accept_from_InstructionFetch),
    .ROB_full (ReOrderBuffer_full),
    .LSB_full (LoadStoreBuffer_full),
    // decoder
    //每一周期从IF取一条指令，并在处理完后传到数据总线（CDB）上
    .update_instr_valid             (IF_output_Instr_valid_to_Decoder),
    .update_instr                   (IF_output_Instr_to_Decoder),
    .update_instr_isjump            (IF_output_Instr_isjump_to_Decoder),//TO SB 1 +imm 0 +4
    .update_instr_jump_wrong_to_pc  (IF_output_Instr_jump_wrong_to_Decoder),
    .Decoder_not_ready_accept       (Decoder_not_ready_accept_from_InstructionFetch),


    .Reg_rs1(Decoder_output_rs1_to_RegFile), //输出寄存器地址 来查找位置from RegFile 用来处理这条指令的vj vk qj qk
    .Reg_rs2(Decoder_output_rs2_to_RegFile),
    .Reg_rs1_ready(RegFile_output_rs1_ready_to_Decoder),
    .Reg_rs2_ready(RegFile_output_rs2_ready_to_Decoder),
    .Reg_reg1(RegFile_output_rs2_ready_to_Decoder),
    .Reg_reg2(RegFile_output_reg2_to_Decoder),

    .ROB_rs1_ready(ROB_output_rs1_ready_to_Decoder),
    .ROB_rs2_ready(ROB_output_rs2_ready_to_Decoder),
    .ROB_reg1(ROB_output_reg1_to_Decoder),
    .ROB_reg2(ROB_output_reg2_to_Decoder),


     //to CDB CDB会把数据传送给LSB ROB RS
    .rd(Decoder_output_rd_to_CDB),
    .opcode_id(Decoder_output_opcode_id_to_CDB),
    .rs1_ready(Decoder_output_rs1_ready_to_CDB),
    .rs2_ready(Decoder_output_rs2_ready_to_CDB), //代表寄存器目前是否有值
    .reg1(Decoder_output_reg1_to_CDB),
    .reg2(Decoder_output_reg2_to_CDB), //代表寄存器的值
    .imm(Decoder_output_imm_to_CDB),


    .Decoder_update_LSB(Decoder_update_LoadStoreBuffer),  // 本次指令是否会更新其他容器
    .Decoder_update_ROB(Decoder_update_ReOrderBuffer),
    .Decoder_update_RS(Decoder_update_ReservationStation),
);

module ReOrderBuffer (
      .clk (clk_in),
      .rst (rst_in),
      .rdy (rdy_in),

        //完善decoder指令信息, 每个周期 从 decoder 读入一条指令，进行rename
      .rs1_ROB_pos(RegFile_output_reg1_ROB_pos_to_ROB),
      .rs2_ROB_pos(RegFile_output_reg2_ROB_pos_to_ROB),

      .ROB_full(ReOrderBuffer_full),
      .rs1_ready(ROB_output_rs1_ready_to_Decoder),// rs1，rs2拿到值为 1,否则为0。
      .rs2_ready(ROB_output_rs2_ready_to_Decoder),
      .reg1(ROB_output_reg1_to_Decoder),// 两个寄存器的值，若没拿到真正的值，则为 ROB 编号
      .reg2(ROB_output_reg2_to_Decoder),

       //每个周期 commit 一条指令
      .commit_valid(ReOrderBuffer_commit_valid_to_RegFile),// to RegFile 是否 commit 了一条指令写寄存器
      .commit_ROB_pos(ReOrderBuffer_commit_ROB_pos_to_RegFile),
      .commit_rd(ReOrderBuffer_commit_rd_to_RegFile),
      .commit_val(ReOrderBuffer_commit_val_to_RegFile),
      .update_ROB_valid(ReOrderBuffer_update_valid_to_RegFile),// to RegFile 新的指令写入寄存器
      .update_ROB_pos(ReOrderBuffer_update_ROB_pos_to_RegFile),
      .update_ROB_rd(ReOrderBuffer_update_rd_to_RegFile),


       // 每个周期 从 decoder 读入一条指令，放到ROB
       .instr_valid(Decoder_update_ReOrderBuffer),
       .rd(Decoder_output_rd_to_CDB),  // 目标寄存器
       .opcode_ID (Decoder_output_opcode_id_to_CDB),  // opcode_ID

);
RegFile RegFile (
    .clk  ( clk_in ),
    .rst  ( rst_in ),
    .rdy  ( rdy_in ),
//一个周期处理一次 decoder里 （rd代表在reg中编号）知道rd 返回reg状态 (通过CDB传递)
    .rs1  (Decoder_output_rs1_to_RegFile),//rs代表地址  reg代表值或者ROB_pos
    .rs2  (Decoder_output_rs2_to_RegFile),
    .rs1_ready (RegFile_output_rs1_ready_to_Decoder),
    .rs2_ready (RegFile_output_rs2_ready_to_Decoder),
    .reg1(RegFile_output_reg1_to_Decoder),
    .reg2(RegFile_output_reg2_to_Decoder),

    .reg1_reorder_ROB_pos(RegFile_output_reg1_ROB_pos_to_ROB), //to ROB
    .reg2_reorder_ROB_pos(RegFile_output_reg2_ROB_pos_to_ROB),

//一个周期处理 ROB一次 commit
    .commit_valid(ReOrderBuffer_commit_valid_to_RegFile),// to RegFile 是否 commit 了一条指令写寄存器
    .commit_ROB_pos(ReOrderBuffer_commit_ROB_pos_to_RegFile),
    .commit_rd(ReOrderBuffer_commit_rd_to_RegFile),
    .commit_val(ReOrderBuffer_commit_val_to_RegFile),
//一个周期处理一条指令进入ROB （update）
    .update_ROB_valid(ReOrderBuffer_update_valid_to_RegFile),// to RegFile 新的指令写入寄存器
    .update_ROB_pos(ReOrderBuffer_update_ROB_pos_to_RegFile),
    .update_ROB_rd(ReOrderBuffer_update_rd_to_RegFile),

);





module LoadStoreBuffer(
    .clk( clk_in ),
    .rst( rst_in ),
    .rdy( rdy_in ),
    // 这一周期需要处理的指令 from decorder
    .update_Decoder_valid (Decoder_update_LoadStoreBuffer),
    .opcode_id(Decoder_output_opcode_id_to_CDB),
    .rs1_ready(Decoder_output_rs1_ready_to_CDB),
    .rs2_ready(Decoder_output_rs2_ready_to_CDB),
    .reg1(Decoder_output_reg1_to_CDB),
    .reg2(Decoder_output_reg2_to_CDB),
    .imm(Decoder_output_imm_to_CDB),

    .ROB_pos(ROB_tail), //from ROB  新指令在 ROB 中的编号

   

    // 其他容器在上一周期是否发来更新
    //from RS
    .update_RS_valid(ALU_instr_valid_to_CDB),
    .update_RS_ROB_pos(ALU_ROB_pos_to_CDB),
    .update_RS_val(ALU_val_to_CDB),
    //from LSB
    input  wire           update_LSB_valid,
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
module ReservationStation(
    .clk                            ( clk_in ),
    .rst                            ( rst_in ),
    .rdy                            ( rdy_in ),
    // 每个周期读入一条指令from decoder
    .update_Decoder_valid(Decoder_update_ReservationStation),                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               // reg1，reg2，imm 的值，如果 reg1，reg2 没拿到真值，则为 ROB 编号

    .opcode_id(Decoder_output_opcode_id_to_CDB),
    .rs1_ready(Decoder_output_rs1_ready_to_CDB),
    .rs2_ready(Decoder_output_rs2_ready_to_CDB), //代表寄存器目前是否有值
    .reg1(Decoder_output_reg1_to_CDB),
    .reg2(Decoder_output_reg2_to_CDB), //代表寄存器的值
    .imm(Decoder_output_imm_to_CDB),
    //from ROB  新指令在 ROB 中的编号
    .ROB_pos(ROB_tail),

    //每个周期calc一条指令，将计算出来的值传到CDB
    .ex_instr_valid(ReservationStation_ex_instr_valid),
    .ex_opcode_id(ReservationStation_ex_opcode_id),
    .ex_vj(ReservationStation_ex_vj),
    .ex_vk(ReservationStation_ex_vk),
    .ex_A(ReservationStation_ex_A),
    .ex_ROB_pos(ReservationStation_ex_ROB_pos);

    // 其他容器在上一周期是否发来更新
    input  wire           update_RS_valid(ALU_instr_valid_to_CDB),         //from RS_CDB
    input  wire [3:0]     update_RS_ROB_pos(ALU_ROB_pos_to_CDB),
    input  wire [31:0]    update_RS_val(ALU_val_to_CDB),
        //from LSB
    input  wire           update_LSB_valid,
    input  wire [3:0]     update_LSB_ROB_pos,
    input  wire [31:0]    update_LSB_val,

);
ALU ALU(
    .clk  ( clk_in ),
    .rst  ( rst_in ),
    .rdy  ( rdy_in ),

    //from RS
    .instr_valid(ReservationStation_ex_instr_valid),
    .opcode_id(ReservationStation_ex_opcode_id),
    .vj(ReservationStation_ex_vj),
    .vk(ReservationStation_ex_vk),
    .A(ReservationStation_ex_A),
    .ROB_pos(ReservationStation_ex_ROB_pos),

    //to CDB
    .ALU_instr_valid (ALU_instr_valid_to_CDB),
    .ALU_ROB_pos  (ALU_ROB_pos_to_CDB),
    .ALU_val (ALU_val_to_CDB),

);

endmodule;
