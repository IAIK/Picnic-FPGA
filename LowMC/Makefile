HIGHLEVEL_INTERPRETER=python3
MATRIX_GENERATOR=sage

SAGE_FLAGS= -python

HIGHLEVEL_FOLDER=py
VHDL_FOLDER=vhdl
MATRIX_FOLDER=matrices

GEN_MATRIX_OPT=./$(HIGHLEVEL_FOLDER)/process_matrices.py

VHDL_PKG=./$(VHDL_FOLDER)/lowmc_pkg.vhd

all: matrix_psi

matrix_psi:
	$(MATRIX_GENERATOR) $(SAGE_FLAGS) $(GEN_MATRIX_OPT) 128 128 11 25 ./$(MATRIX_FOLDER)/matrices_and_constants_128_128_11.pickle $(VHDL_PKG)

matrix_picnic_l1:
	$(MATRIX_GENERATOR) $(SAGE_FLAGS) $(GEN_MATRIX_OPT) 128 128 20 10 ./$(MATRIX_FOLDER)/matrices_and_constants_128_128_20.pickle $(VHDL_PKG)

matrix_picnic_l5:
	$(MATRIX_GENERATOR) $(SAGE_FLAGS) $(GEN_MATRIX_OPT) 256 256 38 10 ./$(MATRIX_FOLDER)/matrices_and_constants_256_256_38.pickle $(VHDL_PKG)

.PHONY: matrix_psi matrix_picnic_l1 matrix_picnic_l5
