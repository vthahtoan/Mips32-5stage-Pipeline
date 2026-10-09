catch {quit -sim}
onerror {quit -code 1 -f}
set negative_tb_dir [file join [file normalize ..] tb]
set negative_run_dir [file join $negative_tb_dir scoreboard_run]
file mkdir $negative_run_dir
transcript file [file join $negative_run_dir scoreboard_negative.log]
transcript on
do [file join $negative_tb_dir run_scoreboard.do]

onbreak {resume}
foreach negative_case {{0 1 REGISTER} {1 2 MEMORY}} {
    set negative_test [lindex $negative_case 0]
    set negative_mode [lindex $negative_case 1]
    set negative_name [lindex $negative_case 2]
    catch {quit -sim}
    vsim -voptargs=+acc -onfinish stop -lib $lib_dir tb_mips_scoreboard +TEST=$negative_test +INJECT_DUT_ERROR=$negative_mode
    run -all
    set negative_encoder [examine -radix decimal sim:/tb_mips_scoreboard/errors]
    set negative_model [examine -radix decimal sim:/tb_mips_scoreboard/model_errors]
    set negative_model_checks [examine -radix decimal sim:/tb_mips_scoreboard/model_checks]
    set negative_encodings [examine -radix decimal sim:/tb_mips_scoreboard/encoder_checks]
    set negative_errors [examine -radix decimal sim:/tb_mips_scoreboard/scoreboard_errors]
    set negative_checks [examine -radix decimal sim:/tb_mips_scoreboard/scoreboard_checks]
    echo "SCOREBOARD NEGATIVE RESULT $negative_name: encoder=$negative_encoder model=$negative_model scoreboard=$negative_errors checks=$negative_checks"
    if {$negative_encoder != 0 || $negative_model != 0 || $negative_errors != 1 || $negative_checks != 293 || $negative_model_checks != [lindex {33 23} $negative_test] || $negative_encodings != [lindex {33 22} $negative_test]} {
        error "SCOREBOARD NEGATIVE FAIL: $negative_name"
    }
    echo "SCOREBOARD NEGATIVE PASS: $negative_name corruption detected"
}
echo "SCOREBOARD NEGATIVE SUITE PASS: register and memory corruption detected"
