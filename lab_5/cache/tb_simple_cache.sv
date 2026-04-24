// tb_simple_cache.sv
module tb_simple_cache;

    // Parameters
    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 32;

    // DUT signals
    logic clk, reset;
    logic read, write;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] data_in;
    logic [DATA_WIDTH-1:0] data_out;
    logic hit;

    // Instantiate DUT
    simple_cache dut (
        .clk(clk), .reset(reset),
        .read(read), .write(write),
        .addr(addr), .data_in(data_in),
        .data_out(data_out), .hit(hit)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Reset
        clk = 0; reset = 1;
        read = 0; write = 0;
        addr = 0; data_in = 0;
        #20 reset = 0;

        // Random stimulus
        repeat (200) begin
            @(posedge clk);
            addr = $urandom_range(0,255);
            if ($urandom_range(0,1)) begin
                read = 1; write = 0;
            end else begin
                read = 0; write = 1;
                data_in = $urandom();
            end
        end

        // ADD ADDITIONAL STIMULUS AS NEEDED HERE

        #50
        $display("TEST FINISHED");
        $finish;
    end

    // ADD COVERAGE STATEMENTS HERE

endmodule