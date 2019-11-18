library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

-- input rounds in (0, ..., R - 1)

entity lowmc_round_i is
  generic(
    constant Round_DI : in integer range 0 to R
  );
  port(
    -- Input signals
    signal State_NL_DI : in std_logic_vector(S - 1 downto 0);
    signal State_L_DI : in std_logic_vector((N - S) - 1 downto 0);
    signal Key_DI : in std_logic_vector(K - 1 downto 0);
    -- Output signals
    signal State_NL_DO : out std_logic_vector(S - 1 downto 0);
    signal State_L_DO : out std_logic_vector((N - S) - 1 downto 0)
  );
end entity;

architecture behavorial of  lowmc_round_i is
  signal Sbox_out : std_logic_vector(S - 1 downto 0);
  signal Matrix_in, Matrix_rwedge_in_perm : std_logic_vector(N - 1 downto 0);
  signal Index : integer range 0 to R;

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

  component lowmc_matrix_sn
    port(
      -- Input signals
      signal Data_DI   : in std_logic_vector(N - 1 downto 0);
      signal Round_DI  : in integer range 0 to R;
      -- Output signals
      signal Data_DO : out std_logic_vector(S - 1 downto 0)
    );
  end component;

  component lowmc_state_perm
    generic(
      constant Round_DI : in integer range 0 to R
    );
    port(
      -- Input signals
      signal State_DI : in std_logic_vector(N - 1 downto 0);
      -- Output signals
      signal State_DO : out std_logic_vector(N - 1 downto 0)
    );
  end component;

  component lowmc_matrix_rwedge
    port(
      -- Input signals
      signal Data_DI   : in std_logic_vector(N - 1 downto 0);
      signal Round_DI : in integer range 0 to R;
      -- Output signals
      signal Data_DO : out std_logic_vector((N - S) - 1 downto 0)
    );
  end component;

begin

  -- SBOX_NL
  SBOX_NL : lowmc_sbox_nl
  port map(
    State_NL_DI => State_NL_DI,
    Key_DI => Key_DI,
    Round_DI => Round_DI,
    State_NL_DO => Sbox_out
  );

  -- S x N Matrix
  MATRIX_SN : lowmc_matrix_sn
  port map(
    Data_DI => Matrix_in,
    Round_DI => Round_DI,
    Data_DO => State_NL_DO
  );

  -- State Perm
  STATE_PERM : lowmc_state_perm
  generic map(
    Round_DI => Round_DI
  )
  port map(
    State_DI => Matrix_in,
    State_DO => Matrix_rwedge_in_perm
  );

  -- (N - S) x N Matrix
  MATRIX_NSN : lowmc_matrix_rwedge
  port map(
    Data_DI => Matrix_rwedge_in_perm,
    Round_DI => Round_DI,
    Data_DO => State_L_DO
  );

  Matrix_in <= Sbox_out & State_L_DI;

end behavorial;
