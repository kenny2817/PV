`timescale 1ns/1ps

module tb_fifo;

  // Parameters
  localparam WIDTH = 8;
  localparam DEPTH = 16;

  // DUT signals
  logic clk, rst_n;
  logic wr_en, rd_en;
  logic [WIDTH-1:0] wr_data;
  logic [WIDTH-1:0] rd_data;
  logic full, empty;

  // Instantiate DUT
  fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(wr_en),
    .wr_data(wr_data),
    .rd_en(rd_en),
    .rd_data(rd_data),
    .full(full),
    .empty(empty)
  );

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk; // 100 MHz

  initial begin
    // Reset
    rst_n = 0;
    wr_en = 0;
    rd_en = 0;
    wr_data = '0;
    #20;
    rst_n = 1; 
  
    @(posedge clk);
    wait (rst_n);

    // Stimulus
    @(posedge clk);
    
    wr_en = 1; rd_en = 0; wr_data = 8'hFF; repeat (17) @(posedge clk);
    
    wr_en = 0; rd_en = 0;                              @(posedge clk);
    wr_en = 1; rd_en = 1;                              @(posedge clk);

    wr_en = 0; rd_en = 1;                  repeat (16) @(posedge clk);
    wr_en = 1; rd_en = 0; wr_data = 8'h00; repeat (16) @(posedge clk);
    wr_en = 0; rd_en = 1;                  repeat (16) @(posedge clk);

    rst_n = 0;                                         @(posedge clk);
    rst_n = 1;                                         @(posedge clk);

    #50;
    $display("TEST FINISHED");
    $finish;
  end

  // Assertions
  always @(posedge clk) begin
    if (wr_en && full)  $error("Write attempted when FIFO is full!");
    if (rd_en && empty) $error("Read attempted when FIFO is empty!");
  end

  // Functional coverage
  covergroup fifo_cov @(posedge clk);
    option.per_instance = 1;

    // Cover flags
    coverpoint full {
      bins went_full = {1};
    }
    coverpoint empty {
      bins went_empty = {1};
    }

    // Cover occupancy transitions
    coverpoint dut.count {
      bins empty_bin   = {0};
      bins mid_bins    = {[1:DEPTH-1]};
      bins full_bin    = {DEPTH};
    }

    // Cover read/write activity
    coverpoint wr_en;
    coverpoint rd_en;

    // Cross coverage: wr_en vs rd_en
    cross wr_en, rd_en {
      bins write_only = binsof(wr_en) intersect {1} &&
                        binsof(rd_en) intersect {0};
      bins read_only  = binsof(wr_en) intersect {0} &&
                        binsof(rd_en) intersect {1};
      bins both_off   = binsof(wr_en) intersect {0} &&
                        binsof(rd_en) intersect {0};
      bins illegal    = binsof(wr_en) intersect {1} &&
                        binsof(rd_en) intersect {1};
    }
  endgroup

  // Cover property: FIFO becomes empty after a read when it had data
  property becomes_empty_after_read;
    @(posedge clk) disable iff (!rst_n)
      (dut.count > 0 && rd_en) |=> empty;
  endproperty

  cover property (becomes_empty_after_read);

  fifo_cov cov_inst = new();

endmodule