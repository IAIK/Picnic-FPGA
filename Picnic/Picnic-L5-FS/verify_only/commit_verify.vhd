library work;
use work.lowmc_pkg.all;
use work.keccak_pkg.all;
use work.picnic_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity commit is
  port(
    -- Clock and Reset
    signal Clk_CI      : in std_logic;
    signal Rst_RI      : in std_logic;
    -- Input signals
    signal Start_SI    : in std_logic;
    signal Seed_0_DI   : in std_logic_vector(PICNIC_S - 1 downto 0);
    signal Seed_1_DI   : in std_logic_vector(PICNIC_S - 1 downto 0);
    signal Key_R0_DI   : in std_logic_vector(K - 1 downto 0);
    signal Key_R1_DI   : in std_logic_vector(K - 1 downto 0);
    signal TS_0_DI     : in std_logic_vector(R * S - 1 downto 0);
    signal TS_1_DI     : in std_logic_vector(R * S - 1 downto 0);
    signal Cipher_0_DI : in std_logic_vector(N - 1 downto 0);
    signal Cipher_1_DI : in std_logic_vector(N - 1 downto 0);
    -- Output signals
    signal Finish_SO   : out std_logic;
    signal Commit_0_DO : out std_logic_vector(DIGEST_L - 1 downto 0);
    signal Commit_1_DO : out std_logic_vector(DIGEST_L - 1 downto 0)
  );
end entity;

architecture behavorial of commit is
  type states is (init, seed_start, seed, commits_start, commits, absorb1, absorb2);
  signal State_DN, State_DP : states;
  signal Init_in, Start_in, Finish_out : std_logic;
  signal K0_in, K1_in : std_logic_vector(KECCAK_R - 1 downto 0);
  signal Hash0_out, Hash1_out : std_logic_vector(DIGEST_L - 1 downto 0);
  signal Dig0_DN, Dig0_DP : std_logic_vector(DIGEST_L - 1 downto 0);
  signal Dig1_DN, Dig1_DP : std_logic_vector(DIGEST_L - 1 downto 0);

  component keccak
    generic(
      constant GEN_R : integer := 1344;
      constant OUT_BIT : integer := 256
    );
    port(
      -- Clock and Reset
      signal Clk_CI   : in std_logic;
      signal Rst_RI   : in std_logic;
      -- Input signals
      signal Block_DI   : in std_logic_vector(GEN_R - 1 downto 0);
      signal Absorb_SI  : in std_logic;
      signal Squeeze_SI : in std_logic;
      signal Init_SI    : in std_logic;
      -- Output signals
      signal Hash_DO  : out std_logic_vector(OUT_BIT - 1 downto 0);
      signal Valid_SO : out std_logic
    );
  end component;

begin

  K0 : keccak
  generic map(
    GEN_R => KECCAK_R,
    OUT_BIT => DIGEST_L
  )
  port map (
    Clk_CI     => Clk_CI,
    Rst_RI     => Rst_RI,
    Block_DI   => K0_in,
    Absorb_SI  => Start_in,
    Squeeze_SI => '0',
    Init_SI    => Init_in,
    Hash_DO    => Hash0_out,
    Valid_SO   => Finish_out
  );

  K1 : keccak
  generic map(
    GEN_R => KECCAK_R,
    OUT_BIT => DIGEST_L
  )
  port map (
    Clk_CI     => Clk_CI,
    Rst_RI     => Rst_RI,
    Block_DI   => K1_in,
    Absorb_SI  => Start_in,
    Squeeze_SI => '0',
    Init_SI    => Init_in,
    Hash_DO    => Hash1_out,
    Valid_SO   => open
  );

  -- output logic
  process(State_DP, Dig0_DP, Dig1_DP, Seed_0_DI, Seed_1_DI, Hash0_out, Hash1_out, Key_R0_DI, Key_R1_DI, TS_0_DI, TS_1_DI, Cipher_0_DI, Cipher_1_DI, Finish_out, Start_SI)
  begin
    --default
    Start_in <= '0';
    Init_in <= '0';
    Finish_SO <= '0';
    K0_in <= (others => '0');
    K1_in <= (others => '0');
    Dig0_DN <= Dig0_DP;
    Dig1_DN <= Dig1_DP;
    Commit_0_DO <= Hash0_out;
    Commit_1_DO <= Hash1_out;

    case State_DP is
      when init =>
        if Start_SI = '1' then
          Init_in <= '1';
        end if;
        Finish_SO <= '1';
      when seed_start =>
        K0_in(KECCAK_R - 1 downto KECCAK_R - 8) <= HASH_PREFIX_4;
        K0_in(KECCAK_R - 8 - 1 downto KECCAK_R - PICNIC_S - 16) <= Seed_0_DI & KECCAK_PAD;
        K0_in(7) <= '1';
        K1_in(KECCAK_R - 1 downto KECCAK_R - 8) <= HASH_PREFIX_4;
        K1_in(KECCAK_R - 8 - 1 downto KECCAK_R - PICNIC_S - 16) <= Seed_1_DI & KECCAK_PAD;
        K1_in(7) <= '1';
        Start_in <= '1';
      when seed =>
        if Finish_out = '1' then
          Dig0_DN <= Hash0_out;
          Dig1_DN <= Hash1_out;
          Init_in <= '1';
        end if;
      when commits_start =>
        -- hash input
        if DIGEST_L + K + R * S + N + 16 > KECCAK_R then
          K0_in(KECCAK_R - 1 downto KECCAK_R - DIGEST_L - K - 8) <= HASH_PREFIX_0 & Dig0_DP & Key_R0_DI;
          K0_in(COMMIT_FIRST - 1 downto 0) <= TS_0_DI(R * S - 1 downto R * S - COMMIT_FIRST);
          K1_in(KECCAK_R - 1 downto KECCAK_R - DIGEST_L - K - 8) <= HASH_PREFIX_0 & Dig1_DP & Key_R1_DI;
          K1_in(COMMIT_FIRST - 1 downto 0) <= TS_1_DI(R * S - 1 downto R * S - COMMIT_FIRST);
        else
          K0_in(KECCAK_R - 1 downto KECCAK_R - 16 - K - DIGEST_L - COMMIT_RS - N) <= HASH_PREFIX_0 & Dig0_DP & Key_R0_DI & TS_0_DI(COMMIT_RS - 1 downto 0) & Cipher_0_DI & KECCAK_PAD;
          K0_in(7) <= '1';
          K1_in(KECCAK_R - 1 downto KECCAK_R - 16 - K - DIGEST_L - COMMIT_RS - N) <= HASH_PREFIX_0 & Dig1_DP & Key_R1_DI & TS_1_DI(COMMIT_RS - 1 downto 0) & Cipher_1_DI & KECCAK_PAD;
          K1_in(7) <= '1';
        end if;
        Start_in <= '1';
      when commits =>
        if DIGEST_L + K + R * S + N + 16 > KECCAK_R then
          if Finish_out <= '1' then
            -- hash input
            if DIGEST_L + K + R * S + N + 16 > 2 * KECCAK_R then
              K0_in <= TS_0_DI(R * S - KECCAK_R + DIGEST_L + K + 8 - 1 downto 0) & x"0" & Cipher_0_DI;
              K1_in <= TS_1_DI(R * S - KECCAK_R + DIGEST_L + K + 8 - 1 downto 0) & x"0" & Cipher_1_DI;
            else
              K0_in(KECCAK_R - 1 downto DIGEST_L + K + 16 + N) <= TS_0_DI(R * S - KECCAK_R + DIGEST_L + K + 8 - 1 downto 0) & x"0" & Cipher_0_DI & KECCAK_PAD;
              K0_in(7) <= '1';
              K1_in(KECCAK_R - 1 downto DIGEST_L + K + 16 + N) <= TS_1_DI(R * S - KECCAK_R + DIGEST_L + K + 8 - 1 downto 0) & x"0" & Cipher_1_DI & KECCAK_PAD;
              K1_in(7) <= '1';
            end if;
            Start_in <= '1';
          end if;
        end if;
      when absorb1 =>
        if DIGEST_L + K + R * S + N + 16 > 2 * KECCAK_R then
          if Finish_out <= '1' then
            -- hash input
            K0_in(KECCAK_R - 1 downto KECCAK_R - 8) <= KECCAK_PAD;
            K0_in(7) <= '1';
            K1_in(KECCAK_R - 1 downto KECCAK_R - 8) <= KECCAK_PAD;
            K1_in(7) <= '1';
            Start_in <= '1';
          end if;
        end if;
      when absorb2 =>
    end case;
  end process;

  -- next state logic
  process (State_DP, Start_SI, Finish_out)
  begin
    --default
    State_DN <= State_DP;

    case State_DP is
      when init =>
        if Start_SI = '1' then
          State_DN <= seed_start;
        end if;
      when seed_start =>
        State_DN <= seed;
      when seed =>
        if Finish_out = '1' then
          State_DN <= commits_start;
        end if;
      when commits_start =>
        State_DN <= commits;
      when commits =>
        if Finish_out = '1' then
          if DIGEST_L + K + R * S + N + 16 > KECCAK_R then
            State_DN <= absorb1;
          else
            State_DN <= init;
          end if;
        end if;
      when absorb1 =>
        if Finish_out = '1' then
          if DIGEST_L + K + R * S + N + 16 > 2 * KECCAK_R then
            State_DN <= absorb2;
          else
            State_DN <= init;
          end if;
        end if;
      when absorb2 =>
        if Finish_out = '1' then
          State_DN <= init;
        end if;
    end case;
  end process;

  -- the registers
  process (Clk_CI, Rst_RI)
  begin  -- process register_p
    if Clk_CI'event and Clk_CI = '1' then
      if Rst_RI = '1' then               -- synchronous reset (active high)
        State_DP   <= init;
        Dig0_DP    <= (others => '0');
        Dig1_DP    <= (others => '0');
      else
        State_DP   <= State_DN;
        Dig0_DP    <= Dig0_DN;
        Dig1_DP    <= Dig1_DN;
      end if;
    end if;
  end process;

end behavorial;