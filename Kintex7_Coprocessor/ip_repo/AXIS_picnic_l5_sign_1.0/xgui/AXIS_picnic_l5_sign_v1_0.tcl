# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  ipgui::add_page $IPINST -name "Page 0"

  ipgui::add_param $IPINST -name "PDI_WIDTH" -widget comboBox
  ipgui::add_param $IPINST -name "SDI_WIDTH" -widget comboBox
  ipgui::add_param $IPINST -name "PDO_WIDTH" -widget comboBox

}

proc update_PARAM_VALUE.PDI_WIDTH { PARAM_VALUE.PDI_WIDTH } {
	# Procedure called to update PDI_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PDI_WIDTH { PARAM_VALUE.PDI_WIDTH } {
	# Procedure called to validate PDI_WIDTH
	return true
}

proc update_PARAM_VALUE.PDO_WIDTH { PARAM_VALUE.PDO_WIDTH } {
	# Procedure called to update PDO_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PDO_WIDTH { PARAM_VALUE.PDO_WIDTH } {
	# Procedure called to validate PDO_WIDTH
	return true
}

proc update_PARAM_VALUE.SDI_WIDTH { PARAM_VALUE.SDI_WIDTH } {
	# Procedure called to update SDI_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SDI_WIDTH { PARAM_VALUE.SDI_WIDTH } {
	# Procedure called to validate SDI_WIDTH
	return true
}


