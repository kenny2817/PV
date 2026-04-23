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

	// All outputs must be cleared to zero
	property P00;
		!rst_n |-> (
			opcode       == 0 && 
			rd 	         == 0 && 
			rs           == 0 && 
			imm          == 0 && 
			decode_done  == 0 && 
			hazard_stall == 0
		);
	endproperty

	// An instruction is accepted when instr_valid=1 and hazard_stall=0 in the nextcycle.
	// On acceptance, the fields (opcode, rd, rs, imm) must capture the corresponding bits of instr
	property P01;
		disable iff (!rst_n)
		(instr_valid && !hazard_stall) |=> (
			opcode == $past(instr[15 : 12]) && 
			rd     == $past(instr[11 :  8]) && 
			rs     == $past(instr[ 7 :  4]) && 
			imm    == $past(instr[ 3 :  0])
		);
	endproperty

	// While instr_valid=1 and hazard_stall=1, the decoded fields (opcode, rd, rs, imm) must retain their previous values and only update when the instruction is accepted
	property P02;
		disable iff (!rst_n)
		(instr_valid && hazard_stall) |=> (
			$stable(opcode) && 
			$stable(rd	  ) && 
			$stable(rs	  ) && 
			$stable(imm	  )
		);
	endproperty
	
	// A hazard occurs when the destination register (rd) of the previously accepted instruction matches the source register (rs) of the current instruction
	// hazard_stallmust assert
	property P03;
		disable iff (!rst_n)
		(instr_valid && (instr[7:4] == rd)) |-> hazard_stall;
	endproperty

	// After acceptance in cycle N, decode_done must assert exactly in cycle N+2
	// The current instruction is not accepted until the stall clears
	// If instr_valid is high in consecutive cycles and no hazard occurs, each instruction is accepted immediately
	property P04;
		disable iff (!rst_n)
		(instr_valid && !hazard_stall) |-> ##2 decode_done;
	endproperty

	// decode_done must be a single cycle pulse
	// Each accepted instruction produces a decode_donepulse two cycles later, possibly resulting in consecutive decode_donepulses
	property P05;
		disable iff (!rst_n)
		decode_done |-> $past(instr_valid && !hazard_stall, 2);
	endproperty

	// decode_done must not assert during the stall window
	property P06;
		disable iff (!rst)
		hazard_stall |-> !decode_done;
	endproperty

	assert property (P00) else $warning("P0 FAILE0D");
	assert property (P01) else $warning("P01 FAILED");
	assert property (P02) else $warning("P02 FAILED");
	assert property (P03) else $warning("P03 FAILED");
	assert property (P04) else $warning("P04 FAILED");
	assert property (P05) else $warning("P05 FAILED");
	assert property (P06) else $warning("P06 FAILED");
  
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
