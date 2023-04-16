# XDC constraints for the Digilent ZedBoard
# part:  xc7z020clg484-1

# General configuration
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]

# 100 MHz clock
#set_property PACKAGE_PIN Y9 [get_ports clk]
#create_clock -period 10.000 -name clk [get_ports clk]

# LEDs (using ZedBoard's LEDs)
set_property PACKAGE_PIN T22 [get_ports {led[0]}]
set_property PACKAGE_PIN T21 [get_ports {led[1]}]
set_property PACKAGE_PIN U22 [get_ports {led[2]}]
set_property PACKAGE_PIN U21 [get_ports {led[3]}]
set_property PACKAGE_PIN V22 [get_ports {led[4]}]
set_property PACKAGE_PIN W22 [get_ports {led[5]}]
set_property PACKAGE_PIN U19 [get_ports {led[6]}]
set_property PACKAGE_PIN U14 [get_ports {led[7]}]

set_false_path -to [get_ports {led[*]}]
set_output_delay 0.000 [get_ports {led[*]}]

# Reset button
#set_property PACKAGE_PIN R18 [get_ports reset]

#set_false_path -from [get_ports reset]
#set_input_delay 0.000 [get_ports reset]

# Push buttons
#set_property PACKAGE_PIN P16 [get_ports btnu]
#set_property PACKAGE_PIN R16 [get_ports btnd]
#set_property PACKAGE_PIN N15 [get_ports btnl]
#set_property PACKAGE_PIN R18 [get_ports btnr]
#set_property PACKAGE_PIN T18 [get_ports btnu]

#set_false_path -from [get_ports {btnu btnl btnd btnr btnc}]
#set_input_delay 0 [get_ports {btnu btnl btnd btnr btnc}]

# Toggle switches
#set_property PACKAGE_PIN F22 [get_ports {sw[0]}]
#set_property PACKAGE_PIN G22 [get_ports {sw[1]}]
#set_property PACKAGE_PIN H22 [get_ports {sw[2]}]
#set_property PACKAGE_PIN F21 [get_ports {sw[3]}]
#set_property PACKAGE_PIN H19 [get_ports {sw[4]}]
#set_property PACKAGE_PIN H18 [get_ports {sw[5]}]
#set_property PACKAGE_PIN H17 [get_ports {sw[6]}]
#set_property PACKAGE_PIN M15 [get_ports {sw[7]}]

#set_false_path -from [get_ports {sw[*]}]
#set_input_delay 0 [get_ports {sw[*]}]

# UART
#set_property PACKAGE_PIN Y11 [get_ports uart_txd]
#set_property PACKAGE_PIN AA11 [get_ports uart_rxd]

#set_false_path -to [get_ports {uart_txd}]
#set_output_delay 0 [get_ports {uart_txd}]
#set_false_path -from [get_ports {uart_rxd}]
#set_input_delay 0 [get_ports {uart_rxd}]


# Gigabit Ethernet RGMII PHY (PORT1)
set_property PACKAGE_PIN M19 [get_ports phy1_rgmii_rx_clk]
set_property PACKAGE_PIN P17 [get_ports {phy1_rgmii_rxd[0]}]
set_property PACKAGE_PIN P18 [get_ports {phy1_rgmii_rxd[1]}]
set_property PACKAGE_PIN N22 [get_ports {phy1_rgmii_rxd[2]}]
set_property PACKAGE_PIN P22 [get_ports {phy1_rgmii_rxd[3]}]
set_property PACKAGE_PIN M20 [get_ports phy1_rgmii_rx_ctl]
set_property PACKAGE_PIN M22 [get_ports phy1_rgmii_tx_clk]
set_property PACKAGE_PIN M21 [get_ports {phy1_rgmii_txd[0]}]
set_property PACKAGE_PIN J21 [get_ports {phy1_rgmii_txd[1]}]
set_property PACKAGE_PIN J22 [get_ports {phy1_rgmii_txd[2]}]
set_property PACKAGE_PIN T16 [get_ports {phy1_rgmii_txd[3]}]
set_property PACKAGE_PIN T17 [get_ports phy1_rgmii_tx_ctl]
set_property PACKAGE_PIN K18 [get_ports phy1_reset_n]

set_property PACKAGE_PIN J18 [get_ports phy1_mdc]
set_property PACKAGE_PIN L22 [get_ports phy1_mdio]

set_false_path -to [get_ports phy1_reset_n]
set_output_delay 0.000 [get_ports phy1_reset_n]

create_clock -period 8.000 -name phy1_rgmii_rx_clk [get_ports phy1_rgmii_rx_clk]

# Gigabit Ethernet RGMII PHY (PORT2)
set_property PACKAGE_PIN N19 [get_ports phy2_rgmii_rx_clk]
set_property PACKAGE_PIN L21 [get_ports {phy2_rgmii_rxd[0]}]
set_property PACKAGE_PIN R20 [get_ports {phy2_rgmii_rxd[1]}]
set_property PACKAGE_PIN T19 [get_ports {phy2_rgmii_rxd[2]}]
set_property PACKAGE_PIN R21 [get_ports {phy2_rgmii_rxd[3]}]
set_property PACKAGE_PIN N20 [get_ports phy2_rgmii_rx_ctl]
set_property PACKAGE_PIN N18 [get_ports phy2_rgmii_tx_clk]
set_property PACKAGE_PIN P21 [get_ports {phy2_rgmii_txd[0]}]
set_property PACKAGE_PIN N17 [get_ports {phy2_rgmii_txd[1]}]
set_property PACKAGE_PIN J20 [get_ports {phy2_rgmii_txd[2]}]
set_property PACKAGE_PIN K21 [get_ports {phy2_rgmii_txd[3]}]
set_property PACKAGE_PIN J16 [get_ports phy2_rgmii_tx_ctl]
set_property PACKAGE_PIN J17 [get_ports phy2_reset_n]

set_property PACKAGE_PIN M17 [get_ports phy2_mdc]
set_property PACKAGE_PIN K20 [get_ports phy2_mdio]

set_false_path -to [get_ports phy2_reset_n]
set_output_delay 0.000 [get_ports phy2_reset_n]

create_clock -period 8.000 -name phy2_rgmii_rx_clk [get_ports phy2_rgmii_rx_clk]

# ----------------------------------------------------------------------------
# IOSTANDARD Constraints
#
# Note that these IOSTANDARD constraints are applied to all IOs currently
# assigned within an I/O bank.  If these IOSTANDARD constraints are
# evaluated prior to other PACKAGE_PIN constraints being applied, then
# the IOSTANDARD specified will likely not be applied properly to those
# pins.  Therefore, bank wide IOSTANDARD constraints should be placed
# within the XDC file in a location that is evaluated AFTER all
# PACKAGE_PIN constraints within the target bank have been evaluated.
#
# Un-comment one or more of the following IOSTANDARD constraints according to
# the bank pin assignments that are required within a design.
# ----------------------------------------------------------------------------

# Note that the bank voltage for IO Bank 33 is fixed to 3.3V on ZedBoard.
set_property IOSTANDARD LVCMOS33 [get_ports -of_objects [get_iobanks 33]]

# Set the bank voltage for IO Bank 34 to 1.8V by default.
# set_property IOSTANDARD LVCMOS33 [get_ports -of_objects [get_iobanks 34]];
# set_property IOSTANDARD LVCMOS25 [get_ports -of_objects [get_iobanks 34]];
set_property IOSTANDARD LVCMOS18 [get_ports -of_objects [get_iobanks 34]]

set_property SLEW FAST [get_ports phy1_rgmii_tx_clk]
set_property SLEW FAST [get_ports phy1_rgmii_tx_ctl]
set_property SLEW FAST [get_ports {phy1_rgmii_txd[0]}]
set_property SLEW FAST [get_ports {phy1_rgmii_txd[1]}]
set_property SLEW FAST [get_ports {phy1_rgmii_txd[2]}]
set_property SLEW FAST [get_ports {phy1_rgmii_txd[3]}]
set_property SLEW FAST [get_ports phy1_mdc]
set_property SLEW FAST [get_ports phy1_mdio]
set_property SLEW FAST [get_ports phy1_reset_n]
set_property SLEW FAST [get_ports phy2_rgmii_tx_clk]
set_property SLEW FAST [get_ports phy2_rgmii_tx_ctl]
set_property SLEW FAST [get_ports {phy2_rgmii_txd[0]}]
set_property SLEW FAST [get_ports {phy2_rgmii_txd[1]}]
set_property SLEW FAST [get_ports {phy2_rgmii_txd[2]}]
set_property SLEW FAST [get_ports {phy2_rgmii_txd[3]}]
set_property SLEW FAST [get_ports phy2_mdc]
set_property SLEW FAST [get_ports phy2_mdio]
set_property SLEW FAST [get_ports phy2_reset_n]
set_property DRIVE 16 [get_ports phy1_rgmii_tx_clk]
set_property DRIVE 16 [get_ports phy1_rgmii_tx_ctl]
set_property DRIVE 16 [get_ports {phy1_rgmii_txd[0]}]
set_property DRIVE 16 [get_ports {phy1_rgmii_txd[1]}]
set_property DRIVE 16 [get_ports {phy1_rgmii_txd[2]}]
set_property DRIVE 16 [get_ports {phy1_rgmii_txd[3]}]
set_property DRIVE 16 [get_ports phy1_mdc]
set_property DRIVE 16 [get_ports phy1_mdio]
set_property DRIVE 16 [get_ports phy1_reset_n]
set_property DRIVE 16 [get_ports phy2_rgmii_tx_clk]
set_property DRIVE 16 [get_ports phy2_rgmii_tx_ctl]
set_property DRIVE 16 [get_ports {phy2_rgmii_txd[0]}]
set_property DRIVE 16 [get_ports {phy2_rgmii_txd[1]}]
set_property DRIVE 16 [get_ports {phy2_rgmii_txd[2]}]
set_property DRIVE 16 [get_ports {phy2_rgmii_txd[3]}]
set_property DRIVE 16 [get_ports phy2_mdio]
set_property DRIVE 16 [get_ports phy2_reset_n]
set_property DRIVE 16 [get_ports phy2_mdc]