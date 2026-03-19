`timescale 1ns/1ps

enum logic [O_SIZE -1 : 0] { 
    ADD =       3'b000,
    SUB =       3'b001,
    AND =       3'b010,
    OR  =       3'b011,
    XOR =       3'b100,
    NOT_A =     3'b101,
    PASS_A =    3'b110,
    PASS_B =    3'b111
} op_e;

task assert_w(
    input op_e  operand,
    input int   a,
    input int   b
);
    logic [I_SIZE -1 : 0] expected_Y;
    logic expected_carry;
    string op_str;
    
    case (operand)
        ADD:     begin  expected_Y = a + b;     expected_carry = (a + b) >> I_SIZE;     op_str = "ADD";     end
        SUB:     begin  expected_Y = a - b;     expected_carry = (a - b) >> I_SIZE;     op_str = "SUB";     end
        AND:     begin  expected_Y = a & b;     expected_carry = 0;                     op_str = "AND";     end
        OR:      begin  expected_Y = a | b;     expected_carry = 0;                     op_str = "OR";      end
        XOR:     begin  expected_Y = a ^ b;     expected_carry = 0;                     op_str = "XOR";     end
        NOT_A:   begin  expected_Y = ~a;        expected_carry = 0;                     op_str = "NOT_A";   end
        PASS_A:  begin  expected_Y = a;         expected_carry = 0;                     op_str = "PASS_A";  end
        PASS_B:  begin  expected_Y = b;         expected_carry = 0;                     op_str = "PASS_B";  end
        default: begin  expected_Y = 0;         expected_carry = 0;                     op_str = "INVALID"; end // invalid
    endcase

    assert (Y == expected_Y && carry == expected_carry)
        else $error("%s failed for A=%0d, B=%0d: Y=%0d, carry=%b", op_str, A, B, Y, carry);  
endtask

module alu_4bit_tb;

    localparam int I_SIZE = 4;
    localparam int O_SIZE = 3;

    logic [I_SIZE -1 : 0]   A, B, Y;
    logic [O_SIZE -1 : 0]   op;
    logic                   carry;

    alu_4bit dut (
        .A(A),
        .B(B),
        .sel(op),
        .result(Y),
        .carry_out(carry)
    );

    task test_op(
        input op_e operand
    );
        op = operand;
        for (int a = 0; a < I_SIZE; a++) begin
            for (int b = 0; b < I_SIZE; b++) begin
                A = a;
                B = b;
                #1;
                assert_w(operand, a, b);
            end
        end 
    endtask

    initial begin
        #10; test_op(ADD);       // T_000
        #10; test_op(SUB);       // T_001
        #10; test_op(AND);       // T_002
        #10; test_op(OR);        // T_003
        #10; test_op(XOR);       // T_004
        #10; test_op(NOT_A);     // T_005
        #10; test_op(PASS_A);    // T_006
        #10; test_op(PASS_B);    // T_007
        #10; test_op(3'bxxx);    // T_008
    end

endmodule
