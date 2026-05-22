module counter(
    input wire clk,
    input wire reset,
    output reg [3:0] count
);

    parameter MAX_AMOUNT = 4'd10;

    always @(posedge clk) begin
        if (reset) begin
            count <= 4'd0;
        end else begin
            if (count <= MAX_AMOUNT) begin
                count <= count + 1'b1;
            end
        end
    end

    // FORMAL STATEMENTS BELOW --------------------------------
    //

`ifdef FORMAL
    // Assume reset is asserted in the first cycle
    initial assume(reset);

    // After reset, count must be zero
    always @(posedge clk) if (reset) assume(count == 0);

    // Track if we are past the first cycle
    logic past_valid;
    always @(posedge clk) past_valid <= 1'b1;

    // Property: Counter increments by 1 until MAX_AMOUNT (ignoring reset cycles)
    assert property (@(posedge clk) disable iff (reset)
        past_valid && !$past(reset) && ($past(count) < MAX_AMOUNT)
            |-> count == $past(count) + 1);

    // Property: Counter holds value at MAX_AMOUNT (ignoring reset cycles)
    assert property (@(posedge clk) disable iff (reset)
        past_valid && !$past(reset) && ($past(count) == MAX_AMOUNT)
            |-> count == MAX_AMOUNT);

    // Property: Counter resets to 0 when reset is asserted
    assert property (@(posedge clk)
        reset |-> count == 0);
`endif

endmodule
