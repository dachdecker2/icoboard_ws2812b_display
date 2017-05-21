
ifeq ($(shell bash -c 'type -p icoprog'),)
#SSH_RASPI ?= ssh pi@raspi
SSH_RASPI ?= ssh pi@10.42.0.187
else
SSH_RASPI ?= sh -c
endif

help:
	@echo
	@echo "make top.blif      run synthesis, generate BLIF netlist"
	@echo "make top.asc       run place and route, generate IceStorm ASCII file"
	@echo "make top.bin       run timing analysis, generate iCE40 BIN file"
	@echo
	@echo "make prog_sram         FPGA SRAM programming, (re)starts FPGA from SRAM"
	@echo "make prog_flash        serial flash programming, does not touch FPGA"
	@echo "make prog_erase        erase first flash block"
	@echo
	@echo "make reset_halt        stop FPGA and keep in reset"
	@echo "make reset_boot        (re)start FPGA from serial flash"
	@echo
	@echo "make clean             remove output files"
	@echo

top.blif: top.v pll_config.v spi.v ws2812b_out.v
	yosys -p 'synth_ice40 -blif top.blif' top.v pll_config.v spi.v ws2812b_out.v > yosys.out
	sed "/Warning/p" -n < yosys.out > yosys.warnings
	cat yosys.warnings

top.asc: top.blif icoboard.pcf
	arachne-pnr -d 8k -p icoboard.pcf -o top.asc top.blif

top.bin: top.asc
	icetime -d hx8k -c 75 top.asc
	icepack top.asc top.bin

prog_sram: top.bin
	cat yosys.warnings
	$(SSH_RASPI) 'icoprog -p' < top.bin

prog_flash: top.bin
	$(SSH_RASPI) 'icoprog -f' < top.bin

prog_erase:
	$(SSH_RASPI) 'icoprog -e'

reset_halt:
	$(SSH_RASPI) 'icoprog -R'

reset_boot:
	$(SSH_RASPI) 'icoprog -b'

show:	top.v
	yosys -p 'show -stretch top' top.v
#	yosys -p 'show -stretch top' spi.v
#	yosys -p 'show -stretch top' ws2812b_out.v
#	yosys -p 'show -format ps -viewer gv' top.v

sim: spi_tb.v spi.v $(DEPS)
	iverilog -s testbench -o testbench.vvp top_tb.v top.v
	vvp testbench.vvp -lxt2
	gtkwave testbench.vcd testbench.gtkw &

clean:
	rm top.blif top.asc top.bin

.PHONY: prog_sram prog_flash reset_halt reset_boot clean

