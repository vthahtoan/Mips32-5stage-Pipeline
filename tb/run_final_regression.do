catch {quit -sim}
onerror {quit -code 1 -f}
set final_tb_dir [file normalize [pwd]]
set final_project_dir [file dirname $final_tb_dir]
if {![file isdirectory [file join $final_project_dir src]]} {
    error "Start run_final_regression.do from the project tb directory"
}
set final_parent [file join $final_tb_dir final_regression_run]
file mkdir $final_parent
set final_stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set final_evidence_dir [file join $final_parent $final_stamp]
set final_suffix 0
while {[file exists $final_evidence_dir]} {
    incr final_suffix
    set final_evidence_dir [file join $final_parent ${final_stamp}_$final_suffix]
}
file mkdir $final_evidence_dir
set final_summary [file join $final_evidence_dir FINAL_RESULT.txt]
set final_channel [open $final_summary w]
puts $final_channel "INCOMPLETE: final regression has started; PASS has not been established."
puts $final_channel "Evidence directory: $final_evidence_dir"
close $final_channel
echo "FINAL REGRESSION START: evidence=$final_evidence_dir"

set final_inputs [list instruction.txt]
foreach final_name {ALU ALUControl Controller DMEM EX_MEM_reg Extender Forwarding HazardDetection ID_EX_reg IF_ID_reg IMEM MEM_WB_reg PC RegisterFile toplevel} {
    lappend final_inputs src/$final_name.v
}
foreach final_name {mips_instruction_pkg.sv mips_reference_pkg.sv mips_scoreboard_pkg.sv mips_random_pkg.sv mips_random_memory_pkg.sv mips_random_branch_pkg.sv mips_coverage_pkg.sv tb_mips_scoreboard.sv tb_mips_random_alu.sv tb_mips_random_memory.sv tb_mips_random_branch.sv mips_coverage_monitor.sv tb_mips_coverage.sv tb_mips_coverage_monitor_check.sv run_scoreboard.do run_scoreboard_negative.do run_functional_coverage.do run_final_regression.do} {
    lappend final_inputs tb/$final_name
}
foreach final_relative $final_inputs {
    set final_source [file join $final_project_dir $final_relative]
    if {![file isfile $final_source]} {error "Required source missing: $final_source"}
    set final_snapshot [file join $final_evidence_dir sources $final_relative]
    file mkdir [file dirname $final_snapshot]
    file copy $final_source $final_snapshot
}

cd $final_tb_dir
do [file join $final_tb_dir run_scoreboard_negative.do]
onerror {quit -code 1 -f}
if {$reference_total_checks != 879 || $reference_total_model_checks != 86 ||
    $reference_total_encodings != 92 || $reference_all_loaded_kinds != 131071 ||
    $negative_name ne "MEMORY" || $negative_errors != 1 || $negative_checks != 293} {
    error "Final directed/negative suite did not complete with expected results"
}
set final_directed_checks $reference_total_checks
catch {quit -sim}
transcript off
set final_negative_log [file join $final_tb_dir scoreboard_run scoreboard_negative.log]
if {![file isfile $final_negative_log] || [file size $final_negative_log] == 0} {
    error "Directed/negative transcript was not saved"
}
file copy $final_negative_log [file join $final_evidence_dir scoreboard_negative.log]

cd $final_tb_dir
set coverage_seeds {1 7 42 2026}
set coverage_require_full 1
do [file join $final_tb_dir run_functional_coverage.do]
onerror {quit -code 1 -f}
if {$coverage_total_runs != 15 || $coverage_total_checks != 4411 ||
    $coverage_plan_hit != 64 || $coverage_plan_total != 64} {
    error "Final functional regression or 64-bin plan did not complete"
}
transcript off
foreach final_name {functional_coverage_suite.log coverage_plan.txt functional_coverage_report.txt mips_functional_merged.ucdb} {
    set final_source [file join $final_tb_dir functional_coverage_run $final_name]
    if {![file isfile $final_source] || [file size $final_source] == 0} {
        error "Required coverage evidence missing: $final_source"
    }
    file copy $final_source [file join $final_evidence_dir $final_name]
}

foreach final_relative $final_inputs {
    set final_channel [open [file join $final_project_dir $final_relative] rb]
    set final_current [read $final_channel]
    close $final_channel
    set final_channel [open [file join $final_evidence_dir sources $final_relative] rb]
    set final_saved [read $final_channel]
    close $final_channel
    if {$final_current ne $final_saved} {error "Source changed during final regression: $final_relative"}
}
set final_tool_version "Unavailable; retain the Questa header in the suite logs."
set final_vsim_tool [auto_execok vsim]
if {$final_vsim_tool ne ""} {
    catch {set final_tool_version [exec {*}$final_vsim_tool -version 2>@1]}
}
set final_positive_checks [expr {$final_directed_checks + $coverage_total_checks}]
set final_channel [open $final_summary w]
puts $final_channel "FINAL VERIFICATION PASS"
puts $final_channel "Completed: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S %Z}]"
puts $final_channel "Tool: $final_tool_version"
puts $final_channel "Seeds: $coverage_seeds"
puts $final_channel "Positive CPU runs: 18 (3 directed baseline + 15 coverage regression)."
puts $final_channel "Positive scoreboard comparisons: $final_positive_checks (879 + 4411)."
puts $final_channel "Negative CPU runs: 2; register and memory corruption detected."
puts $final_channel "Monitor self-check: PASS; artificial events excluded from CPU coverage."
puts $final_channel "Coverage regression executed instructions: $coverage_total_events"
puts $final_channel "Functional coverage plan: 64/64 bins."
puts $final_channel "Native coverage percentages: see functional_coverage_report.txt."
puts $final_channel "Source snapshot: sources/ (inputs unchanged throughout the run)."
puts $final_channel "Scope: the documented 17-instruction MIPS subset and initial coverage plan."
puts $final_channel "Scoreboard checks final architectural state and event counts, not every retirement."
puts $final_channel "FPGA, synthesis/timing and RTL code coverage are outside this run."
close $final_channel
catch {quit -sim}
cd $final_tb_dir
transcript file [file join $final_evidence_dir final_regression.log]
transcript on
echo "FINAL VERIFICATION PASS: 18 positive CPU runs, 2 negative CPU runs, $final_positive_checks positive scoreboard comparisons, 64/64 planned bins"
echo "FINAL EVIDENCE DIRECTORY: $final_evidence_dir"
echo "Download this entire evidence directory, including sources/, before cleaning generated simulation files."
