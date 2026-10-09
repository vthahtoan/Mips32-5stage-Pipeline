catch {quit -sim}
onerror {quit -code 1 -f}
set project_dir [file normalize ..]
set tb_dir [file join $project_dir tb]
set rtl_dir [file join $project_dir src]
set run_dir [file join $tb_dir scoreboard_run]
file mkdir $run_dir
file copy -force [file join $project_dir instruction.txt] [file join $run_dir instruction.txt]
cd $run_dir
set lib_dir [file join $run_dir scoreboard_work]
if {![file isdirectory $lib_dir]} { vlib $lib_dir }
set rtl_files [list]
foreach name {ALU ALUControl Controller DMEM EX_MEM_reg Extender Forwarding HazardDetection ID_EX_reg IF_ID_reg IMEM MEM_WB_reg PC RegisterFile toplevel} {
    lappend rtl_files [file join $rtl_dir [format "%s.v" $name]]
}
eval vlog -work [list $lib_dir] $rtl_files
vlog -sv -work $lib_dir [file join $tb_dir mips_instruction_pkg.sv] [file join $tb_dir mips_reference_pkg.sv] [file join $tb_dir mips_scoreboard_pkg.sv] [file join $tb_dir tb_mips_scoreboard.sv]

set reference_names {ALU_AND_SHIFT MEMORY BRANCH_AND_JUMP}
set reference_expected_checks {293 293 293}
set reference_expected_model_checks {33 23 30}
set reference_expected_encodings {33 22 37}
set reference_all_loaded_kinds 0
set reference_total_checks 0
set reference_total_model_checks 0
set reference_total_encodings 0
onbreak {resume}
foreach reference_test_id {0 1 2} {
    catch {quit -sim}
    vsim -voptargs=+acc -onfinish stop -lib $lib_dir tb_mips_scoreboard +TEST=$reference_test_id
    run -all
    set reference_errors [examine -radix decimal sim:/tb_mips_scoreboard/errors]
    set reference_model_errors [examine -radix decimal sim:/tb_mips_scoreboard/model_errors]
    set reference_model_checks [examine -radix decimal sim:/tb_mips_scoreboard/model_checks]
    set reference_model_steps [examine -radix decimal sim:/tb_mips_scoreboard/model_steps]
    set reference_scoreboard_errors [examine -radix decimal sim:/tb_mips_scoreboard/scoreboard_errors]
    set reference_checks [examine -radix decimal sim:/tb_mips_scoreboard/scoreboard_checks]
    set reference_encodings [examine -radix decimal sim:/tb_mips_scoreboard/encoder_checks]
    set reference_writes [examine -radix decimal sim:/tb_mips_scoreboard/writes_seen]
    set reference_stalls [examine -radix decimal sim:/tb_mips_scoreboard/stalls_seen]
    set reference_taken [examine -radix decimal sim:/tb_mips_scoreboard/branches_taken]
    set reference_not_taken [examine -radix decimal sim:/tb_mips_scoreboard/branches_not_taken]
    set reference_jumps [examine -radix decimal sim:/tb_mips_scoreboard/jumps_seen]
    set reference_loaded_kinds [examine -radix unsigned sim:/tb_mips_scoreboard/loaded_kinds]
    set reference_name [lindex $reference_names $reference_test_id]
    echo "SCOREBOARD RESULT ${reference_name}: encoder_errors=$reference_errors scoreboard_errors=$reference_scoreboard_errors model_errors=$reference_model_errors checks=$reference_checks model_checks=$reference_model_checks model_steps=$reference_model_steps encoder_checks=$reference_encodings writes=$reference_writes stalls=$reference_stalls taken=$reference_taken not_taken=$reference_not_taken jumps=$reference_jumps"
    if {$reference_errors != 0 || $reference_scoreboard_errors != 0 || $reference_model_errors != 0 || $reference_model_checks != [lindex $reference_expected_model_checks $reference_test_id] || $reference_checks != [lindex $reference_expected_checks $reference_test_id] || $reference_encodings != [lindex $reference_expected_encodings $reference_test_id]} {
        set reference_first_failure [examine sim:/tb_mips_scoreboard/scoreboard_first_failure]
        echo "FIRST SCOREBOARD FAILURE: $reference_first_failure"
        error "SCOREBOARD FAIL: $reference_name"
    }
    echo "SCOREBOARD PASS: $reference_name"
    set reference_all_loaded_kinds [expr {$reference_all_loaded_kinds | $reference_loaded_kinds}]
    incr reference_total_checks $reference_checks
    incr reference_total_model_checks $reference_model_checks
    incr reference_total_encodings $reference_encodings
}
if {$reference_all_loaded_kinds != 131071} {
    error "SCOREBOARD FAIL: the programs did not load all 17 instruction kinds"
}
echo "SCOREBOARD SUITE PASS: 3 groups, $reference_total_checks CPU checks, $reference_total_model_checks model checks, $reference_total_encodings encoding checks, 17 instruction kinds loaded"
