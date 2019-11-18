library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_matrix_nk is
  port(
    -- Input signals
    signal Data_DI   : in std_logic_vector(K - 1 downto 0);
    -- Output signals
    signal Data_DO : out std_logic_vector(N - 1 downto 0)
  );
end entity;

architecture behavorial of lowmc_matrix_nk is
  signal Data_mul : T_NK_MATRIX;
begin

  NK_AND_GEN : for i in 0 to N - 1 generate
    Data_mul(i) <= K0(i) and Data_DI;
  end generate NK_AND_GEN;

  NK_XOR_GEN : for i in 0 to N - 1 generate
    process (Data_mul(i))
      variable tmp : std_logic;
    begin
      tmp := '0';
      for j in 0 to K - 1 loop
        tmp := tmp xor Data_mul(i)(j);
      end loop;
      Data_DO(i) <= tmp;
    end process;
  end generate NK_XOR_GEN;

end behavorial;
