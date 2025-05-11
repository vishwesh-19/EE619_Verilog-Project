This is a course project for EE619:VLSI System Design, IITK

The pdf file contains the project description.
File "backend.v" has the verilog code for the backend module.
"FPGA_model.v" has the verilog code for FPGA signals.
"backend_tb.v" is the testbench file and also connects the backend module with the FPGA module.
"comp.vcd" contains the simulation waveforms, defined in "backend_tb.v"

Simulation commands:
iverilog -o backend_tb.vvp backend_tb.v 
vvp backend_tb.vvp 
gtkwave comp.vcd
