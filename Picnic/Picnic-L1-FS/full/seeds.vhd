library work;
use work.lowmc_pkg.all;
use work.keccak_pkg.all;
use work.picnic_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity seeds is
  port(
    -- Clock and Reset
    signal Clk_CI      : in std_logic;
    signal Rst_RI      : in std_logic;
    -- Input signals
    signal Start_SI    : in std_logic;
    signal Next_SI     : in std_logic;
    signal Plain_DI    : in std_logic_vector(N - 1 downto 0);
    signal Key_DI      : in std_logic_vector(K - 1 downto 0);
    signal Cipher_DI   : in std_logic_vector(N - 1 downto 0);
    signal Message_DI  : in std_logic_vector(MSG_LEN - 1 downto 0);
    -- Output signals
    signal Ready_SO    : out std_logic;
    signal Seed_0_DO   : out std_logic_vector(PICNIC_S - 1 downto 0);
    signal Seed_1_DO   : out std_logic_vector(PICNIC_S - 1 downto 0);
    signal Seed_2_DO   : out std_logic_vector(PICNIC_S - 1 downto 0)
  );
end entity;

architecture behavorial of seeds is
  type states is (init, absorb_start, absorb, seed_out_0, seed_out_buf, seed_out_off, squeeze_0, squeeze_off);
  signal State_DN, State_DP : states;
  signal Init_in, Start_in, Squeeze_in, Finish_out : std_logic;
  signal K_in, Hash_out : std_logic_vector(KECCAK_R - 1 downto 0);
  signal Buffer_out_DN, Buffer_out_DP : std_logic_vector(3 * PICNIC_S / 2 - 1 downto 0);
  signal Count_DN, Count_DP : integer range 0 to 3;

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
    OUT_BIT => KECCAK_R
  )
  port map (
    Clk_CI     => Clk_CI,
    Rst_RI     => Rst_RI,
    Block_DI   => K_in,
    Absorb_SI  => Start_in,
    Squeeze_SI => Squeeze_in,
    Init_SI    => Init_in,
    Hash_DO    => Hash_out,
    Valid_SO   => Finish_out
  );

  -- output logic
  process (State_DP, Start_SI, Finish_out, Next_SI, Hash_out, Plain_DI, Key_DI, Cipher_DI, Message_DI, Buffer_out_DP, Count_DP)
  begin
    --default
    Start_in <= '0';
    Init_in <= '0';
    Squeeze_in <= '0';
    Ready_SO <= '0';
    K_in <= (others => '0');
    Seed_0_DO <= (others => '0');
    Seed_1_DO <= (others => '0');
    Seed_2_DO <= (others => '0');
    Buffer_out_DN <= Buffer_out_DP;
    Count_DN <= Count_DP;

    case State_DP is
      when init =>
        if Start_SI = '1' then
          Init_in <= '1';
        end if;
        Ready_SO <= '1';
      when absorb_start =>
        K_in(KECCAK_R - 1 downto KECCAK_R - K - MSG_LEN - N - N - 24) <= Key_DI & Message_DI & Cipher_DI & Plain_DI & MSG_LENGHT_END & KECCAK_PAD;
        K_in(7) <= '1';
        Start_in <= '1';
      when absorb =>
        Count_DN <= 0;
      when seed_out_0 =>
        Ready_SO <= '1';
        Seed_0_DO <= Hash_out(KECCAK_R - 3 * Count_DP * PICNIC_S - 1 downto KECCAK_R - (3 * Count_DP + 1) * PICNIC_S);
        Seed_1_DO <= Hash_out(KECCAK_R - (3 * Count_DP + 1) * PICNIC_S - 1 downto KECCAK_R - (3 * Count_DP + 2) * PICNIC_S);
        Seed_2_DO <= Hash_out(KECCAK_R - (3 * Count_DP + 2) * PICNIC_S - 1 downto KECCAK_R - (3 * Count_DP + 3) * PICNIC_S);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' and Count_DP >= 2 then
          Buffer_out_DN <= Hash_out(3* PICNIC_S / 2 - 1 downto 0);
          Squeeze_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
        end if;
      when seed_out_buf =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(3 * PICNIC_S / 2 - 1 downto PICNIC_S / 2);
        Seed_1_DO(PICNIC_S - 1 downto PICNIC_S / 2) <= Buffer_out_DP(PICNIC_S / 2 - 1 downto 0);
        Seed_1_DO(PICNIC_S / 2 - 1 downto 0) <= Hash_out(KECCAK_R - 1 downto KECCAK_R - PICNIC_S / 2);
        Seed_2_DO <= Hash_out(KECCAK_R - PICNIC_S / 2 - 1 downto KECCAK_R - 3 * PICNIC_S / 2);
        if Start_SI = '1' then
          Init_in <= '1';
        end if;
      when seed_out_off =>
        Ready_SO <= '1';
        Seed_0_DO <= Hash_out(KECCAK_R - 3 * PICNIC_S / 2 - 3 * Count_DP * PICNIC_S - 1 downto KECCAK_R - 3 * PICNIC_S / 2 - (3 * Count_DP + 1) * PICNIC_S);
        Seed_1_DO <= Hash_out(KECCAK_R - 3 * PICNIC_S / 2 - (3 * Count_DP + 1) * PICNIC_S - 1 downto KECCAK_R - 3 * PICNIC_S / 2 - (3 * Count_DP + 2) * PICNIC_S);
        Seed_2_DO <= Hash_out(KECCAK_R - 3 * PICNIC_S / 2 - (3 * Count_DP + 2) * PICNIC_S - 1 downto KECCAK_R - 3 * PICNIC_S / 2 - (3 * Count_DP + 3) * PICNIC_S);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' and Count_DP >= 2 then
          Buffer_out_DN <= Hash_out(3* PICNIC_S / 2 - 1 downto 0);
          Squeeze_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
        end if;
      when squeeze_0 =>
        Count_DN <= 0;
      when squeeze_off =>
        Count_DN <= 0;
    end case;
  end process;

  -- next state logic
  process (State_DP, Start_SI, Finish_out, Next_SI, Count_DP)
  begin
    --default
    State_DN <= State_DP;

    case State_DP is
      when init =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        end if;
      when absorb_start =>
        State_DN <= absorb;
      when absorb =>
        if Finish_out = '1' then
          State_DN <= seed_out_0;
        end if;
      when seed_out_0 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' and Count_DP >= 2 then
          State_DN <= squeeze_off;
        end if;
      when seed_out_buf =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= seed_out_off;
        end if;
      when seed_out_off =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' and Count_DP >= 2 then
          State_DN <= squeeze_0;
        end if;
      when squeeze_0 =>
        if Finish_out = '1' then
          State_DN <= seed_out_0;
        end if;
      when squeeze_off =>
        if Finish_out = '1' then
          State_DN <= seed_out_buf;
        end if;
    end case;
  end process;

  -- the registers
  process (Clk_CI, Rst_RI)
  begin  -- process register_p
    if Clk_CI'event and Clk_CI = '1' then
      if Rst_RI = '1' then               -- synchronous reset (active high)
        State_DP      <= init;
        Buffer_out_DP <= (others => '0');
        Count_DP      <= 0;
      else
        State_DP      <= State_DN;
        Buffer_out_DP <= Buffer_out_DN;
        Count_DP      <= Count_DN;
      end if;
    end if;
  end process;

end behavorial;