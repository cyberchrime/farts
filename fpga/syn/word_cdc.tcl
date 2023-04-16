# Copyright (c) 2023 Chris H. Meyer
#
# This file is part of aRTS.
#
# aRTS is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# aRTS is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with aRTS. If not, see <https://www.gnu.org/licenses/>.

# Clock Domain Crossing timing constraints

foreach cdc_inst [get_cells -hier -filter {(ORIG_REF_NAME == word_cdc || REF_NAME == word_cdc)}] {
    puts "Inserting timing constraints for word_cdc instance $cdc_inst"

    set sync_reg [get_cells -hier -filter "(NAME == $cdc_inst/sync_reg_reg[0][0])"]

    set input_clk [get_clocks -of_objects [all_fanin -flat -startpoints_only $sync_reg/D]]
    set output_clk [get_clocks -of_objects [get_pins $sync_reg/C]]

    set group_name [get_property REF_NAME $cdc_inst]

    set_clock_groups -name $group_name -asynchronous \
        -group $input_clk \
        -group $output_clk

    # output register
    set input_reg_ffs [get_cells -quiet "$cdc_inst/input_reg_reg[*]"]
    set sync_reg_ffs [get_cells -quiet "$cdc_inst/sync_reg_reg[*][*]"]

    if {[llength $input_reg_ffs]} {
        set_property ASYNC_REG TRUE $input_reg_ffs
        set_property IOB FALSE $input_reg_ffs
    }

    set_property ASYNC_REG TRUE $sync_reg_ffs
    set_property IOB FALSE $sync_reg_ffs
}