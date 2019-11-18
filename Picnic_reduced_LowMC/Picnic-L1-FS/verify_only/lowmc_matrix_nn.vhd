library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_matrix_nn is
  port(
    -- Input signals
    signal State_DI   : in std_logic_vector(N - 1 downto 0);
    -- Output signals
    signal State_DO : out std_logic_vector(N - 1 downto 0)
  );
end entity;

architecture behavorial of lowmc_matrix_nn is
  signal Linear_mul : T_NN_MATRIX;
begin

  L_AND_GEN : for i in 0 to N - 1 generate
    Linear_mul(i) <= LMATRIX(0)(i) and State_DI;
  end generate L_AND_GEN;

  L_XOR_GEN : for i in 0 to N - 1 generate
    process (Linear_mul(i))
      variable tmp : std_logic;
    begin
      tmp := '0';
      for j in 0 to N - 1 loop
        tmp := tmp xor Linear_mul(i)(j);
      end loop;
      State_DO(i) <= tmp;
    end process;
  end generate L_XOR_GEN;

end behavorial;
