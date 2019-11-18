library work;
use work.keccak_pkg.all;
use work.picnic_pkg.all;

library ieee;
use ieee.std_logic_1164.all;

entity h3 is
  port(
    -- Clock and Reset
    signal Clk_CI      : in std_logic;
    signal Rst_RI      : in std_logic;
    -- Input signals
    signal Start_SI    : in std_logic;
    signal Valid_SI    : in std_logic;
    signal Block_DI    : in std_logic_vector(PICNIC_S - 1 downto 0);
    -- Output signals
    signal Ready_SO    : out std_logic;
    signal Chal_DO     : out std_logic_vector(2 * T - 1 downto 0);
    signal Sig_Len_DO  : out integer range 0 to MAX_SIG
  );
end entity;

architecture behavorial of h3 is
  type states is (init, buffer0, buffer1, absorb1, buffer2, buffer3, absorb2, pad, absorb3, challenge1, challenge2);
  signal State_DN, State_DP : states;
  signal Input_Buf_DN, Input_Buf_DP : std_logic_vector(KECCAK_R - 1 downto 0);
  signal Hash_in : std_logic_vector(KECCAK_R - 1 downto 0);
  signal Hash_out : std_logic_vector(DIGEST_L - 1 downto 0);
  signal Init_in, Absorb_in, Finish_out : std_logic;
  signal Counter_DP, Counter_DN : integer range 0 to 10;
  signal Count_All_DP, Count_All_DN : integer range 0 to 9 * T + 7;
  signal Digest_DP, Digest_DN : std_logic_vector(DIGEST_L - 1 downto 0);
  signal Challenge_DP, Challenge_DN : std_logic_vector(2 * T - 1 downto 0);
  signal Count_Challenge_DP, Count_Challenge_DN : integer range 0 to 2 * T;
  signal Count_Digest_DP, Count_Digest_DN : integer range 0 to DIGEST_L;
  signal Sig_Len_DP, Sig_Len_DN : integer range 0 to MAX_SIG;

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
    Block_DI   => Hash_in,
    Absorb_SI  => Absorb_in,
    Squeeze_SI => '0',
    Init_SI    => Init_in,
    Hash_DO    => Hash_out,
    Valid_SO   => Finish_out
  );

  -- output logic
  process (State_DP, Block_DI, Start_SI, Valid_SI, Counter_DP, Input_Buf_DP, Hash_out, Count_All_DP, Challenge_DP, Digest_DP, Count_Challenge_DP, Count_Digest_DP, Finish_out, Sig_Len_DP)
  begin
    --default
    Ready_SO <= '0';
    Init_in <= '0';
    Absorb_in <= '0';
    Chal_DO <= Challenge_DP;
    Input_Buf_DN <= Input_Buf_DP;
    Counter_DN <= Counter_DP;
    Hash_in <= (others => '0');
    Count_All_DN <= Count_All_DP;
    Digest_DN <= Digest_DP;
    Challenge_DN <= Challenge_DP;
    Count_Challenge_DN <= Count_Challenge_DP;
    Count_Digest_DN <= Count_Digest_DP;
    Sig_Len_DN <= Sig_Len_DP;
    Sig_Len_DO <= Sig_Len_DP;

    case State_DP is
      when init =>
        if Start_SI = '1' then
          Init_in <= '1';
          Input_Buf_DN(KECCAK_R - 1 downto KECCAK_R - 8) <= (others => '0');
          Input_Buf_DN(7 downto 0) <= HASH_PREFIX_1;
          Counter_DN <= 0;
          Count_All_DN <= 0;
          Count_Challenge_DN <= 0;
          Sig_Len_DN <= 0;
        end if;
        Ready_SO <= '1';
      when buffer0 =>
        if Valid_SI = '1' then
          Input_Buf_DN(KECCAK_R - 1 downto PICNIC_S) <= Input_Buf_DP(KECCAK_R - PICNIC_S - 1 downto 0);
          Input_BUF_DN(PICNIC_S - 1 downto 0) <= Block_DI;
          Counter_DN <= Counter_DP + 1;
          Count_All_DN <= Count_All_DP + 1;
        end if;
        Ready_SO <= '1';
      when buffer1 =>
        if Valid_SI = '1' then
          Hash_in(KECCAK_R - 1 downto PICNIC_S / 2 - 8) <= Input_Buf_DP(KECCAK_R - PICNIC_S / 2 + 8 - 1 downto 0);
          Hash_in(PICNIC_S / 2 - 8 - 1 downto 0) <= Block_DI(PICNIC_S - 1 downto PICNIC_S / 2 + 8);
          Absorb_in <= '1';
          Input_Buf_DN(PICNIC_S / 2 + 8 - 1 downto 0) <= Block_DI(PICNIC_S / 2 + 8 - 1 downto 0);
          Input_Buf_DN(KECCAK_R - 1 downto PICNIC_S / 2 + 8) <= (others => '0');
          Count_All_DN <= Count_All_DP + 1;
        end if;
        Ready_SO <= '1';
      when absorb1 =>
        Counter_DN <= 1;
      when buffer2 =>
        if Valid_SI = '1' then
          Input_Buf_DN(KECCAK_R - 1 downto PICNIC_S) <= Input_Buf_DP(KECCAK_R - PICNIC_S - 1 downto 0);
          Input_BUF_DN(PICNIC_S - 1 downto 0) <= Block_DI;
          Counter_DN <= Counter_DP + 1;
          Count_All_DN <= Count_All_DP + 1;
        end if;
        Ready_SO <= '1';
      when buffer3 =>
        if Valid_SI = '1' then
          Hash_in(KECCAK_R - 1 downto PICNIC_S - 8) <= Input_Buf_DP(KECCAK_R - PICNIC_S + 8 - 1 downto 0);
          Hash_in(PICNIC_S - 8  - 1 downto 0) <= Block_DI(PICNIC_S - 1 downto 8);
          Absorb_in <= '1';
          Input_Buf_DN(8 - 1 downto 0) <= Block_DI(8 - 1 downto 0);
          Input_Buf_DN(KECCAK_R - 1 downto 8) <= (others => '0');
          Count_All_DN <= Count_All_DP + 1;
        end if;
        Ready_SO <= '1';
      when absorb2 =>
        Counter_DN <= 0;
      when pad =>
        if Valid_SI = '1' then
          Hash_in(KECCAK_R - 1 downto KECCAK_R - 5 * PICNIC_S - 16) <= Input_Buf_DP(4 * PICNIC_S + 8 - 1 downto 0) & Block_DI & KECCAK_PAD;
          Hash_in(7) <= '1';
          Absorb_in <= '1';
          Sig_Len_DN <= CHAL_ROUND_BYTE + (T * DIGEST_L / 8) + (SALT_LEN / 8);
        end if;
        Ready_SO <= '1';
      when absorb3 =>
        if Finish_out = '1' then
          Digest_DN <= Hash_out;
          Init_in <= '1';
          Count_Digest_DN <= 0;
        end if;
      when challenge1 =>
        Hash_in(KECCAK_R - 1 downto KECCAK_R - DIGEST_L - 16) <= HASH_PREFIX_1 & Digest_DP & KECCAK_PAD;
        Hash_in(7) <= '1';
        Absorb_in <= '1';
        if Digest_DP(DIGEST_L - 1 downto DIGEST_L - 2) /= "11" then
          -- Add to challenge
          Challenge_DN <= Challenge_DP(2 * T - 3 downto 0) & Digest_DP(DIGEST_L - 2) & Digest_DP(DIGEST_L - 1);
          Count_Challenge_DN <= Count_Challenge_DP + 1;
          -- length:
          if Digest_DP(DIGEST_L - 1 downto DIGEST_L - 2) = "00" then
            Sig_Len_DN <= Sig_Len_DP + (PICNIC_S / 4) + RS_PAD_BYTE;
          else
            Sig_Len_DN <= Sig_Len_DP + (3 * PICNIC_S / 8) + RS_PAD_BYTE;
          end if;
        end if;
        Digest_DN <= Digest_DP(DIGEST_L - 3 downto 0) & "00";
        Count_Digest_DN <= Count_Digest_DP + 1;
      when challenge2 =>
        if Digest_DP(DIGEST_L - 1 downto DIGEST_L - 2) /= "11" then
          -- Add to challenge
          Challenge_DN <= Challenge_DP(2 * T - 3 downto 0) & Digest_DP(DIGEST_L - 2) & Digest_DP(DIGEST_L - 1);
          Count_Challenge_DN <= Count_Challenge_DP + 1;
          -- length:
          if Digest_DP(DIGEST_L - 1 downto DIGEST_L - 2) = "00" then
            Sig_Len_DN <= Sig_Len_DP + (PICNIC_S / 4) + RS_PAD_BYTE;
          else
            Sig_Len_DN <= Sig_Len_DP + (3 * PICNIC_S / 8) + RS_PAD_BYTE;
          end if;
        end if;
        Digest_DN <= Digest_DP(DIGEST_L - 3 downto 0) & "00";
        Count_Digest_DN <= Count_Digest_DP + 1;
    end case;
  end process;

  -- next state logic
  process (State_DP, Start_SI, Valid_SI, Counter_DP, Finish_out, Count_All_DP, Count_Challenge_DP, Count_Digest_DP, Digest_DP)
  begin
    --default
    State_DN <= State_DP;

    case State_DP is
      when init =>
        if Start_SI = '1' then
          State_DN <= buffer0;
        end if;
      when buffer0 =>
        if Valid_SI = '1' and Count_All_DP >= 9 * T + 6 then
          State_DN <= pad;
        elsif Valid_SI = '1' and Counter_DP >= 9 then
          State_DN <= buffer1;
        end if;
      when buffer1 =>
        if Valid_SI = '1' then
          State_DN <= absorb1;
        end if;
      when absorb1 =>
        if Finish_out = '1' then
          State_DN <= buffer2;
        end if;
      when buffer2 =>
        if Valid_SI = '1' and Counter_DP >= 9 then
          State_DN <= buffer3;
        end if;
      when buffer3 =>
        if Valid_SI = '1' then
          State_DN <= absorb2;
        end if;
      when absorb2 =>
        if Finish_out = '1' then
          State_DN <= buffer0;
        end if;
      when pad =>
        if Valid_SI = '1' then
          State_DN <= absorb3;
        end if;
      when absorb3 =>
        if Finish_out = '1' then
          State_DN <= challenge1;
        end if;
      when challenge1 =>
        if Count_Challenge_DP >= T - 1 and Digest_DP(DIGEST_L - 1 downto DIGEST_L - 2) /= "11" then
          State_DN <= init;
        else
          State_DN <= challenge2;
        end if;
      when challenge2 =>
        if Count_Challenge_DP >= T - 1 and Digest_DP(DIGEST_L - 1 downto DIGEST_L - 2) /= "11" then
          State_DN <= init;
        elsif Count_Digest_DP >= DIGEST_L / 2 - 1 then
          State_DN <= absorb3;
        end if;
    end case;
  end process;

  -- the registers
  process (Clk_CI, Rst_RI)
  begin  -- process register_p
    if Clk_CI'event and Clk_CI = '1' then
      if Rst_RI = '1' then               -- synchronous reset (active high)
        State_DP           <= init;
        Input_Buf_DP       <= (others => '0');
        Counter_DP         <= 0;
        Count_All_DP       <= 0;
        Digest_DP          <= (others => '0');
        Challenge_DP       <= (others => '0');
        Count_Challenge_DP <= 0;
        Count_Digest_DP    <= 0;
        Sig_Len_DP         <= 0;
      else
        State_DP           <= State_DN;
        Input_Buf_DP       <= Input_Buf_DN;
        Counter_DP         <= Counter_DN;
        Count_All_DP       <= Count_All_DN;
        Digest_DP          <= Digest_DN;
        Challenge_DP       <= Challenge_DN;
        Count_Challenge_DP <= Count_Challenge_DN;
        Count_Digest_DP    <= Count_Digest_DN;
        Sig_Len_DP         <= Sig_Len_DN;
      end if;
    end if;
  end process;

end behavorial;
