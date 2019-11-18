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
  type states is (
    init, absorb_start, absorb1, absorb2, squeeze,
    seed_out_0, seed_out_1, seed_out_2, seed_out_3, seed_out_4, seed_out_5,
    seed_out_6, seed_out_7, seed_out_8, seed_out_9, seed_out_10, seed_out_11,
    seed_out_12, seed_out_13, seed_out_14, seed_out_15, seed_out_16
  );
  signal State_DN, State_DP : states;
  signal Init_in, Start_in, Squeeze_in, Finish_out : std_logic;
  signal K_in, Hash_out : std_logic_vector(KECCAK_R - 1 downto 0);
  signal Count_DN, Count_DP : integer range 0 to 16;
  signal Buffer_out_DN, Buffer_out_DP : std_logic_vector(KECCAK_R - 1 downto 0);

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
        K_in <= Key_DI & Message_DI & Cipher_DI & Plain_DI(N - 1 downto N - KECCAK_R + K + MSG_LEN + N);
        Start_in <= '1';
      when absorb1 =>
        if Finish_out <= '1' then
          K_in(KECCAK_R - 1 downto KECCAK_R - N + KECCAK_R - K - MSG_LEN - N - 24) <= Plain_DI(N - KECCAK_R + K + MSG_LEN + N - 1 downto 0) & MSG_LENGHT_END & KECCAK_PAD;
          K_in(7) <= '1';
          Start_in <= '1';
        end if;
      when absorb2 =>
        Count_DN <= 0;
      when seed_out_0 =>
        Ready_SO <= '1';
        Seed_0_DO <= Hash_out(KECCAK_R - 1 downto KECCAK_R - PICNIC_S);
        Seed_1_DO <= Hash_out(KECCAK_R - PICNIC_S - 1 downto KECCAK_R - 2 * PICNIC_S);
        Seed_2_DO <= Hash_out(KECCAK_R - 2 * PICNIC_S - 1 downto KECCAK_R - 3 * PICNIC_S);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Squeeze_in <= '1';
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_1 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(319 downto 64);
        Seed_1_DO <= Buffer_out_DP(63 downto 0) & Hash_out(KECCAK_R - 1 downto KECCAK_R - 192);
        Seed_2_DO <= Hash_out(KECCAK_R - 193 downto KECCAK_R - 448);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Squeeze_in <= '1';
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_2 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(639 downto 384);
        Seed_1_DO <= Buffer_out_DP(383 downto 128);
        Seed_2_DO <= Buffer_out_DP(127 downto 0) & Hash_out(KECCAK_R - 1 downto KECCAK_R - 128);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_3 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(959 downto 704);
        Seed_1_DO <= Buffer_out_DP(703 downto 448);
        Seed_2_DO <= Buffer_out_DP(447 downto 192);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Squeeze_in <= '1';
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_4 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(191 downto 0) & Hash_out(KECCAK_R - 1 downto KECCAK_R - 64);
        Seed_1_DO <= Hash_out(KECCAK_R - 65 downto KECCAK_R - 320);
        Seed_2_DO <= Hash_out(KECCAK_R - 321 downto KECCAK_R - 576);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Squeeze_in <= '1';
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_5 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(511 downto 256);
        Seed_1_DO <= Buffer_out_DP(255 downto 0);
        Seed_2_DO <= Hash_out(KECCAK_R - 1 downto KECCAK_R - 256);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_6 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(831 downto 576);
        Seed_1_DO <= Buffer_out_DP(575 downto 320);
        Seed_2_DO <= Buffer_out_DP(319 downto 64);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Squeeze_in <= '1';
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_7 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(63 downto 0) & Hash_out(KECCAK_R - 1 downto KECCAK_R - 192);
        Seed_1_DO <= Hash_out(KECCAK_R - 193 downto KECCAK_R - 448);
        Seed_2_DO <= Hash_out(KECCAK_R - 449 downto KECCAK_R - 704);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Squeeze_in <= '1';
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_8 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(383 downto 128);
        Seed_1_DO <= Buffer_out_DP(127 downto 0) & Hash_out(KECCAK_R - 1 downto KECCAK_R - 128);
        Seed_2_DO <= Hash_out(KECCAK_R - 129 downto KECCAK_R - 384);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Squeeze_in <= '1';
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_9 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(703 downto 448);
        Seed_1_DO <= Buffer_out_DP(447 downto 192);
        Seed_2_DO <= Buffer_out_DP(191 downto 0) & Hash_out(KECCAK_R - 1 downto KECCAK_R - 64);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_10 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(1023 downto 768);
        Seed_1_DO <= Buffer_out_DP(767 downto 512);
        Seed_2_DO <= Buffer_out_DP(511 downto 256);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Squeeze_in <= '1';
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_11 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(255 downto 0);
        Seed_1_DO <= Hash_out(KECCAK_R - 1 downto KECCAK_R - 256);
        Seed_2_DO <= Hash_out(KECCAK_R - 257 downto KECCAK_R - 512);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Squeeze_in <= '1';
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_12 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(575 downto 320);
        Seed_1_DO <= Buffer_out_DP(319 downto 64);
        Seed_2_DO <= Buffer_out_DP(63 downto 0) & Hash_out(KECCAK_R - 1 downto KECCAK_R - 192);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_13 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(895 downto 640);
        Seed_1_DO <= Buffer_out_DP(639 downto 384);
        Seed_2_DO <= Buffer_out_DP(383 downto 128);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Squeeze_in <= '1';
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_14 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(127 downto 0) & Hash_out(KECCAK_R - 1 downto KECCAK_R - 128);
        Seed_1_DO <= Hash_out(KECCAK_R - 129 downto KECCAK_R - 384);
        Seed_2_DO <= Hash_out(KECCAK_R - 385 downto KECCAK_R - 640);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Squeeze_in <= '1';
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_15 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(447 downto 192);
        Seed_1_DO <= Buffer_out_DP(191 downto 0) & Hash_out(KECCAK_R - 1 downto KECCAK_R - 64);
        Seed_2_DO <= Hash_out(KECCAK_R - 65 downto KECCAK_R - 320);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= Count_DP + 1;
          Buffer_out_DN <= Hash_out;
        end if;
      when seed_out_16 =>
        Ready_SO <= '1';
        Seed_0_DO <= Buffer_out_DP(767 downto 512);
        Seed_1_DO <= Buffer_out_DP(511 downto 256);
        Seed_2_DO <= Buffer_out_DP(255 downto 0);
        if Start_SI = '1' then
          Init_in <= '1';
        elsif Next_SI = '1' then
          Count_DN <= 0;
          Squeeze_in <= '1';
          Buffer_out_DN <= Hash_out;
        end if;
      when squeeze =>
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
        State_DN <= absorb1;
      when absorb1 =>
        if Finish_out = '1' then
          State_DN <= absorb2;
        end if;
      when absorb2 =>
        if Finish_out = '1' then
          State_DN <= seed_out_0;
        end if;
      when seed_out_0 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= squeeze;
        end if;
      when seed_out_1 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= squeeze;
        end if;
      when seed_out_2 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= seed_out_3;
        end if;
      when seed_out_3 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= squeeze;
        end if;
      when seed_out_4 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= squeeze;
        end if;
      when seed_out_5 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= seed_out_6;
        end if;
      when seed_out_6 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= squeeze;
        end if;
      when seed_out_7 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= squeeze;
        end if;
      when seed_out_8 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= squeeze;
        end if;
      when seed_out_9 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= seed_out_10;
        end if;
      when seed_out_10 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= squeeze;
        end if;
      when seed_out_11 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= squeeze;
        end if;
      when seed_out_12 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= seed_out_13;
        end if;
      when seed_out_13 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= squeeze;
        end if;
      when seed_out_14 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= squeeze;
        end if;
      when seed_out_15 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= seed_out_16;
        end if;
      when seed_out_16 =>
        if Start_SI = '1' then
          State_DN <= absorb_start;
        elsif Next_SI = '1' then
          State_DN <= squeeze;
        end if;
      when squeeze =>
        if Finish_out = '1' then
          case Count_DP is
            when 0 =>
              State_DN <= seed_out_0;
            when 1 =>
              State_DN <= seed_out_1;
            when 2 =>
              State_DN <= seed_out_2;
            when 3 =>
              State_DN <= seed_out_3;
            when 4 =>
              State_DN <= seed_out_4;
            when 5 =>
              State_DN <= seed_out_5;
            when 6 =>
              State_DN <= seed_out_6;
            when 7 =>
              State_DN <= seed_out_7;
            when 8 =>
              State_DN <= seed_out_8;
            when 9 =>
              State_DN <= seed_out_9;
            when 10 =>
              State_DN <= seed_out_10;
            when 11 =>
              State_DN <= seed_out_11;
            when 12 =>
              State_DN <= seed_out_12;
            when 13 =>
              State_DN <= seed_out_13;
            when 14 =>
              State_DN <= seed_out_14;
            when 15 =>
              State_DN <= seed_out_15;
            when 16 =>
              State_DN <= seed_out_16;
          end case;
        end if;
    end case;
  end process;

  -- the registers
  process (Clk_CI, Rst_RI)
  begin  -- process register_p
    if Clk_CI'event and Clk_CI = '1' then
      if Rst_RI = '1' then               -- synchronous reset (active high)
        State_DP      <= init;
        Count_DP      <= 0;
        Buffer_out_DP <= (others => '0');
      else
        State_DP      <= State_DN;
        Count_DP      <= Count_DN;
        Buffer_out_DP <= Buffer_out_DN;
      end if;
    end if;
  end process;

end behavorial;
