library work;
use work.picnic_pkg.all;
use work.bram_pkg.all;
use work.protocol_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity output_fifo is
  port(
    -- Clock and Reset
    signal clk                : in std_logic;
    signal rst                : in std_logic;
    -- Inputs
    signal Sig_Len            : in integer range 0 to MAX_SIG;
    signal Init_DI            : in std_logic_vector(INIT_WIDTH - 1 downto 0);
    signal Init_SI            : in std_logic;
    signal Data_DI            : in std_logic_vector(PDO_WIDTH - 1 downto 0);
    signal Valid_Data_SI      : in std_logic;
    signal Unaligned_DI       : in std_logic_vector(UNALIGNED_WIDTH - 1 downto 0);
    signal Valid_Unaligned_SI : in std_logic;
    signal Ready_SI           : in std_logic;
    -- Outputs
    signal Data_DO            : out std_logic_vector(PDO_WIDTH - 1 downto 0);
    signal Valid_SO           : out std_logic;
    signal Ready_SO           : out std_logic;
    signal Last_SO            : out std_logic;
    signal Skip_SO            : out std_logic
  );
end entity;

architecture behavorial of output_fifo is
  type states is (init, state0, state1, state2, state3, state4, state5,
                        state6, state7, state8, state9, state10, state11,
                        state12, state13, state14, state15);
  signal State_DN, State_DP : states;

  signal To_Send_DN, To_Send_DP : integer range 0 to MAX_SIG;
  signal Cur_Send_DN, Cur_Send_DP : integer range 0 to L5_BYTES_PER_SEG;
  signal Saved_DN, Saved_DP : std_logic_vector(PDO_WIDTH - 1 downto 0);

  constant PDO_BYTES : integer := (PDO_WIDTH / 8);
begin

  -- output logic
  process (State_DP, Saved_DP, Valid_Data_SI, Valid_Unaligned_SI, Ready_SI, Init_DI, Data_DI, Unaligned_DI, To_Send_DP, Cur_Send_DP, Sig_Len)
  begin
    --default
    Saved_DN <= Saved_DP;
    Data_DO <= Saved_DP;
    To_Send_DN <= To_Send_DP;
    Cur_Send_DN <= Cur_Send_DP;
    Valid_SO <= '0';
    Ready_SO <= Ready_SI;
    Skip_SO <= '0';
    Last_SO <= '0';

    case State_DP is
      when init =>
        Ready_SO <= '1';
        Saved_DN(INIT_WIDTH - 1 downto 0) <= Init_DI;
        Saved_DN(PDO_WIDTH - 1 downto INIT_WIDTH) <= (others => '0');
        Cur_Send_DN <= 96; -- already send as challenge
        if Valid_Data_SI = '1' and Valid_Unaligned_SI = '1' then
          To_Send_DN <= Sig_Len - 96; -- to send to be done
        end if;
      when state0 =>
        -- 14/2 bytes
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto PDO_WIDTH - INIT_WIDTH) <= Saved_DP(INIT_WIDTH - 1 downto 0);
            Data_DO(PDO_WIDTH - INIT_WIDTH - 1 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(INIT_WIDTH - 1 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 104);
            Saved_DN(103 downto 0) <= Unaligned_DI(103 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 104) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(INIT_WIDTH - 1 downto 0) & Data_DI(PDO_WIDTH - 1 downto INIT_WIDTH);
            Saved_DN(INIT_WIDTH - 1 downto 0) <= Data_DI(INIT_WIDTH - 1 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto INIT_WIDTH) <= (others => '0');
          end if;
        end if;
      when state1 =>
        -- 13/3 byte
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto 24) <= Saved_DP(103 downto 0);
            Data_DO(23 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(103 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 96);
            Saved_DN(95 downto 0) <= Unaligned_DI(95 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 96) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(103 downto 0) & Data_DI(PDO_WIDTH - 1 downto 104);
            Saved_DN(103 downto 0) <= Data_DI(103 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 104) <= (others => '0');
          end if;
        end if;
      when state2 =>
        -- 12/4 bytes
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto 32) <= Saved_DP(95 downto 0);
            Data_DO(31 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(95 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 88);
            Saved_DN(87 downto 0) <= Unaligned_DI(87 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 88) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(95 downto 0) & Data_DI(PDO_WIDTH - 1 downto 96);
            Saved_DN(95 downto 0) <= Data_DI(95 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 96) <= (others => '0');
          end if;
        end if;
      when state3 =>
        -- 11/5 bytes
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto 40) <= Saved_DP(87 downto 0);
            Data_DO(39 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(87 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 80);
            Saved_DN(79 downto 0) <= Unaligned_DI(79 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 80) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(87 downto 0) & Data_DI(PDO_WIDTH - 1 downto 88);
            Saved_DN(87 downto 0) <= Data_DI(87 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 88) <= (others => '0');
          end if;
        end if;
      when state4 =>
        -- 10/6 bytes
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto 48) <= Saved_DP(79 downto 0);
            Data_DO(47 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(79 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 72);
            Saved_DN(71 downto 0) <= Unaligned_DI(71 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 72) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(79 downto 0) & Data_DI(PDO_WIDTH - 1 downto 80);
            Saved_DN(79 downto 0) <= Data_DI(79 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 80) <= (others => '0');
          end if;
        end if;
      when state5 =>
        -- 9/7 bytes
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto 56) <= Saved_DP(71 downto 0);
            Data_DO(55 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(71 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 64);
            Saved_DN(63 downto 0) <= Unaligned_DI(63 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 64) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(71 downto 0) & Data_DI(PDO_WIDTH - 1 downto 72);
            Saved_DN(71 downto 0) <= Data_DI(71 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 72) <= (others => '0');
          end if;
        end if;
      when state6 =>
        -- 8/8 bytes
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto 64) <= Saved_DP(63 downto 0);
            Data_DO(63 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(63 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 56);
            Saved_DN(55 downto 0) <= Unaligned_DI(55 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 56) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(63 downto 0) & Data_DI(PDO_WIDTH - 1 downto 64);
            Saved_DN(63 downto 0) <= Data_DI(63 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 64) <= (others => '0');
          end if;
        end if;
      when state7 =>
        -- 7/9 bytes
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto 72) <= Saved_DP(55 downto 0);
            Data_DO(71 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(55 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 48);
            Saved_DN(47 downto 0) <= Unaligned_DI(47 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 48) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(55 downto 0) & Data_DI(PDO_WIDTH - 1 downto 56);
            Saved_DN(55 downto 0) <= Data_DI(55 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 56) <= (others => '0');
          end if;
        end if;
      when state8 =>
        -- 6/10 bytes
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto 80) <= Saved_DP(47 downto 0);
            Data_DO(79 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(47 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 40);
            Saved_DN(39 downto 0) <= Unaligned_DI(39 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 40) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(47 downto 0) & Data_DI(PDO_WIDTH - 1 downto 48);
            Saved_DN(47 downto 0) <= Data_DI(47 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 48) <= (others => '0');
          end if;
        end if;
      when state9 =>
        -- 5/11 bytes
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto 88) <= Saved_DP(39 downto 0);
            Data_DO(87 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(39 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 32);
            Saved_DN(31 downto 0) <= Unaligned_DI(31 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 32) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(39 downto 0) & Data_DI(PDO_WIDTH - 1 downto 40);
            Saved_DN(39 downto 0) <= Data_DI(39 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 40) <= (others => '0');
          end if;
        end if;
      when state10 =>
        -- 4/12 bytes
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto 96) <= Saved_DP(31 downto 0);
            Data_DO(95 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(31 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 24);
            Saved_DN(23 downto 0) <= Unaligned_DI(23 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 24) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(31 downto 0) & Data_DI(PDO_WIDTH - 1 downto 32);
            Saved_DN(31 downto 0) <= Data_DI(31 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 32) <= (others => '0');
          end if;
        end if;
      when state11 =>
        -- 3/13 bytes
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto 104) <= Saved_DP(23 downto 0);
            Data_DO(103 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(23 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 16);
            Saved_DN(15 downto 0) <= Unaligned_DI(15 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 16) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(23 downto 0) & Data_DI(PDO_WIDTH - 1 downto 24);
            Saved_DN(23 downto 0) <= Data_DI(23 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 24) <= (others => '0');
          end if;
        end if;
      when state12 =>
        -- 2/14 bytes
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto 112) <= Saved_DP(15 downto 0);
            Data_DO(111 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(15 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 8);
            Saved_DN(7 downto 0) <= Unaligned_DI(7 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 8) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(15 downto 0) & Data_DI(PDO_WIDTH - 1 downto 16);
            Saved_DN(15 downto 0) <= Data_DI(15 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 16) <= (others => '0');
          end if;
        end if;
      when state13 =>
        -- 1/15 bytes
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto 120) <= Saved_DP(7 downto 0);
            Data_DO(119 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(7 downto 0) & Unaligned_DI;
            Saved_DN <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(7 downto 0) & Data_DI(PDO_WIDTH - 1 downto 8);
            Saved_DN(7 downto 0) <= Data_DI(7 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 8) <= (others => '0');
          end if;
        end if;
      when state14 =>
        -- 0/16 bytes
        -- skip output here
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          -- no remaining output here
          elsif Valid_Unaligned_SI = '1' and Valid_data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Skip_SO <= '1';
            Data_DO <= Unaligned_DI & Data_DI(PDO_WIDTH - 1 downto 120);
            Saved_DN(119 downto 0) <= Data_DI(119 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 120) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Data_DI;
            Saved_DN <= (others => '0');
          end if;
        end if;
      when state15 =>
        -- 15/1 bytes
        if Ready_SI = '1' then
          if Cur_Send_DP = L5_BYTES_PER_SEG then
            Cur_Send_DN <= 0;
            -- Send new header
            Last_SO <= '1';
            Ready_SO <= '0'; -- don't get new data
            Valid_SO <= '1';
            if To_Send_DP > L5_BYTES_PER_SEG then
              Data_DO <= H_SIG & "00" & x"00" & std_logic_vector(to_unsigned(L5_BYTES_PER_SEG, H_LEN_WIDTH)) & pad_96;
            else
              Data_DO <= H_SIG & "11" & x"00" & std_logic_vector(to_unsigned(To_Send_DP, H_LEN_WIDTH)) & pad_96;
            end if;
          elsif To_Send_DP < 16 then
            To_Send_DN <= 0;
            Cur_Send_DN <= 0;
            -- Send remaining data
            Last_SO <= '1';
            Valid_SO <= '1';
            Data_DO(PDO_WIDTH - 1 downto 8) <= Saved_DP(119 downto 0);
            Data_DO(7 downto 0) <= (others => '0');
          elsif Valid_Unaligned_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(119 downto 0) & Unaligned_DI(UNALIGNED_WIDTH - 1 downto 112);
            Saved_DN(111 downto 0) <= Unaligned_DI(111 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 112) <= (others => '0');
          elsif Valid_Data_SI = '1' then
            if Cur_Send_DP + PDO_BYTES = L5_BYTES_PER_SEG then
              Last_SO <= '1';
            end if;
            Cur_Send_DN <= Cur_Send_DP + PDO_BYTES;
            To_Send_DN <= To_Send_DP - PDO_BYTES;
            Valid_SO <= '1';
            Data_DO <= Saved_DP(119 downto 0) & Data_DI(PDO_WIDTH - 1 downto 120);
            Saved_DN(119 downto 0) <= Data_DI(119 downto 0);
            Saved_DN(PDO_WIDTH - 1 downto 120) <= (others => '0');
          end if;
        end if;
    end case;
  end process;

  -- next state logic
  process (State_DP, Valid_Data_SI, Valid_Unaligned_SI, Ready_SI, Init_SI, Cur_Send_DP, TO_Send_DP)
  begin
    --default
    State_DN <= State_DP;

    case State_DP is
      when init =>
        if Valid_Data_SI = '1' and Valid_Unaligned_SI = '1' then
          State_DN <= state0;
        end if;
      when state0 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state1;
        end if;
      when state1 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state2;
        end if;
      when state2 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state3;
        end if;
      when state3 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state4;
        end if;
      when state4 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state5;
        end if;
      when state5 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state6;
        end if;
      when state6 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state7;
        end if;
      when state7 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state8;
        end if;
      when state8 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state9;
        end if;
      when state9 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state10;
        end if;
      when state10 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state11;
        end if;
      when state11 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state12;
        end if;
      when state12 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state13;
        end if;
      when state13 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state14;
        end if;
      when state14 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' and Valid_Data_SI = '1' then
          State_DN <= state15;
        end if;
      when state15 =>
        if Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and To_Send_DP < 16 then
          State_DN <= init;
        elsif Ready_SI = '1' and Cur_Send_DP < L5_BYTES_PER_SEG and Valid_Unaligned_SI = '1' then
          State_DN <= state0;
        end if;
    end case;

    if Init_SI = '1' then
      State_DN <= init;
    end if;
  end process;

  process (clk, rst)
  begin  -- process register_p
    if clk'event and clk = '1' then
      if rst = '1' then               -- synchronous reset (active high)
        State_DP     <= init;
        Saved_DP     <= (others => '0');
        Cur_Send_DP  <= 0;
        To_Send_DP   <= 0;
      else
        State_DP     <= State_DN;
        Saved_DP     <= Saved_DN;
        To_Send_DP   <= To_Send_DN;
        Cur_Send_DP  <= Cur_Send_DN;
      end if;
    end if;
  end process;

end architecture behavorial;
