#!/bin/bash

ebmc packet.sv -D FORMAL --top packet --bound 20 --systemverilog --trace --waveform --vcd packet.vcd
