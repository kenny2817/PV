module fetch_unit (
    input  wire        clk,
    input  wire        rst_n,

    // Input from control
    input  wire        pc_en,
    input  wire        branch_en,
    input  wire [7:0]  branch_addr,

    // Output to decode
    output reg  [15:0] instr
);

    reg [7:0] pc;
    reg [7:0] next_pc;
    reg [15:0] mem [0:255];
    integer i;

    // Initialize memory with dummy instructions
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = i; // instruction = address for simplicity
    end

    always @* begin
        if (branch_en)
            next_pc = branch_addr;
        else if (pc_en)
            next_pc = pc + 2;
        else
            next_pc = pc;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            pc    <= 8'h00;
            instr <= mem[8'h00];
        end else begin
            pc    <= next_pc;
            instr <= mem[next_pc];
        end
    end

endmodule