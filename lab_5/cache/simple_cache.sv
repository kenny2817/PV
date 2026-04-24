// simple_cache.sv (Direct-Mapped)
module simple_cache #(
    parameter int CACHE_LINES = 16,
    parameter int LINE_SIZE   = 4,    // words per line
    parameter int ADDR_WIDTH  = 8,    // address width in bits
    parameter int DATA_WIDTH  = 32
)(
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  read,
    input  logic                  write,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic                  hit 
);

    // Compute widths
    localparam int INDEX_WIDTH  = $clog2(CACHE_LINES);
    localparam int OFFSET_WIDTH = $clog2(LINE_SIZE);
    localparam int TAG_WIDTH    = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH;

    // Cache storage: [index][offset]
    logic [DATA_WIDTH-1:0] cache_mem [CACHE_LINES-1:0][LINE_SIZE-1:0];
    logic [TAG_WIDTH-1:0]  tag_array [CACHE_LINES-1:0];
    logic                  valid_array [CACHE_LINES-1:0];

    // Decoded address fields
    logic [TAG_WIDTH-1:0]    tag;
    logic [INDEX_WIDTH-1:0]  index;
    logic [OFFSET_WIDTH-1:0] offset;

    // Use part-selects robust to variable widths
    assign tag    = addr[ADDR_WIDTH-1 -: TAG_WIDTH];
    assign index  = addr[OFFSET_WIDTH+INDEX_WIDTH-1 -: INDEX_WIDTH];
    assign offset = addr[OFFSET_WIDTH-1 -: OFFSET_WIDTH];

    // Reset and sequential behavior
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Clear tags/valid bits and data outputs
            for (int i = 0; i < CACHE_LINES; i++) begin
                valid_array[i] <= 1'b0;
                tag_array[i]   <= '0;
                for (int j = 0; j < LINE_SIZE; j++) begin
                    cache_mem[i][j] <= '0;
                end
            end
            hit <= 1'b0;
            data_out <= '0;
        end else begin
            if (read) begin
                if (valid_array[index] && tag_array[index] == tag) begin
                    hit <= 1'b1;
                    data_out <= cache_mem[index][offset];
                end else begin
                    hit <= 1'b0;
                    // Simulate fetch from memory (just echo addr for simplicity)
                    data_out <= {24'h0, addr};
                    cache_mem[index][offset] <= {24'h0, addr};
                    tag_array[index] <= tag;
                    valid_array[index] <= 1'b1;
                end
            end else if (write) begin
                if (valid_array[index] && tag_array[index] == tag) begin
                    hit <= 1'b1;
                end else begin
                    hit <= 1'b0;
                    tag_array[index] <= tag;
                    valid_array[index] <= 1'b1;
                end
                cache_mem[index][offset] <= data_in;
            end else begin
                // No operation; keep outputs stable
                hit <= 1'b0;
            end
        end
    end
endmodule
