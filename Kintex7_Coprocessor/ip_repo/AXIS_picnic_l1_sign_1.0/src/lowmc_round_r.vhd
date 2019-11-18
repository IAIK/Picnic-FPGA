library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_round_r is
  port(
    -- Input signals
    signal State_0_DI : in std_logic_vector(N - 1 downto 0);
    signal State_1_DI : in std_logic_vector(N - 1 downto 0);
    -- Output signals
    signal State_0_DO    : out std_logic_vector(N - 1 downto 0);
    signal State_1_DO    : out std_logic_vector(N - 1 downto 0)
  );
end entity;

architecture behavorial of  lowmc_round_r is
  signal Key_0_out, Key_1_out : std_logic_vector(S - 1 downto 0);

  component lowmc_matrix_r_nn
    port(
      -- Input signals
      signal Data_DI   : in std_logic_vector(N - 1 downto 0);
      -- Output signals
      signal Data_DO : out std_logic_vector(N - 1 downto 0)
    );
  end component;

begin
  ------------------------------------------------------------------------------
  -- FIRST INSTANCE
  -- N x N Matrix
  MATRIX_NN_0 : lowmc_matrix_r_nn
  port map(
    Data_DI => State_0_DI,
    Data_DO => State_0_DO
  );


  ------------------------------------------------------------------------------
  -- SECOND INSTANCE
  -- N x N Matrix
  MATRIX_NN_1 : lowmc_matrix_r_nn
  port map(
    Data_DI => State_1_DI,
    Data_DO => State_1_DO
  );

end behavorial;
