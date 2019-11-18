#! /usr/bin/env sage

from __future__ import unicode_literals

from sage.all import GF, matrix, vector, copy

import pickle, io
import sys
import math

F = GF(2)

class Instance(object):
    def __init__(self, n, k, r, L, K, R):
        self.n = n
        self.k = k
        self.r = r
        self.L = L
        self.K = K
        self.R = R

def snip_r_wedge(mat_wedge, indices):
    """
    Calculate the minimal representation of R_wedge, and the corresponding shuffle information
    """
    snipped_rows = mat_wedge.nrows() - mat_wedge.ncols()
    M_snip = mat_wedge[mat_wedge.nrows()-snipped_rows:mat_wedge.nrows(),:]

    idx = 0
    for correction in indices:
        M_snip[idx,:] = mat_wedge[correction,:]
        idx += 1

    return M_snip

def calc_dot_from_full_rank(mat):
    """
    calculate the matrix \dot{M} from M, where M is M^1*
    in our implementation, M is horizontally and vertically mirrored and transposed
    """
    dot_size = mat.ncols()
    M_dot = matrix(F, dot_size, dot_size)
    current_rank = 0
    idx = 0
    indices = []
    while current_rank < dot_size:
        assert idx < mat.nrows(), "mat should have full rank, something is wrong"
        M_dot[current_rank,:] = mat[idx,:]
        if current_rank == M_dot.rank():
            indices.append(idx)
        current_rank = M_dot.rank()
        idx += 1

    return M_dot, indices

def reverse_bits(input, size):
    tmp = ("{:0" + str(size) + "b}").format(input)
    tmp = tmp[::-1]
    return long(tmp, 2)

def combine_words(w):
    return long("".join([str(x) for x in w]), base=2)

def print_matrix_py(output, name, m, width, digits=0):
    output.write("        {name}".format(name=name))
    output.write(" = [\n")
    for r in m.rows():
        output.write("          ")
        tmp = reverse_bits(combine_words(r), width)
        output.write("0x" + format(tmp, 'x').zfill(digits))
        output.write(",\n")
    output.write("        ]\n");

def print_vector_py(output, name, m, width, digits=0):
    output.write("        {name}".format(name=name))
    output.write(" = ")
    tmp = reverse_bits(combine_words(m), width)
    output.write("0x" + format(tmp, 'x').zfill(digits))
    output.write("\n")

def print_matrix_vhdl(output, m, width):
    aligned = width // 4
    rem = width % 4;
    formatstr = "x\"{{:0{}x}}\"".format(aligned, width // 16)
    i = 0
    output.write("    (\n")
    for r in m.rows():
        i += 1
        output.write("      ")
        if rem == 0:
            output.write(formatstr.format(reverse_bits(combine_words(r), width)))
        else:
            val = reverse_bits(combine_words(r), width)
            val_bin = ("{:0" + str(width) + "b}").format(val)
            output.write("\"" + val_bin + "\"")
        if i != len(m.rows()):
            output.write(",")
        output.write("\n")
    output.write("    )")

def print_vector_vhdl(output, m, width):
    aligned = width // 4
    rem = width % 4;
    formatstr = "x\"{{:0{}x}}\"".format(aligned, width // 16)
    output.write("      ")
    if rem == 0:
        output.write(formatstr.format(reverse_bits(combine_words(m), width)))
    else:
        val = reverse_bits(combine_words(m), width)
        val_bin = ("{:0" + str(width) + "b}").format(val)
        output.write("\"" + val_bin + "\"")

def main(filein, vhdl_fileout, blocksize=256, keysize=256, rounds=19, sboxes=10):
    with io.open(filein, 'rb') as matfile:
        inst = pickle.load(matfile)

    if inst.n != blocksize or inst.k != keysize or inst.r != rounds:
        raise ValueError("Unexpected LowMC instance.")
    if blocksize != keysize:
        raise ValueError("Only blocksize == keysize is currently supported!")

    P = matrix(F, blocksize, blocksize)
    for i in range(blocksize):
        P[blocksize - i - 1, i] = 1

    Ls = [P * matrix(F, L) * P for L in inst.L]
    Ks = [P * matrix(F, K) * P for K in inst.K]
    Cs = [P * vector(F, C) for C in inst.R]

    Kt = [m.transpose() for m in Ks]
    Lt = [m.transpose() for m in Ls]

    Li = [m.inverse() for m in Lt]
    LiK = [Kt[i + 1] * Li[i] for i in range(inst.r)]
    LiC = [Cs[i] * Li[i] for i in range(inst.r)]

    mod_Li = [copy(Li[i]) for i in range(inst.r)]
    for j in range(inst.r):
        mod_Li[j][inst.n - 3*sboxes:, :inst.n] = matrix(F, 3 * sboxes, inst.n)

    precomputed_key_matrix = None
    precomputed_key_matrix_nl = matrix(F, inst.n, (sboxes * 3) * inst.r)
    precomputed_constant = None
    precomputed_constant_nl = vector(F, (sboxes * 3) * inst.r)

    for round in range(inst.r):
        tmp = copy(LiK[round])
        tmpC = copy(LiC[round])

        for i in range(round + 1, inst.r):
            x = LiK[i]
            c = LiC[i]
            for j in range(i - 1, round - 1, -1):
                x = x * mod_Li[j]
                c = c * mod_Li[j]
            tmp += x
            tmpC += c

        # non-linear part
        idx = round * (3 * sboxes)
        precomputed_key_matrix_nl[:inst.n, idx:idx + 3 * sboxes] = tmp[:inst.n, inst.n - 3*sboxes:]
        precomputed_constant_nl[idx:idx + 3 * sboxes] = tmpC[inst.n - 3 * sboxes:]

        # linear part
        if round == 0:
            tmp[:,inst.n - 3*sboxes:] = matrix(F, inst.n, 3*sboxes)
            tmpC[inst.n - 3*sboxes:] = vector(F, 3*sboxes)
            precomputed_key_matrix = tmp
            precomputed_constant = tmpC

    #RRKC precomputation done
    R_full = []
    R_dot = []
    R_dot_inv = []
    R_wedge = []
    T_vee = []
    R_wedge_snipped = []
    R_cols = []
    Z_i = []

    # i = 1
    R_full.append(Lt[0][:, 0:inst.n-3*sboxes])
    Rdot, colR = calc_dot_from_full_rank(R_full[0])
    R_dot.append(Rdot)
    R_dot_inv.append(R_dot[0].inverse())
    R_cols.append(colR)

    R_wedge.append(R_full[0]*R_dot_inv[0])
    Z_i.append(Lt[0][:,inst.n-3*sboxes:inst.n])
    R_wedge_snipped.append(snip_r_wedge(R_wedge[0],colR))

    # i = 2...r-1
    for i in range(1,rounds-1):
        T_vee.append(R_dot[i-1] * Lt[i][0:inst.n-sboxes*3,:])
        R = matrix(F, inst.n, inst.n-sboxes*3)
        R[0:inst.n-3*sboxes, :] = T_vee[-1][0:inst.n-3*sboxes, 0:inst.n-3*sboxes]
        R[inst.n-3*sboxes:inst.n, :] = Lt[i][inst.n-3*sboxes:inst.n, 0:inst.n-3*sboxes]
        R_full.append(R)
        Rdot, colR = calc_dot_from_full_rank(R_full[i])
        R_dot.append(Rdot)
        R_dot_inv.append(R_dot[i].inverse())
        R_cols.append(colR)
        R_wedge.append(R_full[i]*R_dot_inv[i])
        Z_i.append(T_vee[i-1][0:inst.n-3*sboxes, inst.n-3*sboxes:inst.n].transpose().augment(Lt[i][inst.n-sboxes*3:inst.n, inst.n-sboxes*3:inst.n].transpose()).transpose())
        R_wedge_snipped.append(snip_r_wedge(R_wedge[-1],colR))

    # i = r
    T_vee.append(R_dot[rounds-2] * Lt[rounds-1][0:inst.n-sboxes*3,:])

    # vhdl fileout
    with io.open(vhdl_fileout, 'w') as matfile:
        matfile.write("library ieee;\n")
        matfile.write("use ieee.std_logic_1164.all;\n\n")
        matfile.write("library work;\n\n")
        matfile.write("package lowmc_pkg is\n")
        matfile.write("  constant N : integer := {};\n".format(blocksize))
        matfile.write("  constant K : integer := {};\n".format(keysize))
        matfile.write("  constant M : integer := {};\n".format(sboxes))
        matfile.write("  constant R : integer := {};\n".format(rounds))
        matfile.write("  constant S : integer := {};\n\n".format(3 * sboxes))

        matfile.write("  type T_NK_MATRIX is array(0 to N - 1) of std_logic_vector(K - 1 downto 0);\n")
        matfile.write("  type T_NN_MATRIX is array(0 to N - 1) of std_logic_vector(N - 1 downto 0);\n")
        matfile.write("  type T_SK_MATRIX is array(0 to S - 1) of std_logic_vector(K - 1 downto 0);\n")
        matfile.write("  type T_SN_MATRIX is array(0 to S - 1) of std_logic_vector(N - 1 downto 0);\n")
        matfile.write("  type T_NSS_MATRIX is array(0 to (N - S) - 1) of std_logic_vector(S - 1 downto 0);\n")
        matfile.write("  type T_RS_MATRIX is array(0 to R - 1) of std_logic_vector(S - 1 downto 0);\n\n")

        matfile.write("  type T_KMATRIX is array (0 to R - 1) of T_SK_MATRIX;\n")
        matfile.write("  type T_ZMATRIX is array (0 to R - 2) of T_SN_MATRIX;\n")
        matfile.write("  type T_RMATRIX is array (0 to R - 2) of T_NSS_MATRIX;\n\n")

        # linaer part of key matrices (n x k)
        K0 = (precomputed_key_matrix + Kt[0]).transpose()
        matfile.write("  constant K0 : T_NK_MATRIX := (\n")
        for i, k in enumerate(K0):
            print_vector_vhdl(matfile, k, keysize)
            if i != K0.nrows() - 1:
                matfile.write(",")
            matfile.write("\n")
        matfile.write("  );\n\n")

        # nonlinear part of key matrices (s x k)
        precomputed_key_matrix_nlt = precomputed_key_matrix_nl.transpose()
        matfile.write("  constant KMATRIX : T_KMATRIX := (\n")
        for i in range(rounds):
            index_a = i * sboxes * 3
            index_b = (i + 1) * sboxes * 3
            print_matrix_vhdl(matfile, precomputed_key_matrix_nlt[index_a : index_b], keysize)
            if i != rounds - 1:
                matfile.write(",")
            matfile.write("\n")
        matfile.write("  );\n\n")

        # linear part of Constants (n x 1)
        matfile.write("  constant C0 : std_logic_vector(N - 1 downto 0) := (\n")
        print_vector_vhdl(matfile, precomputed_constant, blocksize)
        matfile.write("\n")
        matfile.write("  );\n\n")

        # nonlinear part of Constants (s x 1)
        matfile.write("  constant CONSTANTS : T_RS_MATRIX := (\n")
        for i in range(rounds):
            index_a = i * sboxes * 3
            index_b = (i + 1) * sboxes * 3
            print_vector_vhdl(matfile, precomputed_constant_nl[index_a : index_b], sboxes * 3)
            if i != rounds - 1:
                matfile.write(",")
            matfile.write("\n")
        matfile.write("  );\n\n")

        # L1_0* (s x n)
        L1 = Lt[0][:,blocksize-3*sboxes:blocksize].transpose()
        # Z_i (s x n)
        matfile.write("  constant ZMATRIX : T_ZMATRIX := (\n")
        for i in range(0, rounds - 1):
            if i == 0:
                print_matrix_vhdl(matfile, L1, blocksize)
            else:
                print_matrix_vhdl(matfile, Z_i[i].transpose(), blocksize)
            if i != rounds - 2:
                matfile.write(",")
            matfile.write("\n")
        matfile.write("  );\n\n")

        # Z_r (s x s)
        Z_r = T_vee[-1].transpose().augment(Lt[-1][inst.n-sboxes*3:inst.n, :].transpose())
        matfile.write("  constant ZR : T_NN_MATRIX := (\n")
        for i, z in enumerate(Z_r):
            print_vector_vhdl(matfile, z, blocksize)
            if i != Z_r.nrows() - 1:
                matfile.write(",")
            matfile.write("\n")
        matfile.write("  );\n\n")

        # Ri_wedge_snipped ((n - s) x s)
        matfile.write("  constant RMATRIX : T_RMATRIX := (\n")
        for i in range(0, rounds - 1):
            Ri = R_wedge_snipped[i].transpose()
            print_matrix_vhdl(matfile, Ri, sboxes * 3)
            if i != rounds - 2:
                matfile.write(",")
            matfile.write("\n")
        matfile.write("  );\n\n")

        matfile.write("-------------------------------------------------------------------------------\n\n")

        matfile.write("  -- constants for State permutation for RMATRIX\n")
        max = 0;
        for i, R in enumerate(R_cols):
            if len(R) > max:
                max = len(R)

        matfile.write("  type INT_ARRAY is array(integer range <>) of integer;\n");
        if (max > 0):
            matfile.write("  type R_C_ARRAY is array(0 to {}) of integer;\n".format(max - 1))
            matfile.write("  type R_ARRAY is array(0 to R - 2) of R_C_ARRAY;\n\n");

        matfile.write("  -- number of columns to swap per matrix\n")
        matfile.write("  constant R_CC : INT_ARRAY(0 to R - 2) := (\n")
        for i, R in enumerate(R_cols):
            matfile.write("    {}".format(len(R)))
            if (i != len(R_cols) - 1):
                matfile.write(",")
            matfile.write("\n")
        matfile.write("  );\n\n")

        matfile.write("  -- columns to swap per matrix\n")
        matfile.write("  constant R_C : R_ARRAY := (\n")
        for i, R in enumerate(R_cols):
            matfile.write("    (\n")
            matfile.write("      ")
            for j in range(max):
                idx = 0
                if j < len(R):
                    idx = R[j]
                matfile.write("{}".format(idx))
                if (j != max - 1):
                    matfile.write(", ")
            matfile.write("\n")
            matfile.write("    )")
            if (i != len(R_cols) - 1):
                matfile.write(",")
            matfile.write("\n")
        matfile.write("  );\n\n")

        matfile.write("end lowmc_pkg;\n")

if __name__ == '__main__':
    import sys

    if len(sys.argv) == 7:
        blocksize, keysize, rounds, sboxes = map(int, sys.argv[1:5])
        main(sys.argv[5], sys.argv[6], blocksize, keysize, rounds, sboxes)
    else:
        main('./matrices/matrices_and_constants_256_256_10.pickle', './vhdl/lowmc_pkg.vhd')
