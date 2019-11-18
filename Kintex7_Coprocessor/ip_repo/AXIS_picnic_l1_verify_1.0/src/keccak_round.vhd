library work;
use work.keccak_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity keccak_round is
  port(
    -- Input signals
    signal State_DI : in T_STATE;
    signal Round_DI : integer range 0 to KECCAK_N;
    -- Output signals
    signal State_DO : out T_STATE
  );
end entity;

architecture behavorial of keccak_round is
  signal C_S : T_COLUMN;
  signal D_S : T_COLUMN;
  signal B_S : T_STATE;
  signal Theta_S : T_STATE;
  signal Iota_S : T_STATE;

begin

  theta_c : for col in 0 to (CUBE_LEN - 1) generate
    C_S(col) <= State_DI(0)(col) xor
                State_DI(1)(col) xor
                State_DI(2)(col) xor
                State_DI(3)(col) xor
                State_DI(4)(col);
    end generate theta_c;

    theta_d : for i in 0 to (CUBE_LEN - 1) generate
        D_S(i) <= C_S((i - 1) mod CUBE_LEN) xor
                  (C_S((i + 1) mod CUBE_LEN)((W - 2) downto 0)
                      & C_S((i + 1) mod CUBE_LEN)(W - 1)
                  );
                      -- rot C_DP[i+1] by 1
    end generate theta_d;

    theta_row : for row in 0 to (CUBE_LEN - 1) generate
      theta_col : for col in 0 to (CUBE_LEN - 1) generate
          Theta_S(row)(col) <= State_DI(row)(col) xor D_S(col);
      end generate theta_col;
    end generate theta_row;

    rho_phi_row : for row in 0 to (CUBE_LEN - 1) generate
      rho_phi_col : for col in 0 to (CUBE_LEN - 1) generate
        rho_phi_gen : if ((ROT(col + CUBE_LEN * row)) mod W) = 0 generate
          B_S((2 * row + 3 * col) mod CUBE_LEN)(col) <= Theta_S(col)(row);
        end generate rho_phi_gen;
        rho_phi_gen2 : if ((ROT(col + CUBE_LEN * row)) mod W) /= 0 generate
          B_S((2 * row + 3 * col) mod CUBE_LEN)(col) <= Theta_S(col)(row)((W - ((ROT(row + CUBE_LEN * col)) mod W) - 1) downto 0) &
              Theta_S(col)(row)((W - 1) downto (W - ((ROT(row + CUBE_LEN * col)) mod W)));
        end generate rho_phi_gen2;
      end generate rho_phi_col;
    end generate rho_phi_row;

    Iota_S(0)(0) <= B_S(0)(0) xor
                    ((not B_S(0)(1)) and
                      B_S(0)(2)
                    ) xor
                    RC(Round_DI);

    chi_iota_x : for row in 0 to (CUBE_LEN - 1) generate
      chi_iota_y : for col in 0 to (CUBE_LEN - 1) generate
        chi_gen : if row /= 0 or col /= 0 generate
          Iota_S(row)(col) <= B_S(row)(col) xor
                              ((not B_S(row)((col + 1) mod CUBE_LEN)) and
                                B_S(row)((col + 2) mod CUBE_LEN)
                              );
        end generate chi_gen;
      end generate chi_iota_y;
    end generate chi_iota_x;

    -- Output
    State_DO <= Iota_S;

end behavorial;