library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_round_r is
  port(
    -- Input signals
    signal State_NL_DI : in std_logic_vector(S - 1 downto 0);
    signal State_L_DI : in std_logic_vector((N - S) - 1 downto 0);
    signal Key_DI : in std_logic_vector(K - 1 downto 0);
    -- Output signals
    signal State_DO : out std_logic_vector(N - 1 downto 0)
  );
end entity;

architecture behavorial of  lowmc_round_r is
  signal Sbox_out : std_logic_vector(S - 1 downto 0);
  signal Matrix_in : std_logic_vector(N - 1 downto 0);

  component lowmc_sbox_nl
    port(
      -- Input signals
      signal State_NL_DI : in std_logic_vector(S - 1 downto 0);
      signal Key_DI : in std_logic_vector(K - 1 downto 0);
      signal Round_DI : in integer range 0 to R;
      -- Output signals
      signal State_NL_DO : out std_logic_vector(S - 1 downto 0)
    );
  end component;

  component lowmc_matrix_r_nn
    port(
      -- Input signals
      signal Data_DI   : in std_logic_vector(N - 1 downto 0);
      -- Output signals
      signal Data_DO : out std_logic_vector(N - 1 downto 0)
    );
  end component;

begin
  -- SBOX_NL
  SBOX_NL : lowmc_sbox_nl
  port map(
    State_NL_DI => State_NL_DI,
    Key_DI => Key_DI,
    Round_DI => R - 1,
    State_NL_DO => Sbox_out
  );

  -- N x N Matrix
  MATRIX_NN : lowmc_matrix_r_nn
  port map(
    Data_DI => Matrix_in,
    Data_DO => State_DO
  );

  Matrix_in <= Sbox_out & State_L_DI;

end behavorial;
