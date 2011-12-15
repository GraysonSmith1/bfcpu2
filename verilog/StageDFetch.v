`include "Constants.v"

module StageDFetch (
	clk,
	reset,

	dp,
	dp_ce,
	dp_down,

	dce,
	da,
	dd,

	cd,
	crda,
	cack,

	a,

	operation_in,
	ack_in,

	operation,
	ack
);

	parameter A_WIDTH = 12;
	parameter D_WIDTH = 8;

	input clk;
	input reset;

	input      [A_WIDTH - 1:0] dp;
	output                     dp_ce;
	output                     dp_down;

	output                     dce;
	output     [A_WIDTH - 1:0] da;
	input      [D_WIDTH - 1:0] dd;

	input                [7:0] cd;
	input                      crda;
	output                     cack;

	output reg [D_WIDTH - 1:0] a;

	input      [`OPCODE_MSB:0] operation_in;
	output     ack;

	output reg [`OPCODE_MSB:0] operation;
	input      ack_in;

	/*
	 * Data pointer manipulation.
	 */
	assign dp_ce   = (operation_in[`OP_INCDP] || operation_in[`OP_DECDP]);
	assign dp_down =  operation_in[`OP_DECDP];

	/* Reading from DRAM. */
	function should_fetch_d;
	input [`OPCODE_MSB:0] operation;
	begin
		should_fetch_d = (operation[`OP_INC] || operation[`OP_DEC] ||
					operation[`OP_OUT] || operation[`OP_LOOPBEGIN] ||
					operation[`OP_LOOPEND]);
	end
	endfunction

	assign da  = dp;
	assign dce = should_fetch_d(operation_in);

	/* Writing to EXT */
	function should_fetch_x;
	input [`OPCODE_MSB:0] operation;
	begin
		should_fetch_x = operation[`OP_IN];
	end
	endfunction

	assign cack = crda && should_fetch_x(operation_in);

	wire ext_wait;
	assign ext_wait = (should_fetch_x(operation_in) && !crda);

	/* ACKing the previous stage */
	assign ack = ack_in && !ext_wait;

	always @(posedge clk) begin
		if (reset) begin
			operation <= 0;

			a         <= 0;
		end else begin
			if (ack_in && ext_wait) begin
				operation <= 0; /* Bubble */
			end else if(ack_in) begin
				operation <= operation_in;

				if (should_fetch_d(operation_in))
					a      <= dd;
				else if (should_fetch_x(operation_in) && crda)
					a      <= cd;
				else
					a      <= 0;
			end
		end
	end

endmodule
