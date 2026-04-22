`timescale 1ns/1ps

module assertions (
  input logic         clk,
  input logic         rst_n,
  input logic         pc_en,
  input logic         branch_en,
  input logic   [7:0] branch_addr,
  output logic [15:0] instr,
  
  input logic   [7:0] pc,
  input logic [15:0] mem [0:255]
);
  
  property P00;
    // fetch reset
    @(posedge clk)
    !rst_n |=> pc == 0;
  endproperty

  property P01;
    // branch priority
    @(posedge clk) disable iff (!rst_n)
    branch_en |=> pc == $past(branch_addr);
  endproperty

  property P02;
    // pc increment
   @(posedge clk) disable iff (!rst_n || branch_en)
    pc_en |=> pc == $past(pc) + 2;
  endproperty

  property P03;
    // pc stability
    @(posedge clk) disable iff (!rst_n)
    (!pc_en && !branch_en) |=> pc == $past(pc);
  endproperty

  property P04;
    // instruction consistency
    @(posedge clk)
    instr == mem[pc];
  endproperty

  property P05;
    // pc range safety
    @(posedge clk) disable iff (!rst_n)
    !$isunknown(pc);
  endproperty

  assert property (P00) else $warning("P00 FAILED: Reset logic broken");
  assert property (P01) else $warning("P01 FAILED: Branch priority broken");  
  assert property (P02) else $warning("P02 FAILED: PC increment broken");
  assert property (P03) else $warning("P03 FAILED: PC stability broken");
  assert property (P04) else $warning("P04 FAILED: Instruction consistency broken");
  assert property (P05) else $warning("P05 FAILED: PC went to X/Z");

endmodule

module tb_fetch_unit;

  // DUT interface signals
  reg         clk;
  reg         rst_n;
  reg         pc_en;
  reg         branch_en;
  reg  [7:0]  branch_addr;
  wire [15:0] instr;

  // Instantiate DUT
  fetch_unit dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .pc_en      (pc_en),
    .branch_en  (branch_en),
    .branch_addr(branch_addr),
    .instr      (instr)
  );

  // Clock generation: 10ns period
  always #5 clk = ~clk;

  // Directed test sequence
  initial begin
    integer i;
  
    // Initialize inputs
    clk         = 0;
    rst_n       = 0;
    pc_en       = 0;
    branch_en   = 0;
    branch_addr = 8'h00;

    $display("[%0t] STARTING SIMULATION ...", $time);

    // Apply reset
    #5;
    @(posedge clk);
    rst_n = 1;
    @(posedge clk);
    $display("[%0t] TEST #1: Reset released, pc should be 0, instr=%0d", $time, instr);

    // Sequential pc increments
    pc_en = 1;
    for (i = 2; i <= 5; i = i + 1) begin
      @(posedge clk);
      $display("[%0t] TEST #%1d: pc increment, pc=%0h, instr=%0d", $time, i, dut.pc, instr);
    end
    pc_en = 0;

    // Branch test
    branch_addr = 8'h10;
    branch_en   = 1;
    @(posedge clk);
    branch_en   = 0;
    $display("[%0t] TEST #6: Branch taken to addr=0x%0h, pc=%0h, instr=%0d", $time, branch_addr, dut.pc, instr);

    // Branch priority over pc_en
    branch_addr = 8'h20;
    pc_en       = 1;
    branch_en   = 1;
    @(posedge clk);
    branch_en   = 0;
    pc_en       = 0;
    $display("[%0t] TEST #7: Branch priority test, pc should be 0x20, instr=%0d", $time, instr);

    // No control signals
    @(posedge clk);
    $display("[%0t] TEST #8: No control active, pc=%0h, instr=%0d", $time, dut.pc, instr);

    // End simulation
    #20;
    $display("[%0t] TEST COMPLETE.", $time);
    $finish;
  end

  always $monitor("%d | %b | %b | %b | %0h | %0d", $time, rst_n, pc_en, branch_en, branch_addr, instr);

  // INSERT ASSERTIONS BELOW
  bind fetch_unit assertions chk_inst (
    .clk        (clk),
    .rst_n      (rst_n),
    .pc_en      (pc_en),
    .branch_en  (branch_en),
    .branch_addr(branch_addr),
    .instr      (instr),

    .pc         (pc),
    .mem        (mem)
  );

endmodule
