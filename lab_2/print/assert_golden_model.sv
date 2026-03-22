task assert_golden_model(
    input op_e  operand,
    input int   a,
    input int   b
);
    logic [I_SIZE -1 : 0]   expected_Y;
    logic                   expected_carry;
    
    case (operand)
        ADD:     begin expected_Y = a + b; expected_carry = (a + b) >> I_SIZE; end
        SUB:     begin expected_Y = a - b; expected_carry = (a - b) >> I_SIZE; end
        AND:     begin expected_Y = a & b; expected_carry = 0;                 end
        OR:      begin expected_Y = a | b; expected_carry = 0;                 end
        XOR:     begin expected_Y = a ^ b; expected_carry = 0;                 end
        NOT_A:   begin expected_Y = ~a;    expected_carry = 0;                 end
        PASS_A:  begin expected_Y = a;     expected_carry = 0;                 end
        PASS_B:  begin expected_Y = b;     expected_carry = 0;                 end
        default: begin expected_Y = 0;     expected_carry = 0;                 end
    endcase

    assert (Y == expected_Y && carry == expected_carry)
        else $error("%s failed for A=%0d, B=%0d: Y=%0d, carry=%b", operand, A, B, Y, carry);  
endtask