#!/bin/bash

ebmc counter.sv -D FORMAL --top counter --bound 20 --systemverilog --trace --waveform --vcd counter.vcd

