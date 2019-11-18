library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_matrix_rwedge is
  port(
    -- Input signals
    signal Data_DI   : in std_logic_vector(N - 1 downto 0);
    signal Round_DI : in integer range 0 to R;
    -- Output signals
    signal Data_DO : out std_logic_vector((N - S) - 1 downto 0)
  );
end entity;

architecture behavorial of lowmc_matrix_rwedge is
  signal Data_mul : T_NSS_MATRIX;
begin

  NSN_AND_GEN : for i in 0 to (N - S) - 1 generate
    Data_mul(i) <= RMATRIX(Round_DI)(i) and Data_DI(N - 1 downto N - S);
  end generate NSN_AND_GEN;

  NSN_XOR_GEN : for i in 0 to (N - S) - 1 generate
    process (Data_mul(i), Data_DI(i))
      variable tmp : std_logic;
    begin
      tmp := Data_DI(i);
      for j in 0 to S - 1 loop
        tmp := tmp xor Data_mul(i)(j);
      end loop;
      Data_DO(i) <= tmp;
    end process;
  end generate NSN_XOR_GEN;

end behavorial;
