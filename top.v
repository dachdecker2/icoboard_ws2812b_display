
// `default_nettype none

`include "ws2812b_out.v"

module top (
	input clk_100mhz,
	      btn1, btn2,
	      rpi_ice_mosi, rpi_ice_miso, rpi_ice_clk, rpi_ice_ss, rpi_ice_ss2,
	output reg led1, led2, led3, pmod1_1,
               pmod2_1, pmod2_2, pmod2_3, pmod2_4,
               pmod4_1, pmod4_2, pmod4_3, pmod4_4
	);

	// Clock Generation

	// 25 MHz, probably 3 MHz
/*	localparam DIVR = 4'b0000;
	localparam DIVF = 7'b0000111;
	localparam DIVQ = 3'b101;
	localparam FILTER_RANGE = 3'b101; // */

	// 75 MHz, actually 9 MHz
	localparam DIVR = 4'b0000;
	localparam DIVF = 7'b0010111;
	localparam DIVQ = 3'b101;
	localparam FILTER_RANGE = 3'b101; // */

	wire pll_locked;
	wire clk_int;
	SB_PLL40_PAD #(
		.FEEDBACK_PATH("SIMPLE"),
		.DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
		.DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
		.PLLOUT_SELECT("GENCLK"),
		.FDA_FEEDBACK(4'b1111),
		.FDA_RELATIVE(4'b1111),
		.DIVR(DIVR),
		.DIVF(DIVF),
		.DIVQ(DIVQ),
		.FILTER_RANGE(3'b101)
	) pll (
		.PACKAGEPIN   (clk_100mhz),
		.PLLOUTGLOBAL (clk_int ),
		.LOCK         (pll_locked),
		.BYPASS       (1'b0      ),
		.RESETB       (1'b1      )
	);
	wire clk = clk_int;


	// Reset Generator
	reg [3:0] resetn_gen = 0;
	reg resetn;
	always @(posedge clk) begin
		resetn <= &resetn_gen;
		resetn_gen <= {resetn_gen[2:0], pll_locked && !btn2};
	end

	// 5MHz-clock
	reg       clk_5MHz;
	reg [3:0] clk_5MHz_counter;
	always @(posedge clk) begin
		if (!resetn) begin
				clk_5MHz_counter <= 0;
				clk_5MHz <= 0;
		end else begin
			if (|clk_5MHz_counter) begin
				clk_5MHz_counter <= clk_5MHz_counter -1;
			end else begin
				clk_5MHz_counter <= 1;
				clk_5MHz <= !clk_5MHz;
			end
		end
	end

	// FPS-clock
	reg        fps_clk;
	reg [19:0] fps_clk_counter;
	always @(posedge clk) begin
		if (!resetn) begin
				fps_clk_counter <= 0;
				fps_clk <= 0;
		end else begin
			if (fps_clk_counter) begin
				fps_clk_counter <= fps_clk_counter -1;
				fps_clk <= 0;
			end else begin
//				fps_clk_counter <= 749999;
				fps_clk_counter <= 89999;
				fps_clk <= 1;
			end
		end
	end


	// ws2812b output
	localparam LEDCOUNT = 36;
	reg  [LEDCOUNT-1:0] red       = 36'b0000_00000000_00000000_00000000_00000001;
	reg  [LEDCOUNT-1:0] green     = 36'b0000_00000000_00000000_00000000_00000010;
	reg  [LEDCOUNT-1:0] blue      = 36'b0000_00000000_00000000_00000000_00000100;
	reg  [LEDCOUNT-1:0] red_int;
	reg  [LEDCOUNT-1:0] green_int;
	reg  [LEDCOUNT-1:0] blue_int;
	reg  [5:0] LED_counter;
	wire bitstream_read;
	reg  bitstream_available;
	reg  start;
	wire [23:0] bitstream;
	// generation of the bitstream
	always @(posedge clk) begin
		if (!resetn) begin
			LED_counter <= 0;
		end else begin
			if (bitstream_read) begin
				// reset available bit once read bit comes high
				bitstream_available <= 0;
			end
			if ((LED_counter > 0) && bitstream_read || start) begin
				start <= 0;
				// build bitstream for next LED
				bitstream = {6'b0, blue_int[0],  1'b0,
				             6'b0, red_int[0],   1'b0,
				             6'b0, green_int[0], 1'b0};
				bitstream_available <= 1;
				LED_counter <= LED_counter - 1;
				// rotate internal copies of the respect color
				red_int   <= {red_int[0],   red_int[LEDCOUNT-1:1]};
				green_int <= {green_int[0], green_int[LEDCOUNT-1:1]};
				blue_int  <= {blue_int[0],  blue_int[LEDCOUNT-1:1]};
			end
			if ((!LED_counter) && fps_clk) begin
				// after sending all LEDs wait for the fps_clk signal
				LED_counter <= LEDCOUNT+1;
				start <= 1;
				red_int <= red;
				blue_int <= blue;
				green_int <= green;
			end
		end
	end
	// actual output of the bitstream
	wire ws2812b_data;
	wire [3:0] ws2812b_debug_info;
	ws2812b_out_module #(.CYCLES_SHORT(3),
	                     .CYCLES_LONG(5),
	                     .CYCLES_RET(450))
	ws2812b_out_int_01 (
                     .clk(clk),
                     .resetn(resetn),
                     .bitstream_available(bitstream_available),
                     .bitstream(bitstream),
                     .bitstream_read(bitstream_read),
                     .ws2812b_data(ws2812b_data),
                     .debug_info(ws2812b_debug_info)
	                );
	assign pmod1_1 = ws2812b_data;

	assign {pmod4_4, pmod4_3, pmod4_2, pmod4_1,
	        pmod2_4, pmod2_3, pmod2_2, pmod2_1} = //debug_info;
	        {ws2812b_debug_info[3:0],
	         fps_clk, clk_5MHz, clk, resetn};


	always @(posedge clk) begin
		if (!resetn) begin
			// reset
			
		end
		else if (fps_clk) begin
			red <= {red[0], red[35:1]};
		end
	end


	// Simple Example Design

/*	// instatiation of a SPI slave
	localparam CPOL = 0;
	localparam CPHA = 0;
	localparam LSBFIRST = 1;

	wire [7:0] spi_value;
	wire       spi_first_byte;

	spi_slave #(.CPOL(CPOL),
	            .CPHA(CPHA),
	            .LSBFIRST(LSBFIRST))
	spi_slave_int (.clk(clk_25mhz),
	               .spi_clk(rpi_ice_clk),
	               .spi_mosi(rpi_ice_mosi),
	               .spi_cs(rpi_ice_ss),
	               .read_value(spi_value),
	               .done(spi_done),
	               .first_byte(spi_first_byte)
//	               , .debug_info(spi_debug_info)
	               ); // */

	// assign pins to value of leds
	assign {led3, led2, led1} = {ws2812b_data, resetn, !fps_clk};
endmodule
