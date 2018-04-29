

    module clk_gen (
    input        clk,
    input        resetn,
    output [0:0] clk_out
    );

    parameter CLK_CYCLES = 10;

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


    `ifdef FORMAL
        `timescale 1 ns / 100 ps
        reg [$clog2(CLK_CYCLES):0] clk_counter_pre;        // previus clk state
//        integer counter = 0;
        reg [10:0] _tst_counter = 0;
        reg [0:0] clk = 0;
//        reg [0:0] resetn = 0;
//        wire [0:0] resetn;

        initial begin
            clk_counter_pre = 0;//CLK_CYCLES-1;
            clk = 0;
//            resetn = 0;
            counter = 0;

//            #10 resetn <= 1;
//            #1000000000 assert (0);
        end

        assign resetn = (_tst_counter>4);

        always @(posedge clk) begin
            _tst_counter = _tst_counter + 1;
            if (_tst_counter == 5) begin
                assert (0);
//                resetn = 1;
            end

            if (!resetn) begin
                clk_counter_pre <= CLK_CYCLES-1;
//                if (counter != 0)
//                    assert (clk_out == 0);
            end else begin
//                assert (clk_counter < CLK_CYCLES);
                assert (clk_counter >= 0);

                if (clk_counter_pre == 0) begin
//                    assert (clk_out == 1);
//                    assert (clk_counter == CLK_CYCLES-1);
                end else begin
                    assert (clk_out == 0);
                    assert (clk_counter == clk_counter_pre - 1);
                end
            end
            clk_counter_pre <= clk_counter;
        end
    `endif
endmodule
