`include "defines.v"

module ALU_CDB (
    input  wire             clk, rst, rdy, 
    //from RS
    input  wire             RS_valid,                                
    input  wire [5:0]       RS_opcode,                                      
    input  wire [31: 0]     RS_vj, RS_vk, RS_A,                                 
    input  wire [3: 0]      RS_ROB_pos,                            
    //to CDB
    output reg              ALU_vaild,                                   
    output reg  [`RBID]     ALU_ROB_pos,                                
    output reg  [`RLEN]     ALU_val,                               
               
);

    always @(*) begin
        ALU_val_vaild = RS_valid;
        if (RS_valid)  ALU_ROB_pos = RS_ROB_pos; else ALU_ROB_pos = 0;
        if (RS_valid) begin
            case (RS_opcode)
                `LUI:ALU_val=RS_A; 
                `AUIPC:ALU_val=RS_pc+RS_A; 
                `ADD:ALU_val=RS_vj+RS_vk; 
                `SUB:ALU_val=RS_vj-RS_vk; 
                `SLL:ALU_val=RS_vj<<(RS_vk[4:0]); 
                `SLT:ALU_val=($signed(RS_vj)<$signed(RS_vk)); 
                `SLTU:ALU_val=(RS_vj<RS_vk); 
                `XOR:ALU_val=RS_vj^RS_vk;
                `SRL:ALU_val=RS_vj>>(RS_vk[4:0]); 
                `SRA:ALU_val=$signed(RS_vj)>>(RS_vk[4:0]); 
                `OR:ALU_val=RS_vj|RS_vk; 
                `AND:ALU_val=RS_vj&RS_vk; 
                `JALR:jumppc=(RS_vj+RS_A)&(~1);
                `ADDI:ALU_val=RS_vj+RS_vk; 
                `SLTI:ALU_val=($signed(RS_vj)<$signed(RS_A)); 
                `SLTIU:ALU_val=(RS_vj<RS_A); 
                `XORI:ALU_val=RS_vj^RS_A; 
                `ORI:ALU_val=RS_vj|RS_A; 
                `ANDI:ALU_val=RS_vj&RS_A; 
                `SLLI:ALU_val=RS_vj<<RS_A; 
                `SRLI:ALU_val=RS_vj>>RS_A; 
                `SRAI:ALU_val=$signed(RS_vj)>>RS_A; 
                `BEQ:ALU_val=(RS_vj==RS_vk); 
                `BNE:ALU_val=(RS_vj!=RS_vk); 
                `BLT:ALU_val=($signed(RS_vj)<$signed(RS_vk)); 
                `BGE:ALU_val=($signed(RS_vj)>=$signed(RS_vk)); 
                `BLTU:ALU_val=(RS_vj<RS_vk); 
                `BGEU:ALU_val=(RS_vj>=RS_vk); 
                default: ALU_val = 0;
            endcase
        end
        else 
        begin
            ALU_val = 0
        end
    end 
endmodule
/*
    
*/