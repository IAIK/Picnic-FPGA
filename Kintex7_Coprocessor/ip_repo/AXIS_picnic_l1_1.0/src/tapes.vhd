library work;
use work.lowmc_pkg.all;
use work.keccak_pkg.all;
use work.picnic_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tapes is
  port(
    -- Clock and Reset
    signal Clk_CI    : in std_logic;
    signal Rst_RI    : in std_logic;
    -- Input signals
    signal Start_SI  : in std_logic;
    signal Seed_0_DI : in std_logic_vector(PICNIC_S - 1 downto 0);
    signal Seed_1_DI : in std_logic_vector(PICNIC_S - 1 downto 0);
    signal Seed_2_DI : in std_logic_vector(PICNIC_S - 1 downto 0);
    signal Salt_DI   : in std_logic_vector(SALT_LEN - 1 downto 0);
    signal Round_DI  : in integer range 0 to T;
    -- Output signals
    signal Finish_SO : out std_logic;
    signal Key_R0_DO : out std_logic_vector(K - 1 downto 0);
    signal Key_R1_DO : out std_logic_vector(K - 1 downto 0);
    signal Rand_0_DO : out std_logic_vector(R * S - 1 downto 0);
    signal Rand_1_DO : out std_logic_vector(R * S - 1 downto 0);
    signal Rand_2_DO : out std_logic_vector(R * S - 1 downto 0)
  );
end entity;

architecture behavorial of tapes is
  type states is (init, kdf_start, kdf, seeds_start, seeds, squeeze);
  signal State_DN, State_DP : states;
  signal Init_in, Start_in, Squeeze_in, Finish_out : std_logic;
  signal K0_in, K1_in, K2_in : std_logic_vector(KECCAK_R - 1 downto 0);
  signal Hash0_out, Hash1_out : std_logic_vector(OUT_TAP_01 - 1 downto 0);
  signal Hash2_out : std_logic_vector(OUT_TAP_2 -1 downto 0);
  signal Dig0_DN, Dig0_DP : std_logic_vector(DIGEST_L - 1 downto 0);
  signal Dig1_DN, Dig1_DP : std_logic_vector(DIGEST_L - 1 downto 0);
  signal Dig2_DN, Dig2_DP : std_logic_vector(DIGEST_L - 1 downto 0);
  signal Squeeze0_DN, Squeeze1_DN, Squeeze0_DP, Squeeze1_DP : std_logic_vector(OUT_TAP_01 - 1 downto 0);
  signal Squeeze2_DN, Squeeze2_DP : std_logic_vector(OUT_TAP_2 - 1 downto 0);

  component keccak
    generic(
      constant GEN_R : integer := 1344;
      constant OUT_BIT : integer := 256
    );
    port(
      -- Clock and Reset
      signal Clk_CI   : in std_logic;
      signal Rst_RI  : in std_logic;
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
      OUT_BIT => OUT_TAP_01
    )
    port map (
      Clk_CI     => Clk_CI,
      Rst_RI     => Rst_RI,
      Block_DI   => K0_in,
      Absorb_SI  => Start_in,
      Squeeze_SI => Squeeze_in,
      Init_SI    => Init_in,
      Hash_DO    => Hash0_out,
      Valid_SO   => Finish_out
    );

    K1 : keccak
    generic map(
      GEN_R => KECCAK_R,
      OUT_BIT => OUT_TAP_01
    )
    port map (
      Clk_CI     => Clk_CI,
      Rst_RI     => Rst_RI,
      Block_DI   => K1_in,
      Absorb_SI  => Start_in,
      Squeeze_SI => Squeeze_in,
      Init_SI    => Init_in,
      Hash_DO    => Hash1_out,
      Valid_SO   => open
    );

    K2 : keccak
    generic map(
      GEN_R => KECCAK_R,
      OUT_BIT => OUT_TAP_2
    )
    port map (
      Clk_CI     => Clk_CI,
      Rst_RI     => Rst_RI,
      Block_DI   => K2_in,
      Absorb_SI  => Start_in,
      Squeeze_SI => Squeeze_in,
      Init_SI    => Init_in,
      Hash_DO    => Hash2_out,
      Valid_SO   => open
    );

  -- output logic
  process (State_DP, Start_SI, Finish_out, Seed_0_DI, Seed_1_DI, Seed_2_DI, Dig0_DP, Dig1_DP, Dig2_DP, Hash0_out, Hash1_out, Hash2_out, Squeeze0_DP, Squeeze1_DP, Squeeze2_DP, Salt_DI, Round_DI)
    variable Round_vec : std_logic_vector(15 downto 0);
  begin
    --default
    Squeeze0_DN <= Squeeze0_DP;
    Squeeze1_DN <= Squeeze1_DP;
    Squeeze2_DN <= Squeeze2_DP;
    Start_in <= '0';
    Init_in <= '0';
    Squeeze_in <= '0';
    Finish_SO <= '0';
    K0_in <= (others => '0');
    K1_in <= (others => '0');
    K2_in <= (others => '0');
    Dig0_DN <= Dig0_DP;
    Dig1_DN <= Dig1_DP;
    Dig2_DN <= Dig2_DP;

    -- output depending on config
    if (K + R * S > KECCAK_R) then
      Key_R0_DO <= Squeeze0_DP(OUT_TAP_01 - 1 downto OUT_TAP_01 - K);
      Key_R1_DO <= Squeeze1_DP(OUT_TAP_01 - 1 downto OUT_TAP_01 - K);
      Rand_0_DO <= Squeeze0_DP(OUT_TAP_01 - K - 1 downto 0) & Hash0_out(OUT_TAP_01 - 1 downto 2 * OUT_TAP_01 - R * S - K);
      Rand_1_DO <= Squeeze1_DP(OUT_TAP_01 - K - 1 downto 0) & Hash1_out(OUT_TAP_01 - 1 downto 2 * OUT_TAP_01 - R * S - K);
      Rand_2_DO <= Squeeze2_DP & Hash2_out(OUT_TAP_2 - 1 downto 2 * OUT_TAP_2 - R * S);
    else
      Key_R0_DO <= Hash0_out(OUT_TAP_01 - 1 downto OUT_TAP_01 - K);
      Key_R1_DO <= Hash1_out(OUT_TAP_01 - 1 downto OUT_TAP_01 - K);
      Rand_0_DO(RAND_01_UP - 1 downto 0) <= Hash0_out(HASH_01_UP - 1 downto HASH_01_DOWN);
      Rand_1_DO(RAND_01_UP - 1 downto 0) <= Hash1_out(HASH_01_UP - 1 downto HASH_01_DOWN);
      Rand_2_DO(RAND_2_UP - 1 downto 0) <= Hash2_out(HASH_2_UP - 1 downto HASH_2_DOWN);
    end if;

    case State_DP is
      when init =>
        if Start_SI = '1' then
          Init_in <= '1';
        end if;
        Finish_SO <= '1';
      when kdf_start =>
        K0_in(KECCAK_R - 1 downto KECCAK_R - 8) <= HASH_PREFIX_2;
        K0_in(KECCAK_R - 8 - 1 downto KECCAK_R - PICNIC_S - 16) <= Seed_0_DI & KECCAK_PAD;
        K0_in(7) <= '1';
        K1_in(KECCAK_R - 1 downto KECCAK_R - 8) <= HASH_PREFIX_2;
        K1_in(KECCAK_R - 8 - 1 downto KECCAK_R - PICNIC_S - 16) <= Seed_1_DI & KECCAK_PAD;
        K1_in(7) <= '1';
        K2_in(KECCAK_R - 1 downto KECCAK_R - 8) <= HASH_PREFIX_2;
        K2_in(KECCAK_R - 8 - 1 downto KECCAK_R - PICNIC_S - 16) <= Seed_2_DI & KECCAK_PAD;
        K2_in(7) <= '1';
        Start_in <= '1';
      when kdf =>
        if Finish_out = '1' then
          Dig0_DN <= Hash0_out(OUT_TAP_01 - 1 downto OUT_TAP_01 - DIGEST_L);
          Dig1_DN <= Hash1_out(OUT_TAP_01 - 1 downto OUT_TAP_01 - DIGEST_L);
          Dig2_DN <= Hash2_out(OUT_TAP_2 - 1 downto OUT_TAP_2 - DIGEST_L);
          Init_in <= '1';
        end if;
      when seeds_start =>
        Round_vec := std_logic_vector(to_unsigned(Round_DI, 16));
        Round_vec := Round_vec(7 downto 0) & Round_vec(15 downto 8);
        K0_in(KECCAK_R - 1 downto KECCAK_R - DIGEST_L - SALT_LEN - 56) <= Dig0_DP & Salt_DI & Round_vec & TAP_0_J & TAP_01_LENGTH & KECCAK_PAD;
        K0_in(7) <= '1';
        K1_in(KECCAK_R - 1 downto KECCAK_R - DIGEST_L - SALT_LEN - 56) <= Dig1_DP & Salt_DI & Round_vec & TAP_1_J & TAP_01_LENGTH & KECCAK_PAD;
        K1_in(7) <= '1';
        K2_in(KECCAK_R - 1 downto KECCAK_R - DIGEST_L - SALT_LEN - 56) <= Dig2_DP & Salt_DI & Round_vec & TAP_2_J & TAP_2_LENGTH & KECCAK_PAD;
        K2_in(7) <= '1';
        Start_in <= '1';
      when seeds =>
        if K + R * S > KECCAK_R then
          if Finish_out = '1' then
            Squeeze0_DN <= Hash0_out;
            Squeeze1_DN <= Hash1_out;
            Squeeze2_DN <= Hash2_out;
            Squeeze_in <= '1';
          end if;
        end if;
      when squeeze =>
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
          State_DN <= kdf_start;
        end if;
      when kdf_start =>
        State_DN <= kdf;
      when kdf =>
        if Finish_out = '1' then
          State_DN <= seeds_start;
        end if;
      when seeds_start =>
        State_DN <= seeds;
      when seeds =>
        if Finish_out = '1' then
          if K + R * S > KECCAK_R then
            State_DN <= squeeze;
          else
            State_DN <= init;
          end if;
        end if;
      when squeeze =>
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
        Dig2_DP    <= (others => '0');
        Squeeze0_DP <= (others => '0');
        Squeeze1_DP <= (others => '0');
        Squeeze2_DP <= (others => '0');
      else
        State_DP   <= State_DN;
        Dig0_DP    <= Dig0_DN;
        Dig1_DP    <= Dig1_DN;
        Dig2_DP    <= Dig2_DN;
        Squeeze0_DP <= Squeeze0_DN;
        Squeeze1_DP <= Squeeze1_DN;
        Squeeze2_DP <= Squeeze2_DN;
      end if;
    end if;
  end process;

end behavorial;
