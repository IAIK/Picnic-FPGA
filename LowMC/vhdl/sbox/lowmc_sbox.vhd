library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_sbox is
  port(
    -- Input signals
    signal State_NL_DI : in std_logic_vector(S - 1 downto 0);
    -- Output signals
    signal State_NL_DO : out std_logic_vector(S - 1 downto 0)
  );
end entity;

architecture behavorial of lowmc_sbox is
begin

  SBOX_GEN : for i in 0 to M - 1 generate
    -- a
    State_NL_DO(S - 3 * i - 3) <= State_NL_DI(S - 3 * i - 3) xor
                                  (
                                    State_NL_DI(S - 3 * i - 2) and
                                    State_NL_DI(S - 3 * i - 1)
                                  );
    -- b
    State_NL_DO(S - 3 * i  - 2) <= State_NL_DI(S - 3 * i - 3) xor
                                   State_NL_DI(S - 3 * i - 2) xor
                                   (
                                     State_NL_DI(S - 3 * i - 3) and
                                     State_NL_DI(S - 3 * i - 1)
                                   );
    -- c
    State_NL_DO(S - 3 * i - 1) <= State_NL_DI(S - 3 * i - 3) xor
                                  State_NL_DI(S - 3 * i - 2) xor
                                  State_NL_DI(S - 3 * i - 1) xor
                                  (
                                    State_NL_DI(S - 3 * i - 3) and
                                    State_NL_DI(S - 3 * i - 2)
                                  );
  end generate SBOX_GEN;

end behavorial;
