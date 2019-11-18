library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_mpc_and is
  port(
    -- Input signals
    signal a0 : in std_logic;
    signal a1 : in std_logic;
    signal b0 : in std_logic;
    signal b1 : in std_logic;
    signal r0 : in std_logic;
    signal r1 : in std_logic;
    -- Output signals
    signal o0 : out std_logic
  );
end entity;

architecture behavorial of lowmc_mpc_and is
begin
  o0 <= (a0 and b1) xor
        (a1 and b0) xor
        (a0 and b0) xor
        r0 xor r1;
end behavorial;