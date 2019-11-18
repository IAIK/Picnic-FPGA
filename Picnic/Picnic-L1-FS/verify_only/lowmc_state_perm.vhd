library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_state_perm is
  generic(
    constant Round_DI : integer
  );
  port(
    -- Input signals
    signal State_DI : in std_logic_vector(N - 1 downto 0);
    -- Output signals
    signal State_DO : out std_logic_vector(N - 1 downto 0)
  );
end entity;

architecture behavorial of lowmc_state_perm is
begin

  process (State_DI)
    variable tmp : std_logic_vector(N - 1 downto 0);
    variable tmp_loop_in : std_logic_vector(N - 1 downto 0);
  begin
    tmp := State_DI;
    for i in R_CC(Round_DI) downto 1 loop
      tmp_loop_in := tmp;
      tmp(N - 1 - S + i) := tmp_loop_in(R_C(Round_DI)(i - 1));
      tmp(N - 2 - S + i downto R_C(Round_DI)(i - 1)) := tmp_loop_in(N - 1 - S + i downto R_C(Round_DI)(i - 1) + 1);
    end loop;
    State_DO <= tmp;
  end process;

end behavorial;
