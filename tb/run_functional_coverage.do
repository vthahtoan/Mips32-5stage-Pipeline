catch {quit -sim}
onerror {quit -code 1 -f}
set project_dir [file normalize ..]
set tb_dir [file join $project_dir tb]
set rtl_dir [file join $project_dir src]
set run_dir [file join $tb_dir functional_coverage_run]
file mkdir $run_dir
file copy -force [file join $project_dir instruction.txt] [file join $run_dir instruction.txt]
cd $run_dir
transcript file [file join $run_dir functional_coverage_suite.log]
transcript on
set lib_dir [file join $run_dir coverage_work]
if {![file isdirectory $lib_dir]} {vlib $lib_dir}
set rtl_files [list]
foreach name {ALU ALUControl Controller DMEM EX_MEM_reg Extender Forwarding HazardDetection ID_EX_reg IF_ID_reg IMEM MEM_WB_reg PC RegisterFile toplevel} {
    lappend rtl_files [file join $rtl_dir [format "%s.v" $name]]
}
eval vlog -work [list $lib_dir] $rtl_files
set sv_files [list]
foreach name {mips_instruction_pkg.sv mips_reference_pkg.sv mips_scoreboard_pkg.sv mips_random_pkg.sv mips_random_memory_pkg.sv mips_random_branch_pkg.sv mips_coverage_pkg.sv tb_mips_scoreboard.sv tb_mips_random_alu.sv tb_mips_random_memory.sv tb_mips_random_branch.sv mips_coverage_monitor.sv tb_mips_coverage.sv tb_mips_coverage_monitor_check.sv} {
    lappend sv_files [file join $tb_dir $name]
}
eval vlog -sv -work [list $lib_dir] $sv_files
if {![info exists coverage_seeds]} {set coverage_seeds {1 7 42 2026}}
if {![info exists coverage_require_full]} {set coverage_require_full 0}
if {[llength $coverage_seeds] < 1} {error "Supply at least one coverage seed"}
if {[llength [lsort -unique $coverage_seeds]] != [llength $coverage_seeds]} {error "Coverage seeds must be distinct for unique UCDB test names"}
if {$coverage_require_full ni {0 1}} {error "coverage_require_full must be 0 or 1"}
foreach cov_seed $coverage_seeds {
    if {![string is integer -strict $cov_seed] || $cov_seed < 1 || $cov_seed > 2147483647} {
        error "Coverage seeds must be positive signed 32-bit integers"
    }
}
set coverage_plan [list \
    [list instruction_mask {ADDI ANDI ORI SW LW ADD SUB AND OR NOR XOR SLT SLL SRL BEQ BNE J}] \
    [list immediate_mask {zero one max_positive min_negative all_ones other}] \
    [list shift_mask {SLL_zero SLL_middle SLL_31 SRL_zero SRL_middle SRL_31}] \
    [list destination_mask {nonzero r0}] \
    [list memory_address_mask {LW_first LW_interior LW_last SW_first SW_interior SW_last}] \
    [list memory_offset_mask {LW_negative LW_zero LW_positive SW_negative SW_zero SW_positive}] \
    [list load_destination_mask {LW_nonzero LW_r0}] \
    [list branch_outcome_mask {BEQ_not_taken BEQ_taken BNE_not_taken BNE_taken}] \
    [list branch_direction_mask {forward_or_zero backward}] \
    [list jump_mask {accepted cancelled_by_branch}] \
    [list hazard_mask {load_to_ALU load_to_store_data load_to_branch}] \
    [list forwarding_mask {A_register_file A_EX_MEM A_MEM_WB B_register_file B_EX_MEM B_MEM_WB}] \
    [list load_distance_mask {immediate_use one_instruction_gap}]]
array unset coverage_merged
foreach group $coverage_plan {set coverage_merged([lindex $group 0]) 0}
set coverage_files [list]
set coverage_total_runs 0
set coverage_total_checks 0
set coverage_total_events 0

vsim -coverage -voptargs=+acc -onfinish stop -lib $lib_dir tb_mips_coverage_monitor_check
onbreak {resume}
run -all
if {[examine -radix decimal sim:/tb_mips_coverage_monitor_check/test_completed] != 1} {
    error "Functional coverage monitor self-check did not complete"
}
echo "COVERAGE MONITOR SELFTEST PASS: artificial events excluded from CPU coverage"
catch {quit -sim}

proc cov_get {prefix field} {return [examine -radix decimal $prefix/$field]}
proc cov_run {family family_name run_name plusargs directed_test} {
    global lib_dir run_dir coverage_plan coverage_merged coverage_files
    global coverage_total_runs coverage_total_checks coverage_total_events
    catch {quit -sim}
    eval vsim -coverage -voptargs=+acc -onfinish stop -lib [list $lib_dir] -gFAMILY=$family tb_mips_coverage $plusargs
    onbreak {resume}
    run -all
    set native sim:/tb_mips_coverage/$family_name/test
    set monitor sim:/tb_mips_coverage/monitor
    set errors [cov_get $native scoreboard_errors]
    set checks [cov_get $native scoreboard_checks]
    set words [cov_get $native program_words]
    set steps [cov_get $native model_steps]
    set observer_errors [cov_get $monitor monitor_errors]
    set events [cov_get $monitor sampled_events]
    if {$family == 0} {
        set completed [expr {$checks == 293 && [cov_get $native errors] == 0 && [cov_get $native model_errors] == 0}]
        set signals 0
        if {[cov_get $native model_checks] != [lindex {33 23 30} $directed_test] ||
            [cov_get $native encoder_checks] != [lindex {33 22 37} $directed_test] ||
            $words != [lindex {33 22 37} $directed_test] || $steps != [lindex {33 22 28} $directed_test]} {
            error "Coverage directed baseline incomplete: $run_name"
        }
    } else {
        set completed [cov_get $native test_completed]
        set signals [cov_get $native signal_errors]
        set expected_words [lindex {0 95 127 175} $family]
        set expected_calls [lindex {0 95 47 43} $family]
        if {$words != $expected_words || [cov_get $native randomizations] != $expected_calls} {
            error "Coverage random program incomplete: $run_name"
        }
        if {$family < 3 && $steps != $words} {error "Coverage straight-line model incomplete: $run_name"}
        if {$family == 2 && [cov_get $native loaded_scenarios] != 15} {error "Missing memory scenarios"}
        if {$family == 3 && ([cov_get $native loaded_scenarios] != 255 || $steps != [cov_get $native expected_steps])} {
            error "Missing branch scenarios or model steps"
        }
    }
    set required_checks [expr {$family < 2 ? 293 : 295}]
    echo "COVERAGE RUN RESULT: name=$run_name completed=$completed errors=$errors signal_errors=$signals monitor_errors=$observer_errors checks=$checks sampled_events=$events model_steps=$steps"
    if {$completed != 1 || $errors != 0 || $signals != 0 || $observer_errors != 0 ||
        $checks != $required_checks || $events != $steps} {
        error "Coverage regression or sampling failed: $run_name"
    }
    foreach group $coverage_plan {
        lassign $group field labels
        set value [cov_get $monitor $field]
        set maximum [expr {(1 << [llength $labels]) - 1}]
        if {$value < 0 || $value > $maximum} {error "Invalid coverage mask: $run_name $field=$value"}
        set coverage_merged($field) [expr {$coverage_merged($field) | $value}]
    }
    set database [file join $run_dir ${run_name}.ucdb]
    coverage save -cvg -testname $run_name $database
    if {![file exists $database] || [file size $database] == 0} {error "UCDB not saved: $run_name"}
    lappend coverage_files $database
    incr coverage_total_runs
    incr coverage_total_checks $checks
    incr coverage_total_events $events
    echo "COVERAGE RUN PASS: $run_name"
}

foreach directed_test {0 1 2} {
    cov_run 0 directed directed_$directed_test [list +TEST=$directed_test] $directed_test
}
foreach cov_seed $coverage_seeds {
    cov_run 1 alu alu_seed_$cov_seed [list +SEED=$cov_seed +RANDOM_WORDS=64] -1
    cov_run 2 memory memory_seed_$cov_seed [list +SEED=$cov_seed +RANDOM_BLOCKS=16] -1
    cov_run 3 branch branch_seed_$cov_seed [list +SEED=$cov_seed +RANDOM_BLOCKS=12] -1
}
echo "COVERAGE REGRESSION PASS: $coverage_total_runs runs, $coverage_total_checks CPU checks, $coverage_total_events observed executed instructions"

set plan_report [file join $run_dir coverage_plan.txt]
set channel [open $plan_report w]
puts $channel "Initial MIPS functional coverage plan: 64 bins (not all possible CPU behavior)."
puts $channel "Only DUT events from passing tests are merged. No code coverage is requested."
set coverage_plan_hit 0
set coverage_plan_total 0
foreach group $coverage_plan {
    lassign $group field labels
    set hits 0
    set missing [list]
    for {set index 0} {$index < [llength $labels]} {incr index} {
        if {$coverage_merged($field) & (1 << $index)} {incr hits} else {lappend missing [lindex $labels $index]}
    }
    incr coverage_plan_hit $hits
    incr coverage_plan_total [llength $labels]
    set line "${field}: $hits/[llength $labels] missing={$missing}"
    puts $channel $line
    echo $line
}
set percentage [format %.2f [expr {100.0*$coverage_plan_hit/$coverage_plan_total}]]
set summary "FUNCTIONAL COVERAGE PLAN: $coverage_plan_hit/$coverage_plan_total bins ($percentage%)"
puts $channel $summary
close $channel
echo $summary

catch {quit -sim}
set vcover_tool [auto_execok vcover]
if {$vcover_tool eq ""} {error "vcover not found; passing run UCDBs and coverage_plan.txt are retained"}
set merged_database [file join $run_dir mips_functional_merged.ucdb]
set merge_output [exec {*}$vcover_tool merge -64 -mergedesigndiffs $merged_database {*}$coverage_files 2>@1]
echo $merge_output
set native_report [file join $run_dir functional_coverage_report.txt]
set report_output [exec {*}$vcover_tool report -64 -cvg -details $merged_database 2>@1]
set channel [open $native_report w]
puts $channel $report_output
close $channel
echo "FUNCTIONAL COVERAGE FILES: $merged_database $native_report $plan_report"
if {$coverage_plan_hit == $coverage_plan_total} {
    echo "FUNCTIONAL COVERAGE PLAN CLOSED: all 64 planned bins hit; scope is this initial plan"
} else {
    echo "FUNCTIONAL COVERAGE GAPS: [expr {$coverage_plan_total - $coverage_plan_hit}] planned bins need additional stimulus"
    if {$coverage_require_full} {error "Functional coverage plan is not closed"}
}
echo "FUNCTIONAL COVERAGE RUN COMPLETE: regression passed and UCDB/text reports saved"
