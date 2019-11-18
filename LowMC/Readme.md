#The LowMC source code
## Folders:
- **matrices** contains the pickle files for the LowMC constants
- **py** contains the script for generating the VHDL package **vhdl/lowmc\_pkg.vhd** from the pickle files for the different LowMC instances
- **vhdl** contains the VHDL source code for LowMC. The different instances use a different lowmc\_pkg.vhd file

## Makefile:
### requirements
- sage
- python3

### targets:
- **matrix\_psi** generates the lowmc\_pkg.vhd file for LowMC(128, 128, 25, 11)
- **matrix\_picnic\_l1** generates the lowmc\_pkg.vhd file for LowMC(128, 128, 10, 20)
- **matrix\_picnic\_l5** generates the lowmc\_pkg.vhd file for LowMC(256, 256, 10, 38)
