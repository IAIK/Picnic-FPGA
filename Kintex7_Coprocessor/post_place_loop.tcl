# Post Place PhysOpt Looping
set NLOOPS 5
set TNS_PREV 0
set WNS_SRCH_STR "WNS="
set TNS_SRCH_STR "TNS="

set PROJ_DIR [get_property directory [current_project]]

set WNS [ exec grep $WNS_SRCH_STR runme.log | tail -1 | sed -n -e "s/^.*$WNS_SRCH_STR//p" | cut -d\  -f 1]
set TNS [ exec grep $TNS_SRCH_STR runme.log | tail -1 | sed -n -e "s/^.*$TNS_SRCH_STR//p" | cut -d\  -f 1]

if {$WNS < 0.000} {
  puts "-------------------------------------------------------------------------"
  puts "-------------------------------------------------------------------------"
  puts "STARTING CUSTOM OPTIMIZER!"
  puts "project_dir: $PROJ_DIR"
  puts "TNS: $TNS"
  puts "WNS: $WNS"
  puts "-------------------------------------------------------------------------"
  puts "-------------------------------------------------------------------------\n"

  # add over constraining
  set_clock_uncertainty 0.200 [get_clocks clk_125mhz]

  for {set i 0} {$i < $NLOOPS} {incr i} {

    set WNS [ exec grep $WNS_SRCH_STR runme.log | tail -1 | sed -n -e "s/^.*$WNS_SRCH_STR//p" | cut -d\  -f 1]
    set TNS [ exec grep $TNS_SRCH_STR runme.log | tail -1 | sed -n -e "s/^.*$TNS_SRCH_STR//p" | cut -d\  -f 1]

    puts "-------------------------------------------------------------------------"
    puts "-------------------------------------------------------------------------"
    puts "run $i:"
    puts "TNS: $TNS"
    puts "WNS: $WNS"
    puts "-------------------------------------------------------------------------"
    puts "-------------------------------------------------------------------------\n"

    phys_opt_design -directive AggressiveExplore

    set WNS [ exec grep $WNS_SRCH_STR runme.log | tail -1 | sed -n -e "s/^.*$WNS_SRCH_STR//p" | cut -d\  -f 1]
    set TNS [ exec grep $TNS_SRCH_STR runme.log | tail -1 | sed -n -e "s/^.*$TNS_SRCH_STR//p" | cut -d\  -f 1]

    if {($TNS == $TNS_PREV && $i > 0) || $WNS >= 0.000} {
      break
    }
    set TNS_PREV $TNS

    phys_opt_design -directive AggressiveFanoutOpt

    set WNS [ exec grep $WNS_SRCH_STR runme.log | tail -1 | sed -n -e "s/^.*$WNS_SRCH_STR//p" | cut -d\  -f 1]
    set TNS [ exec grep $TNS_SRCH_STR runme.log | tail -1 | sed -n -e "s/^.*$TNS_SRCH_STR//p" | cut -d\  -f 1]

    if {($TNS == $TNS_PREV && $i > 0) || $WNS >= 0.000} {
      break
    }
    set TNS_PREV $TNS

    phys_opt_design -directive AlternateReplication

    set WNS [ exec grep $WNS_SRCH_STR runme.log | tail -1 | sed -n -e "s/^.*$WNS_SRCH_STR//p" | cut -d\  -f 1]
    set TNS [ exec grep $TNS_SRCH_STR runme.log | tail -1 | sed -n -e "s/^.*$TNS_SRCH_STR//p" | cut -d\  -f 1]

    if {($TNS == $TNS_PREV) || $WNS >= 0.000} {
      break
    }
    set TNS_PREV $TNS
  }

  # remove over constraining
  set_clock_uncertainty 0 [get_clocks clk_125mhz]

  report_timing_summary -file $PROJ_DIR/post_place_physopt_tim.rpt
  report_design_analysis -logic_level_distribution -of_timing_paths [get_timing_paths -max_paths 10000  -slack_lesser_than 0] -file $PROJ_DIR/post_place_physopt_vios.rpt
  write_checkpoint -force $PROJ_DIR/post_place_physopt.dcp

  set WNS [ exec grep $WNS_SRCH_STR runme.log | tail -1 | sed -n -e "s/^.*$WNS_SRCH_STR//p" | cut -d\  -f 1]
  set TNS [ exec grep $TNS_SRCH_STR runme.log | tail -1 | sed -n -e "s/^.*$TNS_SRCH_STR//p" | cut -d\  -f 1]

  puts "-------------------------------------------------------------------------"
  puts "-------------------------------------------------------------------------"
  puts "CUSTOM OPTIMIZER DONE!"
  puts "TNS: $TNS"
  puts "WNS: $WNS"
  puts "-------------------------------------------------------------------------"
  puts "-------------------------------------------------------------------------\n"
}
