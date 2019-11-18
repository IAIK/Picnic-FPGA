library work;
use work.lowmc_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity lowmc_sbox_mpc is
  port(
    -- Input signals
    signal State_NL_0_DI : in std_logic_vector(S - 1 downto 0);
    signal State_NL_1_DI : in std_logic_vector(S - 1 downto 0);
    signal Rand_0_DI     : in std_logic_vector(S - 1 downto 0);
    signal Rand_1_DI     : in std_logic_vector(S - 1 downto 0);
    signal TS_1_DI       : in std_logic_vector(S - 1 downto 0);
    -- Output signals
    signal State_NL_0_DO : out std_logic_vector(S - 1 downto 0);
    signal State_NL_1_DO : out std_logic_vector(S - 1 downto 0);
    signal TS_0_DO       : out std_logic_vector(S - 1 downto 0)
  );
end entity;

architecture behavorial of lowmc_sbox_mpc is
  signal ab_out0 : std_logic_vector(M - 1 downto 0);
  signal ab_out1 : std_logic_vector(M - 1 downto 0);
  signal bc_out0 : std_logic_vector(M - 1 downto 0);
  signal bc_out1 : std_logic_vector(M - 1 downto 0);
  signal ca_out0 : std_logic_vector(M - 1 downto 0);
  signal ca_out1 : std_logic_vector(M - 1 downto 0);

  component lowmc_mpc_and
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
  end component;
begin

  SBOX_GEN : for i in 0 to M - 1 generate

    AB : lowmc_mpc_and
    port map(
      a0 => State_NL_0_DI(S - 3 * i - 3),
      a1 => State_NL_1_DI(S - 3 * i - 3),
      b0 => State_NL_0_DI(S - 3 * i - 2),
      b1 => State_NL_1_DI(S - 3 * i - 2),
      r0 => Rand_0_DI(S - 3 * i - 1),
      r1 => Rand_1_DI(S - 3 * i - 1),
      o0 => ab_out0(i)
    );

    BC : lowmc_mpc_and
    port map(
      a0 => State_NL_0_DI(S - 3 * i - 2),
      a1 => State_NL_1_DI(S - 3 * i - 2),
      b0 => State_NL_0_DI(S - 3 * i - 1),
      b1 => State_NL_1_DI(S - 3 * i - 1),
      r0 => Rand_0_DI(S - 3 * i - 2),
      r1 => Rand_1_DI(S - 3 * i - 2),
      o0 => bc_out0(i)
    );

    CA : lowmc_mpc_and
    port map(
      a0 => State_NL_0_DI(S - 3 * i - 1),
      a1 => State_NL_1_DI(S - 3 * i - 1),
      b0 => State_NL_0_DI(S - 3 * i - 3),
      b1 => State_NL_1_DI(S - 3 * i - 3),
      r0 => Rand_0_DI(S - 3 * i - 3),
      r1 => Rand_1_DI(S - 3 * i - 3),
      o0 => ca_out0(i)
    );

    ab_out1(i) <= TS_1_DI(S - 3 * i - 1);
    bc_out1(i) <= TS_1_DI(S - 3 * i - 2);
    ca_out1(i) <= TS_1_DI(S - 3 * i - 3);

    -- a0
    State_NL_0_DO(S - 3 * i - 3) <= State_NL_0_DI(S - 3 * i - 3) xor
                                    bc_out0(i);
    -- b0
    State_NL_0_DO(S - 3 * i - 2) <= State_NL_0_DI(S - 3 * i - 3) xor
                                    State_NL_0_DI(S - 3 * i - 2) xor
                                    ca_out0(i);
    -- c0
    State_NL_0_DO(S - 3 * i - 1) <= State_NL_0_DI(S - 3 * i - 3) xor
                                    State_NL_0_DI(S - 3 * i - 2) xor
                                    State_NL_0_DI(S - 3 * i - 1) xor
                                    ab_out0(i);

    -- a1
    State_NL_1_DO(S - 3 * i - 3) <= State_NL_1_DI(S - 3 * i - 3) xor
                                    bc_out1(i);
    -- b1
    State_NL_1_DO(S - 3 * i - 2) <= State_NL_1_DI(S - 3 * i - 3) xor
                                    State_NL_1_DI(S - 3 * i - 2) xor
                                    ca_out1(i);
    -- c1
    State_NL_1_DO(S - 3 * i - 1) <= State_NL_1_DI(S - 3 * i - 3) xor
                                    State_NL_1_DI(S - 3 * i - 2) xor
                                    State_NL_1_DI(S - 3 * i - 1) xor
                                    ab_out1(i);

    -- Transcripts:
    TS_0_DO(S - 3 * i - 1) <= ab_out0(i);
    TS_0_DO(S - 3 * i - 2) <= bc_out0(i);
    TS_0_DO(S - 3 * i - 3) <= ca_out0(i);
  end generate SBOX_GEN;

end behavorial;
