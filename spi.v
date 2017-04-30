
module spi_slave (
	input        clk,
	input        spi_clk,
	input        spi_mosi,
	input        spi_cs,
	input [7:0]  write_value,
	output [7:0] read_value,
	output       first_byte,
	output       done,
	output [7:0] debug_info
);

	// CPOL == 0: clock state while idle is low  ("inactive")
	// CPOL == 1: clock state while idle is high ("inactive")
	parameter CPOL = 0;
	// CPHA == 0: write on clock deactivation, sample on clock activation
	// CPHA == 1: write on clock activation, sample on clock deactivation
	parameter CPHA = 0;
	parameter LSBFIRST = 1;

	reg [ 3:0] state; // idle, start condition, d0, d1, ..., d7
	reg [ 7:0] value_int;
	reg [ 7:0] value_int_buffer;
	reg done_int;
	reg first_byte_int; // inform caller that this is a new transmission
	wire sample;        // used as name for the "sample" condition is True
	wire write;         // used as name for the "write" condition is True
	reg spi_clk_pre;    // previous value of spi_clk 

	assign sample =    (CPOL ^  (CPHA ^ spi_clk    ))
	                && (CPOL ^ !(CPHA ^ spi_clk_pre));

	assign write  =    (CPOL ^ !(CPHA ^ spi_clk    ))
	                && (CPOL ^  (CPHA ^ spi_clk_pre));

	// for simulation: initialize to valid internal values
	initial begin
		state <= 0;
		done_int <= 0;
		value_int_buffer <= 0;
	end

	// actual implementation
	always @(posedge clk)
	begin
		spi_clk_pre <= spi_clk;

		if (spi_cs) begin
			// enable went high (inactive), cancel communication
			state <= 0;
		end else if (state == 0) begin
			// idle, wait for enable beeing pulled low
			done_int <= 0;
			if (spi_cs == 0) begin // start bit detected
				state <= 1;
				// initialize value_int
				value_int <= 0;
				// if applicable: add output of first bit for CPHA == 0
				first_byte_int <= 1;
			end
		end else begin
			// anything but idle, do reception
			if (sample) begin
				value_int <= LSBFIRST ? {value_int[6:0], spi_mosi}
				                      : {spi_mosi, value_int[7:1]};
				// count bits transfered
				state     <= state == 8 ? state + 1 : 0;
				done_int  <= state == 8; // notify calling block
			end
			if (done_int) begin
//			if (state == 8) begin // use same condition as evaluated to
			                      // done_int to save one cycle of propagation
				first_byte_int <= 0;
				value_int_buffer <= value_int;
			end
		end
	end

	assign read_value      = value_int_buffer;
	assign done            = done_int;
	assign first_byte      = first_byte_int;
	assign debug_info[7:4] = state;
	assign debug_info[3:0] = value_int[3:0];
endmodule
