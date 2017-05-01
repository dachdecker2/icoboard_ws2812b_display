

module top (
	input clk_12mhz,
	      btn1, btn2,
	      rpi_ice_mosi, rpi_ice_miso, rpi_ice_clk, rpi_ice_ss, rpi_ice_ss2,
	output reg led1, led2, led3, pmod1_1,
               pmod2_1, pmod2_2, pmod2_3, pmod2_4,
               pmod4_1, pmod4_2, pmod4_3, pmod4_4
	);

	// Clock Generation

	// 3 MHz
/*	localparam DIVR = 4'b0000;
	localparam DIVF = 7'b0000111;
	localparam DIVQ = 3'b101;
	localparam FILTER_RANGE = 3'b101; // */

	// 9 MHz
	localparam DIVR = 4'b0000;
	localparam DIVF = 7'b0010111;
	localparam DIVQ = 3'b101;
	localparam FILTER_RANGE = 3'b101; // */

	wire [0:0] pll_locked;
	wire [0:0] clk_int;
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
		.PACKAGEPIN   (clk_12mhz),
		.PLLOUTGLOBAL (clk_int ),
		.LOCK         (pll_locked),
		.BYPASS       (1'b0      ),
		.RESETB       (1'b1      )
	);
	wire clk = clk_int;


	// Reset Generator
	reg [3:0] resetn_gen = 0;
	reg [0:0] resetn;
	always @(posedge clk) begin
		resetn <= &resetn_gen;
		resetn_gen <= {resetn_gen[2:0], pll_locked && !btn2};
	end


	// FPS-clock
	reg [0:0]  fps_clk;
	reg [17:0] fps_clk_counter;
	always @(posedge clk) begin
		if (!resetn) begin
			fps_clk_counter <= 0;
			fps_clk <= 0;
		end else begin
			fps_clk_counter <= fps_clk_counter ? (fps_clk_counter-1) : 89999;
			fps_clk <= !fps_clk_counter;
		end
	end


	// ws2812b output
	localparam LEDCOUNT = 36;
	reg  [LEDCOUNT-1:0] red   = 36'b1000_10000001_10000001_10000001_10000001;
	reg  [LEDCOUNT-1:0] green = 36'b1000_00000000_00000000_00000000_00000000;
	reg  [LEDCOUNT-1:0] blue  = 36'b1000_00000000_00000000_00000000_00000000;
	reg  [LEDCOUNT-1:0] red_int;
	reg  [LEDCOUNT-1:0] green_int;
	reg  [LEDCOUNT-1:0] blue_int;
	reg  [5:0] LED_counter = 0;
	wire [0:0] bitstream_read;
	reg  [0:0] bitstream_available = 0;
	reg  [0:0] start = 0;
	reg  [0:0] next_LED = 0;
	reg  [23:0] bitstream;
	// generation of the bitstream
	always @(posedge clk) begin
		if (!resetn) begin
			LED_counter <= 0;
			start <= 0;
			next_LED <= 0;
			bitstream_available <= 0;
		end else begin
			if (bitstream_read || start) begin
				start <= 0;
				bitstream_available <= 0;
				next_LED <= LED_counter > 0;
			end
			if (next_LED) begin
				next_LED <= 0;
				bitstream_available <= 1;
				LED_counter <= LED_counter - 1;
				// rotate internal copies of the respect color
				red_int   <= {red_int[0],   red_int[LEDCOUNT-1:1]};
				green_int <= {green_int[0], green_int[LEDCOUNT-1:1]};
				blue_int  <= {blue_int[0],  blue_int[LEDCOUNT-1:1]};
				// build bitstream for next LED
				bitstream <= {7'b0, green_int[0], 0'b0,
				              7'b0, red_int[0],   0'b0,
				              7'b0, blue_int[0],  0'b0};
			end
			if (fps_clk & !LED_counter) begin
				// after sending all LEDs wait for the fps_clk signal
				LED_counter <= LEDCOUNT;
				start       <= 1;
				red_int     <= red;
				green_int   <= green;
				blue_int    <= blue;
			end
		end
	end
	// actual output of the bitstream
	wire [0:0] ws2812b_data;
	wire [3:0] ws2812b_debug_info;
	ws2812b_out_module #(.CYCLES_SHORT(3), //   3 @ 9 MHz
	                     .CYCLES_LONG(5),  //   5 @ 9 MHz
	                     .CYCLES_RET(0),   // 450 @ 9 MHz, clk_fps will do this job
	                     .CYCLES_CNT_WIDTH(3))
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


	always @(posedge clk) begin
		if (!resetn) begin
			// reset
			
		end
		else if (fps_clk) begin
//			red <= {red[0], red[35:1]};
		end
	end


	// Simple Example Design

	// instatiation of a SPI slave
	localparam CPOL = 0;
	localparam CPHA = 0;
	localparam LSBFIRST = 0;

	wire [7:0] spi_value;
	wire [7:0] spi_debug_info;
	wire [0:0] spi_first_byte;
	wire [0:0] spi_done;

	always @(posedge clk) begin
		if (!resetn) begin
			
		end
		else begin
			if (spi_done) begin
				green[7:0] <= spi_value;
				blue[15:8] <= green[7:0];
				green[23:16] <= blue[15:8];
				blue[31:24] <= green[23:16];
			end
		end
	end

	spi_slave #(.CPOL(CPOL),
	            .CPHA(CPHA),
	            .LSBFIRST(LSBFIRST))
	spi_slave_int (.clk(clk),
	               .resetn(resetn),
	               .spi_clk(rpi_ice_clk),
	               .spi_mosi(rpi_ice_mosi),
	               .spi_cs(rpi_ice_ss),
	               .read_value(spi_value),
	               .done(spi_done),
	               .first_byte(spi_first_byte)
	               , .debug_info(spi_debug_info)
	               ); // */

	assign {pmod4_4, pmod4_3, pmod4_2, pmod4_1,
	        pmod2_4, pmod2_3, pmod2_2, pmod2_1} = //debug_info;
//	        {spi_debug_info[3:0],
	        {spi_debug_info[7:4],
	         rpi_ice_ss, rpi_ice_mosi, rpi_ice_clk, resetn};

	// assign pins to value of leds
	assign {led3, led2, led1} = {rpi_ice_ss, rpi_ice_ss2, !fps_clk};
endmodule
