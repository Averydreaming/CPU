`include "defines.v"

module IF (
    input  wire             clk, rst, rdy, 
     // ICache
    input  wire             IC_Instr_Hit, 
    input  wire [31: 0]     IC_Instr, 
    output reg  [31: 0]     npc
    
    // Decoder
    input                   ALLFULL,
    output wire             Instr_hit_ID, 
    output wire [31: 0]     Instr_ID, 
);
    reg  [31: 0]    imm;
    assign imm = (op==7'd23)? {Instr[31:12], 12'b0}   :   (op==7'd55)?{Instr[31:12], 12'b0}   :   (op==7'd103)?{{20{Instr[31]}}, Instr[31:20]}   :    (op==7'd111) ? {{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21]} << 1   :   {{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8]} << 1   ;
    reg  [31: 0]    pc;
    assign Instr_hit_ID= IC_Instr_Hit;
    assign Instr_ID =IC_Instr;

    always @(*) begin
        if (!IC_Instr_Hit ||  ALLFULL) begin
            npc = pc;
        end
        else begin
            case (op)
                7'd99   : begin
                    npc = pc + imm;
                end
                7'd111      : begin
                    npc = pc + imm;
                end
                7'd103     : begin
                    npc = pc + 4;
                end
                7'd55      : begin
                    npc = pc + 4;
                end
                default     :  begin
                    npc = pc + 4;
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'b0;
        end 
        else if (IC_Instr_Hit) begin
            case (op)
                7'd99       : pc <= pc + imm;
                7'd111      : pc <= pc + imm;
                default     : pc <= pc + 4;
            endcase
        end
    end

endmodule