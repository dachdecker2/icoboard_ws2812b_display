
module bram #(
	parameter DATA_WIDTH = 8,
	parameter ADDR_WIDTH = 8
) (
	input  wire clk,
	input  wire read,
	input  wire write,
	input  wire [ADDR_WIDTH-1:0] addr_in,
	input  wire [DATA_WIDTH-1:0] data_in,
	input  wire [ADDR_WIDTH-1:0] addr_out,
	output wire [DATA_WIDTH-1:0] data_out
);

	reg [DATA_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];
	reg [DATA_WIDTH-1:0] data_out_int;

	always @(posedge clk) begin
		mem[addr_in] <= data_in;
		data_out_int <= mem[addr_out];
	end

	initial begin
		mem[0] <= 0;
		mem[1] <= 1;
		mem[2] <= 2;
		mem[3] <= 3;
		mem[4] <= 4;
		mem[5] <= 5;
		mem[6] <= 6;
		mem[7] <= 7;
		mem[8] <= 8;
		mem[9] <= 9; // working initialisation  */
//		$readmemh("meminit", mem); // also working initialisation
	end

	assign data_out = data_out_int;
endmodule
// */