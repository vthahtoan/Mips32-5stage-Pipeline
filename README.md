# 32-bit 5-Stage Pipelined MIPS Processor

A Verilog implementation of a five-stage MIPS processor with a class-based
SystemVerilog verification environment.

The processor includes forwarding, load-use stalls and branch/jump flushing.
Verification uses directed tests, constrained-random programs, an architectural
reference model, a scoreboard and functional coverage.

## Repository Structure

```text
├── results/
├── src/
├── tb/
├── README.md
└── instruction.txt
```

- `src/`: processor RTL.
- `tb/`: SystemVerilog packages, testbenches and simulation scripts.
- `results/`: archived regression logs and coverage reports.
- `instruction.txt`: initial instruction-memory contents.

## Processor Architecture

The processor uses five pipeline stages:

1. **IF**: fetch the instruction and update the program counter.
2. **ID**: decode the instruction and read the register file.
3. **EX**: execute the operation and evaluate branches.
4. **MEM**: access data memory.
5. **WB**: write the result to the register file.

Forwarding supplies dependent operands from later pipeline stages.
The hazard detection unit inserts bubbles for load-use dependencies.
Taken branches flush younger instructions.

Branches resolve in EX, while jumps are handled in ID. An older taken branch
cancels a younger jump. This implementation uses no branch delay slot.

## Supported Instructions

The verified subset contains 17 instructions:

- **R-Type:** `add`, `sub`, `and`, `or`, `nor`, `xor`, `slt`, `sll`, `srl`
- **I-Type:** `addi`, `andi`, `ori`, `lw`, `sw`, `beq`, `bne`
- **J-Type:** `j`

## Verification Environment

```text
Generator → Encoder → CPU program
                  └→ Reference model → Expected state

CPU state and event counts → Scoreboard
CPU pipeline events → Coverage monitor → Functional coverage
```

The reference model executes the program independently of DUT results.
The scoreboard compares all 32 registers, 256 memory words and execution counts.

Expected stall counts come from pipeline scenarios because the architectural
reference model does not simulate pipeline cycles.

The environment includes:

- Directed tests for arithmetic, shifts, memory and control flow.
- Encoding and reference-model checks against known results.
- Constrained-random ALU, memory and branch/jump programs.
- Register and memory fault injection to validate scoreboard error detection.
- Functional coverage sampled from actual DUT events.
- A separate coverage-monitor self-check, excluded from CPU coverage.

## Verification Results

The archived regression completed on **9 October 2026** using
**Siemens QuestaSim 2021.2_1**.

| Metric | Result |
|---|---:|
| Positive CPU runs | 18 |
| Positive scoreboard comparisons | 5290 |
| Fault-injection runs | 2; both detected |
| Random seeds | 1, 7, 42, 2026 |
| Functional coverage plan | 64/64 bins |
| Native covergroup coverage | 100.00% |
| Covergroup types | 11 |

The positive-run totals include directed tests repeated in the baseline and
coverage regression.

Coverage includes instruction kinds, immediate and shift boundaries, register
destinations, memory address and offset classes, branch outcomes, jump
cancellation, forwarding and load-use scenarios.

Archived evidence:

- [Final result](results/FINAL_RESULT.txt)
- [Coverage plan](results/coverage_plan.txt)
- [Native coverage report](results/functional_coverage_report.txt)
- [Regression log](results/functional_coverage_suite.log)
- [Fault-injection log](results/scoreboard_negative.log)

## Running the Regression

Use a Linux environment with QuestaSim licenses supporting SystemVerilog class
randomization and functional covergroups. The commands `vsim`, `vlog` and
`vcover` must be available.

From the repository root:

```sh
cd tb
vsim -c -l final_console.log -do 'do run_final_regression.do; quit -f'
```

The script runs directed and fault-injection tests, followed by the coverage
regression. It requires all 64 planned bins to be hit.

A successful run ends with:

```text
FINAL VERIFICATION PASS
```

Fault-injection tests intentionally produce a scoreboard failure. Their expected
outcome is the subsequent negative-suite PASS.

New results and a source snapshot are saved under:

```text
tb/final_regression_run/<timestamp>/
```

The scripts copy root `instruction.txt` into the simulation working directory.
IMEM reads it at startup; the verification testbenches then replace its contents
with their own test programs.

## Verification Scope

The scoreboard checks final architectural state and event counts rather than
comparing every instruction retirement. Random memory and control-flow tests
use scenario templates with randomized operands.

Achieving 100% functional coverage closes the documented 64-bin plan. It does
not establish exhaustive CPU correctness or RTL code coverage.

Exceptions, interrupts, caches, physical FPGA deployment and the complete
MIPS ISA are outside the verified scope.

---

Developed by **Võ Thanh Toàn**  
University of Information Technology, VNU-HCM.
