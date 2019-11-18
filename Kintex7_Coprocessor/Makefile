VIVADO=vivado
VIVADO_FLAGS=-mode tcl -source
PROJECT_SIGN_L1=picnic_l1_sign
PROJECT_SIGN_L5=picnic_l5_sign
PROJECT_VER_L1=picnic_l1_verify
PROJECT_VER_L5=picnic_l5_verify
PROJECT_L1=picnic_l1
PROJECT_L5=picnic_l5
PROJECT_PSI=lowmc_pcie_psi

all: project_l1

project_l1:
	$(VIVADO) $(VIVADO_FLAGS) $(PROJECT_L1).tcl

project_l5:
	$(VIVADO) $(VIVADO_FLAGS) $(PROJECT_L5).tcl

project_sign_l1:
	$(VIVADO) $(VIVADO_FLAGS) $(PROJECT_SIGN_L1).tcl

project_sign_l5:
	$(VIVADO) $(VIVADO_FLAGS) $(PROJECT_SIGN_L5).tcl

project_verify_l1:
	$(VIVADO) $(VIVADO_FLAGS) $(PROJECT_VER_L1).tcl

project_verify_l5:
	$(VIVADO) $(VIVADO_FLAGS) $(PROJECT_VER_L5).tcl

project_psi:
	$(VIVADO) $(VIVADO_FLAGS) $(PROJECT_PSI).tcl

clean:
	rm -rf $(PROJECT_L1)
	rm -rf $(PROJECT_L5)
	rm -rf $(PROJECT_SIGN_L1)
	rm -rf $(PROJECT_SIGN_L5)
	rm -rf $(PROJECT_VER_L1)
	rm -rf $(PROJECT_VER_L5)
	rm -rf $(PROJECT_PSI)
	rm -rf *.jou
	rm -rf *.log
	rm -rf *.str
	rm -rf *.zip

.PHONY: clean project_sign_l1 project_sign_l5 project_verify_l1 project_verify_l5 project_l1 project_l5 project_psi
