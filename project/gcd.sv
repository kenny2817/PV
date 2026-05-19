// =============================================================================
// Module  : gcd
// Version : 1.0
// Spec    : GCD Module Specification v1.0
// =============================================================================

module gcd #(
    parameter int unsigned WIDTH = 16
)(
    input  logic                 clk,
    input  logic                 rst_n,      // Active-low synchronous reset

    // Input channel (request)
    input  logic                 in_valid,
    output logic                 in_ready,
    input  logic [WIDTH-1:0]     a_in,
    input  logic [WIDTH-1:0]     b_in,

    // Output channel (response)
    output logic                 out_valid,
    input  logic                 out_ready,
    output logic [WIDTH-1:0]     gcd_out
);

    // -------------------------------------------------------------------------
    // State encoding
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE,
        RUN,
        DONE
    } state_t;

    state_t state;

    // -------------------------------------------------------------------------
    // Internal datapath registers
    // -------------------------------------------------------------------------
    logic [WIDTH-1:0] a_reg, b_reg;
    logic [WIDTH-1:0] result_reg;   // latched result; stable while out_valid=1

    // -------------------------------------------------------------------------
    // Combinatorial next-values for the Euclidean step
    // -------------------------------------------------------------------------
    logic [WIDTH-1:0] a_next, b_next;

    always_comb begin
        a_next = a_reg;
        b_next = b_reg;
        if (state == RUN) begin
            if (a_reg > b_reg)
                a_next = a_reg - b_reg;
            else if (b_reg > a_reg)
                b_next = b_reg - a_reg;
        end
    end

    // -------------------------------------------------------------------------
    // State register + datapath  (synchronous reset)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state      <= IDLE;
            a_reg      <= '0;
            b_reg      <= '0;
            result_reg <= '0;
        end else begin
            case (state)

                // ----------------------------------------------------------
                // IDLE: wait for a valid input handshake
                // ----------------------------------------------------------
                IDLE: begin
                    // Check both sides of the handshake
                    if (in_valid && in_ready) begin
                        a_reg <= a_in;
                        b_reg <= b_in;

                        // Handle zero operands immediately.
                        if (a_in == '0 || b_in == '0) begin
                            result_reg <= (a_in == '0) ? b_in : a_in;
                            state      <= DONE;
                        end else if (a_in == b_in) begin
                            result_reg <= a_in;
                            state      <= DONE;
                        end else begin
                            state <= RUN;
                        end
                    end
                end

                // ----------------------------------------------------------
                // RUN: subtractive Euclidean algorithm
                // ----------------------------------------------------------
                RUN: begin
                    // Apply the next-cycle computed values (always_comb above)
                    a_reg <= a_next;
                    b_reg <= b_next;

                    // Check convergence on next-cycle values so the
                    if (a_next == b_next) begin
                        result_reg <= a_next;
                        state      <= DONE;
                    end
                end

                // ----------------------------------------------------------
                // DONE: hold result until consumer accepts it
                // ----------------------------------------------------------
                DONE: begin
                    if (out_ready) begin
                        state <= IDLE;
                    end
                    // result_reg is NOT cleared here; gcd_out must remain
                    // stable until the handshake completes.
                end

                default: state <= IDLE;

            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Output assignments
    // -------------------------------------------------------------------------

    // in_ready: accept new input only when idle (spec §5.1)
    assign in_ready  = (state == IDLE);

    // out_valid: result available when in DONE state (spec §5.2)
    assign out_valid = (state == DONE);

    // gcd_out is combinatorial from result_reg.
    assign gcd_out   = result_reg;

endmodule
