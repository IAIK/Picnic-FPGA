library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_sbox_nl is
  port(
    -- Input signals
    signal State_NL_DI : in std_logic_vector(S - 1 downto 0);
    signal Key_DI : in std_logic_vector(K - 1 downto 0);
    signal Round_DI : in integer range 0 to R;
    -- Output signals
    signal State_NL_DO : out std_logic_vector(S - 1 downto 0)
  );
end entity;

architecture behavorial of  lowmc_sbox_nl is
  signal Sbox_out : std_logic_vector(S - 1 downto 0);
  signal Key_out : std_logic_vector(S - 1 downto 0);

  component lowmc_sbox
    port(
      -- Input signals
      signal State_NL_DI   : in std_logic_vector(S - 1 downto 0);
      -- Output signals
      signal State_NL_DO : out std_logic_vector(S - 1 downto 0)
    );
  end component;

  component lowmc_matrix_sk
    port(
      -- Input signals
      signal Data_DI   : in std_logic_vector(K - 1 downto 0);
      signal Round_DI : in integer range 0 to R;
      -- Output signals
      signal Data_DO : out std_logic_vector(S - 1 downto 0)
    );
  end component;

begin
  -- SBOX
  SBOX : lowmc_sbox
  port map(
    State_NL_DI => State_NL_DI,
    State_NL_DO => Sbox_out
  );

  -- S x K Matrix
  MATRIX_SK : lowmc_matrix_sk
  port map(
    Data_DI => Key_DI,
    Round_DI => Round_DI,
    Data_DO => Key_out
  );

  State_NL_DO <= Sbox_out xor Key_out xor CONSTANTS(Round_DI);
end behavorial;
