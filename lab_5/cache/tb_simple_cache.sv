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

        repeat (5) begin
            @(posedge clk);
            addr = $urandom_range(0,255);
            read = 1; write = 1;
        end

        #50
        $display("TEST FINISHED");
        $finish;
    end

    logic read_past, write_past;
    logic [ADDR_WIDTH-1:0] addr_past;

    always_ff @(posedge clk) begin
        if (reset) begin
            read_past  <= 0;
            write_past <= 0;
            addr_past  <= 0;
        end else begin
            read_past  <= read;
            write_past <= write;
            addr_past  <= addr;
        end
    end

    covergroup simple_cache_cov @(posedge clk iff !reset);
        option.per_instance = 1;
        option.name = "simple_cache_cov";

        cp_index:  coverpoint addr_past[
            dut.OFFSET_WIDTH + dut.INDEX_WIDTH-1 -: dut.INDEX_WIDTH];
        cp_offset: coverpoint addr_past[
            dut.OFFSET_WIDTH -1 -: dut.OFFSET_WIDTH];

        cp_rw_hit: coverpoint {read_past, write_past, hit} {
            
            // 3'b[read][write][hit]
            bins read_hit       = {3'b101};
            bins read_miss      = {3'b100};
            
            bins write_hit      = {3'b011};
            bins write_miss     = {3'b010};
            
            bins collision_hit  = {3'b111};
            bins collision_miss = {3'b110};
            
            bins idle           = {3'b000};
            illegal_bins fake   = {3'b001};
        }
    
    endgroup

    property reset_p;
        @(posedge clk) 
        reset |=> (hit == 1'b0) && (dut.valid_array == '{default:0}); 
    endproperty

    cover property (reset_p);
    
    simple_cache_cov cov_inst = new();

endmodule