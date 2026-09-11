# 32-bit 5-Stage Pipelined MIPS Processor

> A complete Register Transfer Level (RTL) implementation of a 32-bit MIPS processor featuring a 5-stage pipeline, designed in Verilog HDL.

## Repository Structure

```text
├── asm_test/   # MIPS Assembly test scripts and generated Hex machine code
├── docs/       # Project reports, presentation slides, and waveform images
├── src/        # Verilog HDL source files (Datapath, Controller, Hazard Units)
├── tb/         # Testbench files for ModelSim verification
└── README.md
```

## Overview
This repository contains the hardware design and verification environment for a MIPS32 microarchitecture. The processor divides instruction execution into five independent stages (IF, ID, EX, MEM, WB) to achieve high throughput and instruction-level parallelism. The RTL design natively handles data and control hazards and has been fully verified through simulation.

## Supported Instructions
The processor supports a comprehensive subset of the MIPS32 instruction set:
* **R-Type:** `add`, `sub`, `and`, `or`, `nor`, `xor`, `slt`, `sll`, `srl`
* **I-Type:** `addi`, `andi`, `ori`, `lw`, `sw`, `beq`, `bne`
* **J-Type:** `jump`

## Key Features
* **Data Hazard Resolution:** Integrates a Forwarding Unit to bypass data dependencies across pipeline stages without stalling.
* **Load-Use Handling:** Features a Hazard Detection Unit that automatically inserts pipeline bubbles (stalls) when a memory read dependency is detected.
* **Control Hazard Mitigation:** Employs a hardware Flush mechanism to invalidate incorrect instruction fetches during branch operations.

## Synthesis & Timing Analysis Results
While physical FPGA deployment is a future step, the RTL design was synthesized using Quartus II targeted at the **Cyclone II (EP2C35F672C6)** FPGA to evaluate hardware resource utilization and theoretical performance. 
* **Total Logic Elements:** 2,967 (9% utilization)
* **Dedicated Logic Registers:** 1,493 (4% utilization)
* **Maximum Frequency (Fmax):** 68.59 MHz (Slow Model)
* **Minimum Clock Period:** T_min ≈ 14.58 ns

## How to Run & Simulate
The processor's functionality is verified entirely via RTL simulation. Follow these steps to generate machine code and simulate the design:

### 1. Generate Machine Code (Using MARS 4.5)
* Open your MIPS Assembly test script (`.asm` file) from the `asm_test/` directory in the **MARS 4.5** simulator.
* Click the **Assemble** button (or press `F3`) to compile the assembly code.
* Go to **File -> Dump Memory**, select the **Hexadecimal Text** format, and export the file.
* Rename the exported file to `instruction.txt` and place it in the `src/` directory (alongside the `IMEM.v` module).

### 2. Run RTL Simulation (Using ModelSim)
* Open **ModelSim** and create a new project.
* Add all Verilog files (`.v`) from the `src/` and `tb/` directories to the project and click **Compile All**.
* Start a simulation on the top-level testbench module (`tb_toplevel.v`).
* Add critical signals to the Wave window (e.g., `clk`, `pc_out`, `writeback`, `rd`, and hazard control flags).
* **Run** the simulation (e.g., type `run 3000ns` in the transcript) to observe the 5-stage pipeline execution, data forwarding, and hazard stalling in the waveform viewer.

---
*Developed by Võ Thanh Toàn and Trương Đình Trọng at Trường Đại học Công nghệ Thông tin (UIT) - ĐHQG-HCM.*
