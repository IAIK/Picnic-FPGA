library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_matrix_sk is
  port(
    -- Input signals
    signal Data_DI   : in std_logic_vector(K - 1 downto 0);
    signal Round_DI : in integer range 0 to R;
    -- Output signals
    signal Data_DO : out std_logic_vector(S - 1 downto 0)
  );
end entity;

architecture behavorial of lowmc_matrix_sk is
  signal Data_mul : T_SK_MATRIX;
begin

  SK_AND_GEN : for i in 0 to S - 1 generate
    Data_mul(i) <= KMATRIX(Round_DI)(i) and Data_DI;
  end generate SK_AND_GEN;

  SK_XOR_GEN : for i in 0 to S - 1 generate
    process (Data_mul(i))
      variable tmp : std_logic;
    begin
      tmp := '0';
      for j in 0 to K - 1 loop
        tmp := tmp xor Data_mul(i)(j);
      end loop;
      Data_DO(i) <= tmp;
    end process;
  end generate SK_XOR_GEN;

end behavorial;
