library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_mpc_and is
  port(
    -- Input signals
    signal a0 : in std_logic;
    signal a1 : in std_logic;
    signal a2 : in std_logic;
    signal b0 : in std_logic;
    signal b1 : in std_logic;
    signal b2 : in std_logic;
    signal r0 : in std_logic;
    signal r1 : in std_logic;
    signal r2 : in std_logic;
    -- Output signals
    signal o0 : out std_logic;
    signal o1 : out std_logic;
    signal o2 : out std_logic
  );
end entity;

architecture behavorial of lowmc_mpc_and is
begin
  o0 <= (a0 and b1) xor
        (a1 and b0) xor
        (a0 and b0) xor
        r0 xor r1;
  o1 <= (a1 and b2) xor
        (a2 and b1) xor
        (a1 and b1) xor
        r1 xor r2;
  o2 <= (a2 and b0) xor
        (a0 and b2) xor
        (a2 and b2) xor
        r2 xor r0;
end behavorial;