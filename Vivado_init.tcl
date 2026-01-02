exec echo "successfully autosourced this file"

proc test_bruh {} {
  puts "THIS IS A TEST of the new way to do init files"
}

proc die {} {
  exit
}

proc ss {} {
 source ~/.Xilinx/Vivado/Vivado_init.tcl 
}

proc new_print {} {
  puts "this is a new item i just made"
}

proc comp {} {
  update_compile_order -fileset sources_1
  set_property core_revision 8 [ipx::current_core]
  ipx::update_source_project_archive -component [ipx::current_core]
  ipx::create_xgui_files [ipx::current_core]
  ipx::update_checksums [ipx::current_core]
  ipx::check_integrity [ipx::current_core]
  ipx::save_core [ipx::current_core]
  close_project
}

proc re_source_dma {} {
  add_files -norecurse -copy_to /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/src /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/src/dma_fifo/dma_fifo.xci -force
}

proc add_mydma {} {

}

proc mydma {} {
  puts "setting user DMA as active"

  # disable Stitt's module
  set_property is_enabled false [get_files  /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/src/dram_rd.edif]

  # enable my DMA module
  set_property is_enabled true [get_files  /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/my_files/dram_rd_v1.sv]
}

proc notmydma {} {
  puts "setting provided DMA as active"

  # enable Stitt's module
  set_property is_enabled true [get_files  /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/src/dram_rd.edif]

  # disable my DMA module
  set_property is_enabled false [get_files  /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/src/dram_rd_v1.sv]
}

proc sync {} {
  add_files -force -norecurse -copy_to /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/src /home/wayne/FPGA/final-project-final-project-group-79/dram_test/my_files/dram_rd_v1.sv
}

proc elab {} {
  refresh_design
}

proc comp2 {} {
  update_ip_catalog -rebuild -scan_changes
  report_ip_status -name ip_status
  upgrade_ip -vlnv user.org:user:dram_test:1.0 [get_ips  top_block1_dram_test_0_0] -log ip_upgrade.log
  report_ip_status -name ip_status 
  open_bd_design {/home/wayne/FPGA/test_environs/test1/test1.srcs/sources_1/bd/top_block1/top_block1.bd}
}

proc ip_edit {} {
  ipx::edit_ip_in_project -upgrade true -name dram_test_v1_0_project -directory /home/wayne/FPGA/test_environs/test1/test1.tmp/dram_test_v1_0_project /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/component.xml
  # add_files -norecurse -copy_to /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/src /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/src/dma_fifo/dma_fifo.xci -force
  # generate_target all [get_files /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/src/mmap_data_fifo/mmap_data_fifo.xci]
  # generate_target all [get_files /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/src/mmap_request_fifo/mmap_request_fifo.xci]
  # synth_design -rtl -rtl_skip_mlo -name rtl_1
}

proc firstelab {} {
  current_project dram_test_v1_0_project
  add_files -norecurse -copy_to /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/src /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/src/dma_fifo/dma_fifo.xci -force
  generate_target all [get_files /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/src/mmap_data_fifo/mmap_data_fifo.xci]
  generate_target all [get_files /home/wayne/FPGA/final-project-final-project-group-79/dram_test/dram_test_1.0/src/mmap_request_fifo/mmap_request_fifo.xci]
  synth_design -rtl -rtl_skip_mlo -name rtl_1
}

proc sim {} {
  close_sim
  launch_simulation
  # open_wave_config {/home/wayne/harn/rtl_harn1/vivado21_proj/counter_tb_behav2.wcfg}
  open_wave_config {/home/wayne/FPGA/test_environs/test1/test1.tmp/dram_test_v1_0_project/wrapper_tb_behav.wcfg}
  source wrapper_tb.tcl
  # source counter_tb.tcl
}

proc time {runtime} {
  puts "setting new sim time"
}

proc time {val} {
    set runtime "${val}ns"
    set_property -name {xsim.simulate.runtime} -value $runtime -objects [get_filesets sim_1]
    puts "Simulation runtime set to $runtime"
}

set_param board.repoPaths [list "/home/wayne/vivado_boards/board_files"]


