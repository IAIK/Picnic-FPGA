library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_matrix_r_nn is
  port(
    -- Input signals
    signal Data_DI   : in std_logic_vector(N - 1 downto 0);
    -- Output signals
    signal Data_DO : out std_logic_vector(N - 1 downto 0)
  );
end entity;

architecture behavorial of lowmc_matrix_r_nn is
  signal Data_mul : T_NN_MATRIX;
begin

  NN_AND_GEN : for i in 0 to N - 1 generate
    Data_mul(i) <= ZR(i) and Data_DI;
  end generate NN_AND_GEN;

  NN_XOR_GEN : for i in 0 to N - 1 generate
    process (Data_mul(i))
      variable tmp : std_logic;
    begin
      tmp := '0';
      for j in 0 to N - 1 loop
        tmp := tmp xor Data_mul(i)(j);
      end loop;
      Data_DO(i) <= tmp;
    end process;
  end generate NN_XOR_GEN;

end behavorial;
