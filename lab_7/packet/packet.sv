module packet (
    input  wire clk,
    input  wire reset,
    input  wire start_pkt,
    input  wire hdr_done,
    input  wire payload_done,
    input  wire chk_ok,
    input  wire chk_fail,
    input  wire abort,
    output reg  valid_pkt,
    output reg  error_pkt,
    output reg [2:0] state
);

    // State encoding
    localparam IDLE     = 3'd0;
    localparam HEADER   = 3'd1;
    localparam PAYLOAD  = 3'd2;
    localparam CHECKSUM = 3'd3;
    localparam DONE     = 3'd4;

    always @(posedge clk) begin
        if (reset) begin
            state     <= IDLE;
            valid_pkt <= 0;
            error_pkt <= 0;
        end else begin
            valid_pkt <= 0;
            error_pkt <= 0;
            if (abort) begin
                state <= IDLE;
            end else begin
                case (state)
                    IDLE:    if (start_pkt) state <= HEADER;
                    HEADER:  if (hdr_done)  state <= PAYLOAD;
                    PAYLOAD: if (payload_done) state <= CHECKSUM;
                    CHECKSUM: begin
                        if (chk_ok) begin
                            state     <= DONE;
                            valid_pkt <= 1;
                        end else if (chk_fail) begin
                            state     <= IDLE;
                            error_pkt <= 1;
                        end
                    end
                    DONE:    state <= IDLE;
                    default: state <= IDLE;
                endcase
            end
        end
    end

    // FORMAL STATEMENTS BELOW --------------------------------
    //

`ifdef FORMAL

    logic past_valid = 0'b0;
    always @(posedge clk) past_valid <= 1'b1;
    
    initial_reset: assume property (
        @(posedge clk) !past_valid |-> reset
    );

    exclusive_outcome: assume property (
        @(posedge clk) !chk_ok || !chk_fail
    );

    _reset: assert property (
        @(posedge clk)
        reset |=> (state == IDLE) && !valid_pkt && !error_pkt
    );

    _abort: assert property (
        @(posedge clk) disable iff (reset)
        abort |=> (state == IDLE) && !valid_pkt && !error_pkt
    );

    _state: assert property (
        @(posedge clk) disable iff (reset)
        (state == IDLE)     ||
        (state == HEADER)   ||
        (state == PAYLOAD)  ||
        (state == CHECKSUM) ||
        (state == DONE)
    );

    idle_header: assert property (
        @(posedge clk) disable iff (reset)
        (state == IDLE) && start_pkt && !abort
            |=> (state == HEADER)
    );

    idle_idle: assert property (
        @(posedge clk) disable iff (reset)
        (state == IDLE) && !start_pkt && !abort
            |=> (state == IDLE)
    );

    header_payload: assert property (
        @(posedge clk) disable iff (reset)
        (state == HEADER) && hdr_done && !abort
            |=> (state == PAYLOAD)
    );

    header_header: assert property (
        @(posedge clk) disable iff (reset)
        (state == HEADER) && !hdr_done && !abort
            |=> (state == HEADER)
    );

    payload_checksum: assert property (
        @(posedge clk) disable iff (reset)
        (state == PAYLOAD) && payload_done && !abort
            |=> (state == CHECKSUM)
    );

    payload_payload: assert property (
        @(posedge clk) disable iff (reset)
        (state == PAYLOAD) && !payload_done && !abort
            |=> state == PAYLOAD
    );

    checkusm_done: assert property (
        @(posedge clk) disable iff (reset)
        (state == CHECKSUM) && chk_ok && !abort
            |=> (state == DONE) && valid_pkt
    );

    checksum_idle: assert property (
        @(posedge clk) disable iff (reset)
        ((state == CHECKSUM) && chk_fail && !abort)
            |=> (state == IDLE) && error_pkt
    );

    checksum_checksum: assert property (
        @(posedge clk) disable iff (reset)
        (state == CHECKSUM) && !chk_ok && !chk_fail && !abort
            |=> (state == CHECKSUM) && !valid_pkt && !error_pkt
    );

    done_idle: assert property (
        @(posedge clk) disable iff (reset)
        (state == DONE) && !abort
            |=> (state == IDLE)
    );

    pulse_error_pkt: assert property (
        @(posedge clk) disable iff (reset)
        past_valid && error_pkt
            |-> !$past(error_pkt)
    );

    safe_error_pkt: assert property (
        @(posedge clk) disable iff (reset)
        past_valid && error_pkt
            |-> ($past(state) == CHECKSUM) && $past(chk_fail) && !$past(abort)
    );

    pulse_valid_pkt: assert property (
        @(posedge clk) disable iff (reset)
        past_valid && valid_pkt
            |-> !$past(valid_pkt)
    );

    safe_valid_pkt: assert property (
        @(posedge clk) disable iff (reset)
        past_valid && valid_pkt
            |-> ($past(state) == CHECKSUM) && $past(chk_ok) && !$past(abort)
    );

`endif

endmodule