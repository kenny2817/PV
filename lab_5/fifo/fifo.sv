module fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16
)(
    input  logic              clk,
    input  logic              rst_n,
    input  logic              wr_en,
    input  logic [WIDTH-1:0]  wr_data,
    input  logic              rd_en,
    output logic [WIDTH-1:0]  rd_data,
    output logic              full,
    output logic              empty
);

    // Storage
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers and count
    logic [$clog2(DEPTH)-1:0] wr_ptr;
    logic [$clog2(DEPTH)-1:0] rd_ptr;
    logic [$clog2(DEPTH):0]   count; // can go up to DEPTH

    // Status flags
    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr  <= '0;
            rd_ptr  <= '0;
            count   <= '0;
            rd_data <= '0;
        end else begin
            // Prevent simultaneous read & write
            if (wr_en && !rd_en && !full) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= (wr_ptr + 1) % DEPTH;
                count       <= count + 1;
            end else if (rd_en && !wr_en && !empty) begin
                rd_data     <= mem[rd_ptr];
                rd_ptr      <= (rd_ptr + 1) % DEPTH;
                count       <= count - 1;
            end
        end
    end

endmodule