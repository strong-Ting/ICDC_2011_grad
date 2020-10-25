
set_host_options -max_cores 4
#Read All Files
#read_verilog ../src/lcd_ctrl.v
analyze -format verilog ../src/lcd_ctrl.v
elaborate LCD_CTRL
current_design LCD_CTRL
link

#Setting Clock Constraints
source -echo -verbose lcd_ctrl.sdc

#Synthesis all design
#compile -map_effort high -area_effort medium
#compile -map_effort high -area_effort medium -inc
compile_ultra -timing
#compile_ultra
compile_ultra -inc

write -format ddc     -hierarchy -output "lcd_ctrl_syn.ddc"
write_sdf lcd_ctrl_syn.sdf
write_file -format verilog -hierarchy -output lcd_ctrl_syn.v
report_area > area.log
report_timing > timing.log
report_qor   >  lcd_ctrl_syn.qor

