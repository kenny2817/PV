`timescale 1ns/1ps

module assertions (
  input logic         clk,
  input logic         rst_n,
  input logic         instr_valid,
  input logic [15:0] instr,
  input logic        decode_done,
  input logic [3:0]  opcode,
  input logic [3:0]  rd,
  input logic [3:0]  rs,
  input logic [3:0]  imm,
  input logic        hazard_stall
);

    default clocking cb @(posedge clk); 
    endclocking

    property P00;
        // reset
        !rst_n |=> 
          (!decode_done && 
          !hazard_stall && 
          opcode == 0 && 
          rd == 0 && 
          rs == 0 && 
          imm == 0);
    endproperty

    property P01;
        // instruction
        disable iff (!rst_n)
        (instr_valid && !hazard_stall) |=> 
          (!hazard_stall)[->1] |=> 
            decode_done;
    endproperty

    property P02;
        // decode_done
        disable iff (!rst_n)
        decode_done |-> $past(instr_valid) || $past(hazard_stall);
    endproperty

    property P03;
        // outputs
        disable iff (!rst_n)
        (instr_valid && !hazard_stall) |=> 
          (opcode == instr[15:12] && 
          rd      == instr[11:8] && 
          rs      == instr[7:4] && 
          imm     == instr[3:0]);
    endproperty

    property P04;
        // stall
        disable iff (!rst_n)
        (instr_valid && hazard_stall) |=> 
          (opcode == $past(opcode) && 
          rd      == $past(rd) && 
          rs      == $past(rs) && 
          imm     == $past(imm) && 
          !decode_done);
    endproperty

    property P05;
        // hazard
        disable iff (!rst_n)
        instr_valid && (instr[7:4] == rd) |-> 
          hazard_stall;
    endproperty

	assert property (P00) else 
        $warning("\n[SVA P00 FAILED]: Reset Active (!rst_n) but outputs are not zero.\n\t-> decode_done: %b (Exp: 0)\n\t-> hazard_stall: %b (Exp: 0)\n\t-> opcode: %0h (Exp: 0)\n\t-> rd: %0h (Exp: 0)\n\t-> rs: %0h (Exp: 0)\n\t-> imm: %0h (Exp: 0)", 
                 $sampled(decode_done), $sampled(hazard_stall), $sampled(opcode), $sampled(rd), $sampled(rs), $sampled(imm));

    assert property (P01) else 
        $warning("\n[SVA P01 FAILED]: Pipeline latency missed. Expected decode_done=1 after stall dropped.\n\t-> Current decode_done: %b (Exp: 1)\n\t-> Current hazard_stall: %b", 
                 $sampled(decode_done), $sampled(hazard_stall));

    assert property (P02) else 
        $warning("\n[SVA P02 FAILED]: Spurious decode_done detected! Asserted without a valid prior state.\n\t-> Current decode_done: %b\n\t-> Previous instr_valid: %b (Exp: 1 if no stall)\n\t-> Previous hazard_stall: %b (Exp: 1 if recovering)", 
                 $sampled(decode_done), $sampled($past(instr_valid)), $sampled($past(hazard_stall)));

    assert property (P03) else 
        $warning("\n[SVA P03 FAILED]: Decoded output mismatch.\n\tEXPECTED (from past instr):\n\t\topcode=%0h, rd=%0h, rs=%0h, imm=%0h\n\tACTUAL (current outputs):\n\t\topcode=%0h, rd=%0h, rs=%0h, imm=%0h", 
                 $sampled($past(instr[15:12])), $sampled($past(instr[11:8])), $sampled($past(instr[7:4])), $sampled($past(instr[3:0])), 
                 $sampled(opcode), $sampled(rd), $sampled(rs), $sampled(imm));

    assert property (P04) else 
        $warning("\n[SVA P04 FAILED]: Output state illegally changed during a stall!\n\tPAST STATE:\n\t\topcode=%0h, rd=%0h, rs=%0h, imm=%0h\n\tCURRENT STATE:\n\t\topcode=%0h, rd=%0h, rs=%0h, imm=%0h\n\t-> decode_done: %b (Exp: 0)", 
                 $sampled($past(opcode)), $sampled($past(rd)), $sampled($past(rs)), $sampled($past(imm)), 
                 $sampled(opcode), $sampled(rd), $sampled(rs), $sampled(imm), $sampled(decode_done));

    assert property (P05) else 
        $warning("\n[SVA P05 FAILED]: RAW hazard condition met, but stall did not assert immediately.\n\t-> instr_valid: %b\n\t-> Incoming rs: %0h\n\t-> Current rd:  %0h\n\t-> hazard_stall: %b (Exp: 1)", 
                 $sampled(instr_valid), $sampled(instr[7:4]), $sampled(rd), $sampled(hazard_stall));
  
endmodule

module tb_decode_unit;

  // DUT interface
  reg         clk;
  reg         rst_n;
  reg         instr_valid;
  reg  [15:0] instr;
  wire        decode_done;
  wire [3:0]  opcode, rd, rs, imm;
  wire        hazard_stall;

  // Instantiate DUT
  decode_unit dut (
    .clk(clk),
    .rst_n(rst_n),
    .instr_valid(instr_valid),
    .instr(instr),
    .decode_done(decode_done),
    .opcode(opcode),
    .rd(rd),
    .rs(rs),
    .imm(imm),
    .hazard_stall(hazard_stall)
  );

  // Clock generation: 10ns period
  initial clk = 0;
  always #5 clk = ~clk;

  // Directed test sequence
  initial begin
    integer i;

    // Initialize inputs
    rst_n = 0;
    instr_valid = 0;
    instr = 16'h0000;
  
    $display("[%0t] STARTING SIMULATION ...", $time);

    // Apply reset
    #5;
    @(posedge clk);
    rst_n = 1;
    @(posedge clk);
    $display("[%0t] TEST #1: Reset released, outputs should be 0", $time);

    // Decode instruction without hazard
    instr = 16'h1234; // opcode=1, rd=2, rs=3, imm=4
    instr_valid = 1;
    @(posedge clk);
    instr_valid = 0;
    // Wait for decode_done
    repeat (3) @(posedge clk);
    $display("[%0t] TEST #2: decode_done=%b, opcode=%0h, rd=%0h, rs=%0h, imm=%0h",
             $time, decode_done, opcode, rd, rs, imm);

    // Decode instruction with hazard (rs == last_rd)
    instr = 16'h3A20; // opcode=3, rd=A, rs=2 (matches previous rd), imm=0
    instr_valid = 1;
    @(posedge clk);
    instr_valid = 0;
    // Stall should assert
    @(posedge clk);
    $display("[%0t] TEST #3: hazard_stall=%b", $time, hazard_stall);

    // Wait for stall to clear and decode to complete
    repeat (4) @(posedge clk);
    $display("[%0t] TEST #4: decode_done=%b, opcode=%0h, rd=%0h, rs=%0h, imm=%0h",
             $time, decode_done, opcode, rd, rs, imm);

    // Decode instruction after hazard clears
    instr = 16'h4B21; // opcode=4, rd=B, rs=2 (no hazard with last_rd=A), imm=1
    instr_valid = 1;
    @(posedge clk);
    instr_valid = 0;
    repeat (3) @(posedge clk);
    $display("[%0t] TEST #5: decode_done=%b, opcode=%0h, rd=%0h, rs=%0h, imm=%0h",
             $time, decode_done, opcode, rd, rs, imm);

    // Finish
    #20;
    $display("[%0t] TEST COMPLETE.", $time);
    $finish;
  end

  // INSERT ASSERTIONS BELOW
  bind decode_unit assertions chk_inst (
    .clk            (clk),
    .rst_n          (rst_n),
    .instr_valid    (instr_valid),
    .instr          (instr),
    .decode_done    (decode_done),
    .opcode         (opcode),
    .rd             (rd),
    .rs             (rs),
    .imm            (imm),
    .hazard_stall   (hazard_stall)
  );

    initial begin
        $dumpfile("waves.vcd"); 
        $dumpvars(0, tb_decode_unit);  
    end

endmodule
