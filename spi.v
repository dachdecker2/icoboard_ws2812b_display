
module spi_slave (
	input        clk,
	input        resetn,
	input        spi_clk,
	input        spi_mosi,
	input        spi_cs,
	input  [7:0] write_value,
	output [7:0] read_value,
	output [0:0] first_byte,
	output [0:0] timeout_expired,
	output [0:0] done,
	output [7:0] debug_info
);

	// CPOL == 0: clock state while idle is low  ("inactive")
	// CPOL == 1: clock state while idle is high ("inactive")
	parameter CPOL = 0;
	// CPHA == 0: write on clock deactivation, sample on clock activation
	// CPHA == 1: write on clock activation, sample on clock deactivation
	parameter CPHA = 0;
	parameter LSBFIRST = 1;
	parameter TIMEOUT_CYCLES = 9000;
	parameter TIMEOUT_WIDTH = 14;

	reg  [3:0] state; // idle, start condition, d0, d1, ..., d7
	reg  [7:0] value_int;
	reg  [7:0] read_value;
	reg  [0:0] done;
	reg  [0:0] first_byte; // inform caller that this is a new transmission
	wire [0:0] sample;        // used as name for the "sample" condition is True
	wire [0:0] write;         // used as name for the "write" condition is True
	reg  [0:0] spi_clk_reg;    // registered value of spi_clk
	reg  [0:0] spi_clk_pre;    // previous value of spi_clk
	reg  [0:0] spi_mosi_reg;    // registered value of spi_mosi
	reg  [0:0] reset_timeout;

	assign sample =    (CPOL ^  (CPHA ^ spi_clk_reg))
	                && (CPOL ^ !(CPHA ^ spi_clk_pre));

	assign write  =    (CPOL ^ !(CPHA ^ spi_clk_reg))
	                && (CPOL ^  (CPHA ^ spi_clk_pre));

	// for simulation: initialize to valid internal values
	initial begin
		state <= 0;
		done <= 0;
		value_int <= 0;
	end

	reg [TIMEOUT_WIDTH-1:0] timeout_counter = 0;
	reg [0:0]               timeout_expired = 1;

	// actual implementation
	always @(posedge clk) begin
		if (!resetn) begin
			state <= 0;
			reset_timeout <= 1;
			done <= 0;
			timeout_counter <= 0;
			timeout_expired <= 1;
		end else begin
			timeout_counter <= reset_timeout ? TIMEOUT_CYCLES :
			                                   (timeout_counter ? timeout_counter - 1 : 0);
			timeout_expired <= ! timeout_counter;

			spi_clk_reg  <= spi_clk;
			spi_clk_pre  <= spi_clk_reg;
			spi_mosi_reg <= spi_mosi;

			reset_timeout <= 0; // default value
			done <= 0;

			if (timeout_expired) begin
				state <= 0;
				reset_timeout <= 1;
			end else if (sample) begin
				reset_timeout <= 1; // reset timeout in every bit
				value_int <= LSBFIRST ? {value_int[6:0], spi_mosi}
				                      : {spi_mosi, value_int[7:1]};
				if (state < 7) begin
					// starting reception while idle
					state <= state + 1;
					first_byte <= 1;
				end else if (state == 7) begin
					read_value <= LSBFIRST ? {value_int[6:0], spi_mosi}
					                       : {spi_mosi, value_int[7:1]};
					done <= 1;
					state <= 0;
				end
			end
		end
	end

	assign debug_info[7:4] = {state[3:0]};
	assign debug_info[3:0] = value_int[3:0];
endmodule
