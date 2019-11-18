library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

-- input rounds in (0, ..., R - 1)

entity lowmc_round_i_multiplex is
  port(
    -- Input signals
    signal State_0_DI : in std_logic_vector(N - 1 downto 0);
    signal State_1_DI : in std_logic_vector(N - 1 downto 0);
    signal Round_DI      : in integer range 0 to R;
    -- Output signals
    signal State_0_DO : out std_logic_vector(N - 1 downto 0);
    signal State_1_DO : out std_logic_vector(N - 1 downto 0)
  );
end entity;

architecture behavorial of  lowmc_round_i_multiplex is
  signal Matrix_rwedge_0_in_perm, Matrix_rwedge_1_in_perm : std_logic_vector(N - 1 downto 0);
  signal State_0_L_out, State_1_L_out : std_logic_vector(N - S - 1 downto 0);
  signal State_0_NL_out, State_1_NL_out : std_logic_vector(S - 1 downto 0);

  component lowmc_matrix_sn
    port(
      -- Input signals
      signal Data_DI   : in std_logic_vector(N - 1 downto 0);
      signal Round_DI  : in integer range 0 to R;
      -- Output signals
      signal Data_DO : out std_logic_vector(S - 1 downto 0)
    );
  end component;

  component lowmc_state_perm_multiplex
    port(
      -- Input signals
      signal State_DI : in std_logic_vector(N - 1 downto 0);
      signal Round_DI : in integer range 0 to R;
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
  ------------------------------------------------------------------------------
  -- FIRST INSTANCE
  -- S x N Matrix
  MATRIX_SN_0 : lowmc_matrix_sn
  port map(
    Data_DI => State_0_DI,
    Round_DI => Round_DI,
    Data_DO => State_0_NL_out
  );

  -- State Perm
  STATE_PERM_0 : lowmc_state_perm_multiplex
  port map(
    State_DI => State_0_DI,
    Round_DI => Round_DI,
    State_DO => Matrix_rwedge_0_in_perm
  );

  -- (N - S) x N Matrix
  MATRIX_NSN_0 : lowmc_matrix_rwedge
  port map(
    Data_DI => Matrix_rwedge_0_in_perm,
    Round_DI => Round_DI,
    Data_DO => State_0_L_out
  );

  State_0_DO <= State_0_NL_out & State_0_L_out;

  ------------------------------------------------------------------------------
  -- Second INSTANCE
  -- S x N Matrix
  MATRIX_SN_1 : lowmc_matrix_sn
  port map(
    Data_DI => State_1_DI,
    Round_DI => Round_DI,
    Data_DO => State_1_NL_out
  );

  -- State Perm
  STATE_PERM_1 : lowmc_state_perm_multiplex
  port map(
    State_DI => State_1_DI,
    Round_DI => Round_DI,
    State_DO => Matrix_rwedge_1_in_perm
  );

  -- (N - S) x N Matrix
  MATRIX_NSN_1 : lowmc_matrix_rwedge
  port map(
    Data_DI => Matrix_rwedge_1_in_perm,
    Round_DI => Round_DI,
    Data_DO => State_1_L_out
  );

  State_1_DO <= State_1_NL_out & State_1_L_out;

end behavorial;
