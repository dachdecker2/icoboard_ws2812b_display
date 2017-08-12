

module clk_gen (
	input        clk,
	input        resetn,
	output [0:0] clk_out
);

	parameter CLK_CYCLES = 1;

	reg [0:0]  clk_out;
	reg [$clog2(CLK_CYCLES):0] clk_counter;
	always @(posedge clk) begin
		if (!resetn) begin
			clk_counter <= CLK_CYCLES-1;
			clk_out <= 0;
		end else begin
			clk_counter <= clk_counter ? (clk_counter-1) : CLK_CYCLES-1;
			clk_out <= !clk_counter;
		end
	end
endmodule
