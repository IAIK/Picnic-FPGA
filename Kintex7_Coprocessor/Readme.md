#The project files for the LowMC/Picnic coprocessors

## Makefile:
### requirements
- Vivado

### targets:
- **project\_l1** creates the Vivado project for the Picnic-L1-FS coprocessor
- **project\_l5** creates the Vivado project for the Picnic-L5-FS coprocessor
- **project\_sign\_l1** creates the Vivado project for the Picnic-L1-FS coprocessor (sign only)
- **project\_sign\_l5** creates the Vivado project for the Picnic-L5-FS coprocessor (sign only)
- **project\_verify\_l1** creates the Vivado project for the Picnic-L1-FS coprocessor (verify only)
- **project\_verify\_l5** creates the Vivado project for the Picnic-L5-FS coprocessor (verify only)
- **project\_psi** creates the Vivado project for the LowMC-PSI coprocessor
- **clean** removes all the generated files

## C-Library:
- The libraries to access the coprocessors can be found in the **c** folder
