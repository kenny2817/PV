task test_op(
    input op_e operand
);
    op = operand;
    for (int a = 0; a < (1 << I_SIZE); a++) begin
        for (int b = 0; b < (1 << I_SIZE); b++) begin
            A = a;
            B = b;
            #1;
            assert_golden_model(operand, a, b);
        end
    end 
endtask